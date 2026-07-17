// DecoCalculator.swift — DiveKit/Algorithm
// JD2-Ultra 新增：完整減壓引導（業界規格）
//
// 提供 業界等義的三個關鍵值：
//   CEILING  — 不可超越的最淺深度（由 Buhlmann.ceiling 即時取得）
//   FLOOR    — 減壓不再加重的最深深度（低於它就持續吸氮）
//   ASC TIME — 以 10 m/min 上升 + 連續減壓所需的最短到水面總時間
//
// ASC TIME 採前向模擬：複製組織狀態，依固定步長推進，
// 「深於 ceiling+zone → 上升；進入 ceiling zone → 停留」直到 ceiling 歸零後浮出。
// 模擬用的 Schreiner 與 GF 內插與 Buhlmann 同一份 TissueMath / 同一組參數，
// 測試以「恆深模擬 vs Buhlmann.update」交叉驗證一致性。

import Foundation

/// 單次減壓估算結果（每 tick 重算，UI 直接讀取）
public struct DecoStatus: Equatable, Sendable {
    /// 減壓天花板深度（m）。0 = 無減壓義務
    public var ceilingMeters: Double = 0
    /// 減壓地板深度（m）。低於此深度減壓不會進行（floor 定義）
    public var floorMeters: Double = 0
    /// 最短上升總時間（秒，含減壓停留）。0 = 可直接上升
    public var ascentTimeSeconds: Int = 0
    /// 目前位於 ceiling zone（ceiling ~ ceiling+1.2m，最佳減壓區）
    public var inCeilingZone: Bool = false
    /// 目前深度低於 floor（ASC TIME 閃爍 + 上升箭頭，「低於 floor」）
    public var belowFloor: Bool = false
    /// 目前深度高於 ceiling（違規，倒數寬限中）
    public var aboveCeiling: Bool = false

    public init() {}

    /// ceiling zone 寬度：ceiling 以下 1.2 m（4 ft）
    public static let ceilingZoneMeters: Double = 1.2
}

public enum DecoCalculator {

    /// 由目前組織狀態計算完整減壓引導。
    /// - Parameters:
    ///   - buhlmann: 即時引擎的 Buhlmann（只讀取，不改動）
    ///   - depth: 目前深度（m）
    ///   - gasMix: 目前氣體
    ///   - lastStopMeters: 0.2.0(B10)：最後停留深度下限（3/6 m）——引導顯示與
    ///     TTS 模擬不會建議停得比這更淺（業界標準 建議深於 4m 減壓的同類概念）
    /// - Returns: DecoStatus；若 ceiling == 0 則其餘欄位為直接上升語意
    public static func status(buhlmann: Buhlmann,
                              depth: Double,
                              gasMix: GasMix,
                              lastStopMeters: Double = 3.0) -> DecoStatus {
        var s = DecoStatus()
        let env = buhlmann.environment
        let rawCeiling = buhlmann.ceiling(at: depth)
        // B10：顯示天花板 = max(物理 ceiling, 最後停留底線)；物理違規判定仍由引擎用原值
        let ceiling = rawCeiling > 0 ? max(rawCeiling, lastStopMeters) : 0
        s.ceilingMeters = ceiling

        guard ceiling > 0 else {
            // 無減壓義務：ASC TIME = 單純上升時間（業界標準 無deco時不顯示，UI 自行判斷）
            s.ascentTimeSeconds = Int((depth / AlgorithmConstants.ttsAscentRateMpm) * 60.0)
            return s
        }

        // FLOOR：肺泡分壓 = 領先隔室分壓的深度。
        // 深於 floor → 所有隔室仍在吸氮（Palv > pN2），減壓無法進行。
        // Palv(d) = (P_surf + d/mPerBar − pWvp) × fN2 = pN2_max
        let pN2max = buhlmann.tissuePressures.max() ?? 0
        let floorAbs = pN2max / gasMix.fN2 + env.waterVaporPressureBar
        s.floorMeters = max(ceiling, env.depth(from: floorAbs))

        s.belowFloor = depth > s.floorMeters + 0.1
        s.aboveCeiling = depth < ceiling - 0.1
        s.inCeilingZone = !s.aboveCeiling && depth <= ceiling + DecoStatus.ceilingZoneMeters

        s.ascentTimeSeconds = simulateAscentTime(buhlmann: buhlmann, depth: depth,
                                                 gasMix: gasMix, lastStopMeters: lastStopMeters)
        return s
    }

