// Buhlmann.swift — DiveKit/Algorithm
// 基底：JD2Core v11.0 FINAL 🔒 (COMPLETED: All 4 TODOs implemented)
// JD2-Ultra 變更：
//   - public API、tissue 快照（snapshot/restore）供持久化與 DecoCalculator 模擬使用
//   - gfLow/gfHigh 可由 PersonalSetting 設定
//
// ⚠️ 非執行緒安全，所有呼叫在同一 @MainActor（Swift 6）
// ⚠️ firstCeilingBar 責任在 DiveEngine：
//    .ascent 開始 → firstCeilingBar = rawCeiling()
//    .postDive    → firstCeilingBar = nil
// ⚠️ reset()：app 冷啟動（無持久化狀態時），或 environment.didSet 自動呼叫
// ⚠️ DiveEngine.init() 必須呼叫 updateSurface() → hasReceivedUpdate = true

import Foundation

public struct Compartment: Sendable {
    public let halfTimeN2: Double
    public let aN2: Double
    public let bN2: Double
    public var pN2: Double
}

public final class Buhlmann {

    // ✅ 初始化後、第一次 update() 前切換環境是合法的（hasReceivedUpdate = false）
    // ⚠️ 潛水中途（hasReceivedUpdate = true 後）不得切換
    public var environment: DiveEnvironment = .seaLevel {
        didSet {
            assert(!hasReceivedUpdate, "[Buhlmann] 潛水中途不得切換 environment")
            reset()
        }
    }

    public var gfLow: Double  = 0.40
    public var gfHigh: Double = 0.85
    public var firstCeilingBar: Double? = nil

    public private(set) var compartments: [Compartment] = []
    private var prevDepth: Double = 0.0
    private var hasReceivedUpdate: Bool = false

    /// NDL ≥ 99min 與 NDL=∞（passCount==0）統一顯示「99+」
    /// 已知合併：對潛水安全無影響（99min 以上不需關注精確值）
    public static let ndlUnlimitedMarker: Int = 99 * 60

    static let zhl16cTable: [(ht: Double, a: Double, b: Double)] = [
        ( 4.0,1.2599,0.5050),( 8.0,1.0000,0.6514),(12.5,0.8618,0.7222),
        (18.5,0.7562,0.7825),(27.0,0.6667,0.8126),(38.3,0.5600,0.8434),
        (54.3,0.4947,0.8693),(77.0,0.4500,0.8910),(109.0,0.4187,0.9092),
        (146.0,0.3798,0.9222),(187.0,0.3497,0.9319),(239.0,0.3223,0.9403),
        (305.0,0.2850,0.9477),(390.0,0.2737,0.9544),(498.0,0.2523,0.9602),
        (635.0,0.2327,0.9653),
    ]

    public init(environment: DiveEnvironment = .seaLevel) {
        self.environment = environment
        reset()
    }

    /// JD2-Ultra: 套用個人保守度檔位
    public func apply(personal: PersonalSetting) {
        gfLow = personal.gfLow
        gfHigh = personal.gfHigh
    }

    // MARK: - Core Update
    //
    // 符號約定：下潛 pRate > 0（壓力增加），上升 pRate < 0（壓力減少）
    //
    // Gas-switch safe：Palv_initial = alvPN2(at: prevDepth, fN2: currGas.fN2)
    //   用「上一秒深度」+「當前氣體」計算初始肺泡壓
    //   氣體切換視為「在時間區段開頭已完成」，Schreiner 基線不偏移
    //
    public func update(depth: Double, gasMix: GasMix, deltaT: Double) {
        hasReceivedUpdate = true

        // ① 時間轉換（傳入秒，必須第一行）
        let deltaT_min = deltaT / 60.0

        // ② 壓力變化率（符號：下潛 > 0，上升 < 0，單位 bar/min）
        let depthDelta = abs(depth - prevDepth)
        var pRate = 0.0
        if depthDelta >= AlgorithmConstants.depthStableThreshold {
            let rawPrate = ((depth - prevDepth) / environment.metersPerBar) / deltaT_min
            // ⚠️ pRateClampMax 單位 bar/min（rawPrate 也是 bar/min，單位一致）
            pRate = max(-AlgorithmConstants.pRateClampMax,
                       min(AlgorithmConstants.pRateClampMax, rawPrate))
        }

        // ③ 初始肺泡壓（gas-switch safe，用 prevDepth + 當前氣體）
        let Palv_initial = alvPN2(at: prevDepth, fN2: gasMix.fN2)

        // ④ 惰性氣體分壓變化率（bar/min）
        // 僅 Air/Nitrox 有效；Trimix 需分別計算 N₂/He 的 R 值
        let Pr = pRate * gasMix.fN2

        // ⑤ 更新 16 隔室
        for i in 0..<16 {
            compartments[i].pN2 = TissueMath.schreiner(Pi: compartments[i].pN2,
                                                       ht: compartments[i].halfTimeN2,
                                                       t_min: deltaT_min,
                                                       Palv_initial: Palv_initial,
                                                       Pr: Pr)
        }

        // ⑥ 只更新 prevDepth（不儲存 prevPalvN2）
        // ❌ 不要加 prevPalvN2 = currPalv（破壞氣體切換的 Schreiner 基線）
        prevDepth = depth
    }

    public func updateSurface(deltaT: Double) {
        // Palv_surface ≈ 0.74 bar（fN2=0.79）
        // 組織從 piN2=0.74065（fN2Air=0.7902 基準）緩慢脫飽和至 ~0.74
        // 差距 0.00048 bar，速度極慢，第一次潛水前影響可忽略，物理行為正確
        update(depth: 0, gasMix: .air, deltaT: deltaT)
    }

    // MARK: - NDL 解析解
    //
    // 生理學基礎：
    //   Palv（肺泡 N₂ 分壓）= 組織 pN2 的指數收斂漸近線
    //   M-value（GF 調整後）= 組織最大允許分壓
    //
    //   條件一：c.pN2 >= M-value → 組織已超限，當前即需 Deco → return 0
    //   條件二：Palv < M-value → 漸近線安全 → 此隔室 NDL = ∞，skip（合法）
    //
    //   ⚠️ 呼叫時機：DiveEngine.tick() 每秒呼叫，NDL 隨深度即時更新
    //
    public func ndlSeconds(at depth: Double, gasMix: GasMix) -> Int {
        if case .trimix = gasMix {
            assertionFailure("[Buhlmann] Trimix NDL 未實作（v2.0 項目）")
            return 0
        }
        assert(hasReceivedUpdate, "[Buhlmann] DiveEngine.init() 必須先呼叫 updateSurface()")

        let gf   = currentGF(at: depth)
        let Palv = alvPN2(at: depth, fN2: gasMix.fN2)
        var minSec = Double.infinity

        for c in compartments {
            let k = log(2.0) / c.halfTimeN2
            let mValue = environment.surfacePressureBar * (gf / c.bN2 + 1.0 - gf) + c.aN2 * gf
            guard c.pN2 < mValue else { return 0 }   // 條件一
            guard Palv  >= mValue else { continue }   // 條件二
            let denom = Palv - c.pN2
            guard abs(denom) > 1e-9 else { continue }
            let ratio = (Palv - mValue) / denom
            guard ratio > 0 else { continue }
            guard ratio < 1 else { return 0 }
            minSec = min(minSec, (-log(ratio) / k) * 60.0)
        }

        return minSec.isInfinite
            ? Self.ndlUnlimitedMarker
            : max(0, min(Self.ndlUnlimitedMarker, Int(minSec)))
    }

    // MARK: - Ceiling
    public func ceiling(at depth: Double) -> Double {
        let gf = currentGF(at: depth)
        var maxPceil = environment.surfacePressureBar
        for c in compartments {
            let d = gf / c.bN2 + 1.0 - gf
            guard d > 0 else { continue }
            maxPceil = max(maxPceil, (c.pN2 - c.aN2 * gf) / d)
        }
        return max(0, (maxPceil - environment.surfacePressureBar) * environment.metersPerBar)
    }

    public func rawCeiling() -> Double {
        // GF = 1.0，回傳絕對壓力（Bar）供 DiveEngine.firstCeilingBar 鎖定 GF 基準
        // ⚠️ 回傳值為 Bar（絕對壓力），不是深度（Meters）
        let gf = 1.0
        var maxPceil = environment.surfacePressureBar
        for c in compartments {
            let d = gf / c.bN2 + 1.0 - gf
            guard d > 0 else { continue }
            maxPceil = max(maxPceil, (c.pN2 - c.aN2 * gf) / d)
        }
        return maxPceil  // 絕對壓力 Bar（無 deco 時 ≈ surfacePressureBar）
    }

    // MARK: - JD2-Ultra: 快照與還原（持久化 / TTS 模擬）

    /// 目前 16 隔室 N₂ 分壓
    public var tissuePressures: [Double] { compartments.map(\.pN2) }

    /// 由持久化狀態還原組織壓力。
    /// ⚠️ 僅限 App 啟動時使用；count 必須為 16，否則忽略並保持 reset 後狀態。
    public func restoreTissues(_ pN2: [Double], firstCeilingBar: Double? = nil) {
        guard pN2.count == 16 else {
            assertionFailure("[Buhlmann] restoreTissues 需要 16 個隔室值")
            return
        }
        for i in 0..<16 {
            compartments[i].pN2 = pN2[i]
        }
        self.firstCeilingBar = firstCeilingBar
        hasReceivedUpdate = true
        prevDepth = 0.0
    }

    // MARK: - Reset
    // 自動呼叫：environment.didSet（切換環境時）
    // 手動呼叫：app 冷啟動（無持久化狀態時）
    // ⚠️ 不在潛水結束時呼叫（組織狀態需保留用於連潛計算）
    public func reset() {
        let piN2 = environment.initialTissuePN2  // fN2Air=0.7902，職責分離
        compartments = Self.zhl16cTable.map { row in
            Compartment(halfTimeN2: row.ht, aN2: row.a, bN2: row.b, pN2: piN2)
        }
        prevDepth = 0.0
        firstCeilingBar = nil
        hasReceivedUpdate = false
    }

    // MARK: - Private Helpers
    func currentGF(at depth: Double) -> Double {
        guard let firstCeil = firstCeilingBar else { return gfHigh }
        let currentP = environment.absolutePressure(at: depth)
        let denom = environment.surfacePressureBar - firstCeil
        guard abs(denom) > 0.01 else { return gfHigh }
        return max(gfLow, min(gfHigh,
            gfLow + (gfHigh - gfLow) * (currentP - firstCeil) / denom))
    }

    func alvPN2(at depth: Double, fN2: Double) -> Double {
        return (environment.absolutePressure(at: depth)
                - environment.waterVaporPressureBar) * fN2
    }
}

// MARK: - JD2-Ultra: 共用組織數學（Buhlmann 與 DecoCalculator 共用同一實作，避免公式分歧）

enum TissueMath {
    /// Schreiner exponential equation（與 JD2Core v11.0 完全相同的公式）
    static func schreiner(Pi: Double, ht: Double, t_min: Double,
                          Palv_initial: Double, Pr: Double) -> Double {
        let k = log(2.0) / ht
        return Palv_initial + Pr * (t_min - 1.0 / k)
               - (Palv_initial - Pi - Pr / k) * exp(-k * t_min)
    }
}