    // MARK: - ASC TIME 前向模擬

    /// 模擬「10 m/min 上升 + ceiling zone 連續減壓」到浮出水面的總秒數。
    /// 上限 999 分鐘（業界規格，超過顯示 "–"）。
    static func simulateAscentTime(buhlmann: Buhlmann,
                                   depth: Double,
                                   gasMix: GasMix,
                                   lastStopMeters: Double = 3.0) -> Int {
        let env = buhlmann.environment
        let gfLow = buhlmann.gfLow
        let gfHigh = buhlmann.gfHigh
        let table = Buhlmann.zhl16cTable

        var pN2 = buhlmann.tissuePressures
        var d = depth
        var elapsed = 0.0
        let step = AlgorithmConstants.ttsSimulationStepSec
        let maxSec = Double(AlgorithmConstants.ttsMaxMinutes * 60)
        let ascentPerStep = AlgorithmConstants.ttsAscentRateMpm / 60.0 * step

        // 審計 R2：潛水員仍在底部時 firstCeilingBar 尚未鎖定（引擎於開始上升才鎖），
        // 若以 nil → gfHigh 模擬全程，停留會比實際上升（GF 內插到 gfLow）短 = 偏樂觀。
        // 修正：模擬內先以「目前組織的 GF=1.0 天花板壓力」鎖定基準，複製引擎上升時的行為。
        let firstCeilingBar = buhlmann.firstCeilingBar
            ?? rawCeilingBar(tissuePN2: pN2, environment: env)

        func gf(at depth: Double) -> Double {
            let firstCeil = firstCeilingBar
            let currentP = env.absolutePressure(at: depth)
            let denom = env.surfacePressureBar - firstCeil
            guard abs(denom) > 0.01 else { return gfHigh }
            return max(gfLow, min(gfHigh,
                gfLow + (gfHigh - gfLow) * (currentP - firstCeil) / denom))
        }

        func ceiling(at depth: Double) -> Double {
            let g = gf(at: depth)
            var maxPceil = env.surfacePressureBar
            for (i, row) in table.enumerated() {
                let den = g / row.b + 1.0 - g
                guard den > 0 else { continue }
                maxPceil = max(maxPceil, (pN2[i] - row.a * g) / den)
            }
            return max(0, (maxPceil - env.surfacePressureBar) * env.metersPerBar)
        }

        func advance(from: Double, to: Double, dt: Double) {
            let dtMin = dt / 60.0
            let pRate = ((to - from) / env.metersPerBar) / dtMin * gasMix.fN2
            let palvInitial = (env.absolutePressure(at: from) - env.waterVaporPressureBar) * gasMix.fN2
            for i in 0..<16 {
                pN2[i] = TissueMath.schreiner(Pi: pN2[i], ht: table[i].ht, t_min: dtMin,
                                              Palv_initial: palvInitial, Pr: pRate)
            }
        }

        while d > 0.05 && elapsed < maxSec {
            let ceil = ceiling(at: d)
            // 目標：可上升至 ceiling（無義務時直奔水面）；B10：停留不淺於 lastStop 底線
            let target = ceil > 0 ? max(ceil, lastStopMeters) : 0.0
            if d > target + 0.05 {
                // 以 10 m/min 上升一步（不衝過 target）
                let next = max(target, d - ascentPerStep)
                let dt = (d - next) / (AlgorithmConstants.ttsAscentRateMpm / 60.0)
                advance(from: d, to: next, dt: max(dt, 0.001))
                elapsed += max(dt, 0.001)
                d = next
            } else {
                // 在 ceiling 停留減壓一步（恆深）
                advance(from: d, to: d, dt: step)
                elapsed += step
            }
        }

        return Int(min(elapsed, maxSec).rounded())
    }

    /// GF=1.0 的天花板絕對壓力（bar）——與 Buhlmann.rawCeiling() 同公式：
    /// gf=1 時 den = 1/b，(p − a)/(1/b) = (p − a)·b
    static func rawCeilingBar(tissuePN2: [Double], environment env: DiveEnvironment) -> Double {
        var maxPceil = env.surfacePressureBar
        for (i, row) in Buhlmann.zhl16cTable.enumerated() {
            maxPceil = max(maxPceil, (tissuePN2[i] - row.a) * row.b)
        }
        return maxPceil
    }
}
