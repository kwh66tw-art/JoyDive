// DiveReplayEngine.swift — JD2Core/Algorithm/DiveReplayEngine.swift
// v1.1 #4/#5 — 靜態剖面重放
// port 自 JD2-Ultra companion DiveReplay.swift（同一套驗證過的邏輯，逐行比對後對齊）
//
// ⚠️ 刻意不經過 DiveEngine 的即時裝置狀態機（深停/安全停留/警報等對「回放
// 已完成潛水」無意義）。更重要的是：DiveEngine.tick() 的 deltaT chunking
// 是為 1Hz 高頻輪詢設計，同一個 chunk 內會直接跳去目標深度算，樣本間隔一旦
// 拉大（真實匯入的剖面樣本常常是 10–60s 一筆）就會出現「深度瞬間跳變」的
// 失真。改為直接驅動 Buhlmann，樣本間手動線性內插、步長 ≤10s。
//
// 重放假設：由水面飽和組織起算（單支潛水的獨立重放；不含前一潛殘氮——
// 視覺化目的為呈現「這支潛水本身」的組織行為）。firstCeilingBar 不設定，
// ceiling/NDL 全程以 gfHigh 為基準，不做 DiveEngine 那種 ascent 中的 GF
// 收緊爬升（Ultra 驗證過的簡化：回放不需要模擬即時裝置的漸進保守化）。
//
// ⚠️ 這是「事後估算」：無法得知潛水者實際的先前組織負荷、個人 GF 設定等，
//    僅供資訊參考，不能取代潛水電腦或正式減壓軟體。

import Foundation
import DiveKit

enum DiveReplayEngine {

    /// v1.2 #3：曲線警示標示種類，門檻與文案比照統一 DiveKit `DiveEngine.updateAscentWarnings()`
    /// 使用的 `AlgorithmConstants`（maxAscentRateWarn=10 m/min、ascentWarnConsecutiveSec=5s、
    /// ascentSustainedWarnSec=10s），確保與（若未來 JD2-Logbook 也有即時潛水模式時）
    /// 即時裝置警報邏輯一致，而非另外發明門檻。
    enum ReplayWarningKind: Equatable, Sendable {
        case ascentRateExceeded
        case mandatorySafetyStop
    }

    /// 一次警示事件（不綁在既有 ReplayPoint 上——兩種警示可能落在同一個樣本區間內，
    /// 用獨立清單才不會互相覆蓋；sampleIndex 供互動選取列查找「目前選取點附近是否有警示」）
    struct ReplayWarning: Equatable, Sendable {
        let sampleIndex: Int
        let timeSeconds: Double
        let depthMeters: Double
        let kind: ReplayWarningKind
    }

    struct ReplayPoint {
        let timeSeconds: Double
        let depthMeters: Double
        let waterTemp: Double?
        let ceilingDepth: Double
        let ndlSeconds: Int
        /// 該時刻的 16 隔室 N₂ 分壓（bar）— 驅動組織艙長條隨拖曳即時反應
        let tissuePressures: [Double]
        /// 該時刻的 16 隔室 He 分壓（bar）— trimix 潛水才非零；air/nitrox 全程為 0
        /// （2026-07-30 新增，解除 trimix 繞過的一部分：組織艙飽和度視覺化需要
        /// He 貢獻才能正確反映 trimix 潛水的實際組織負荷，見 tissueLoadPercent）
        let tissueHePressures: [Double]
    }

    struct ReplayResult {
        var points: [ReplayPoint] = []
        var warnings: [ReplayWarning] = []

        var maxCeiling: Double { points.map(\.ceilingDepth).max() ?? 0 }
        var enteredDeco: Bool { maxCeiling > 0 }
        var finalTissuePressures: [Double] { points.last?.tissuePressures ?? [] }
    }

    /// 重放整條剖面；樣本間線性內插、步長 ≤10s，與 Ultra 驗證過的取樣尺度一致。
    ///
    /// ⚠️ 2026-07-30：trimix 繞過已解除（家族決策
    /// `_JD2-family/decisions/2026-07-18_trimix減壓計算缺口.md`）。DiveKit 自
    /// v1.5.0 起 `Buhlmann` 已支援雙氣體（N₂/He）Schreiner 計算，`ceiling(at:)`／
    /// `ndlSeconds(at:gasMix:)` 對 trimix 皆為真正計算出的數值（非佔位/防呆），
    /// trimix 與 air/nitrox 走完全相同的重放路徑，不再另外分支。
    @MainActor
    static func replay(
        samples: [DiveProfileSample],
        gasMix: GasMix,
        environment: DiveEnvironment = .seaLevel
    ) -> ReplayResult {
        guard samples.count >= 2 else { return ReplayResult() }
        let sorted = samples.sorted { $0.timeSeconds < $1.timeSeconds }

        let buhlmann = Buhlmann(environment: environment)
        buhlmann.updateSurface(deltaT: 1.0)   // DiveKit 慣例：update() 前先水面初始化

        var points: [ReplayPoint] = []
        points.reserveCapacity(sorted.count)

        var warnings: [ReplayWarning] = []
        // 上升速度追蹤（比照 DiveKit DiveEngine.updateAscentWarnings() 的門檻與號誌，
        // 但回放沒有即時裝置的多段升級狀態機，簡化成「每次連續超速episode 各自最多
        // 各發一次」：一次 ascentRateExceeded（5s 門檻）、一次 mandatorySafetyStop（10s
        // 門檻）；速度掉回門檻以下即視為該次 episode 結束，下次再超速會重新計）。
        var ascentWarnSeconds: Double = 0
        var firedWarningThisEpisode = false
        var firedMandatoryThisEpisode = false
        var chunkPrevDepth = sorted[0].depthMeters

        var prev = sorted[0]
        points.append(makePoint(sample: prev, buhlmann: buhlmann, gasMix: gasMix))

        for (sampleIndex, sample) in sorted.enumerated().dropFirst() {
            let span = sample.timeSeconds - prev.timeSeconds
            guard span > 0 else { continue }
            // 線性內插，步長 ≤10s（避免大樣本間隔造成深度瞬間跳變的失真）
            var elapsed = 0.0
            while elapsed < span - 0.001 {
                let dt = min(10, span - elapsed)
                let frac = (elapsed + dt) / span
                let depth = prev.depthMeters + (sample.depthMeters - prev.depthMeters) * frac
                buhlmann.update(depth: depth, gasMix: gasMix, deltaT: dt)

                // ⚠️ 符號與 DiveKit 一致：depth 變淺（上升）= depthDelta 為負 = rate 為負，
                // 「rate < -threshold」才是「上升過快」，避免下潛速度誤觸發。
                let ascentRateMpm = (depth - chunkPrevDepth) / dt * 60.0
                if ascentRateMpm < -AlgorithmConstants.maxAscentRateWarn {
                    ascentWarnSeconds += dt
                } else {
                    ascentWarnSeconds = 0
                    firedWarningThisEpisode = false
                    firedMandatoryThisEpisode = false
                }
                let eventTime = prev.timeSeconds + elapsed + dt
                if ascentWarnSeconds >= Double(AlgorithmConstants.ascentWarnConsecutiveSec),
                   !firedWarningThisEpisode {
                    firedWarningThisEpisode = true
                    warnings.append(ReplayWarning(sampleIndex: sampleIndex, timeSeconds: eventTime,
                                                  depthMeters: depth, kind: .ascentRateExceeded))
                }
                if ascentWarnSeconds >= Double(AlgorithmConstants.ascentSustainedWarnSec),
                   !firedMandatoryThisEpisode {
                    firedMandatoryThisEpisode = true
                    warnings.append(ReplayWarning(sampleIndex: sampleIndex, timeSeconds: eventTime,
                                                  depthMeters: depth, kind: .mandatorySafetyStop))
                }

                chunkPrevDepth = depth
                elapsed += dt
            }
            points.append(makePoint(sample: sample, buhlmann: buhlmann, gasMix: gasMix))
            prev = sample
        }
        return ReplayResult(points: points, warnings: warnings)
    }

    private static func makePoint(sample: DiveProfileSample, buhlmann: Buhlmann, gasMix: GasMix) -> ReplayPoint {
        ReplayPoint(
            timeSeconds: sample.timeSeconds,
            depthMeters: sample.depthMeters,
            waterTemp: sample.waterTemp,
            ceilingDepth: buhlmann.ceiling(at: sample.depthMeters),
            ndlSeconds: buhlmann.ndlSeconds(at: max(sample.depthMeters, 0), gasMix: gasMix),
            tissuePressures: buhlmann.tissuePressures,
            tissueHePressures: buhlmann.tissueHePressures
        )
    }

    // MARK: - 組織艙飽和度（視覺化用）

    /// 隔室載荷百分比：(pN2+pHe) / 水面合併 M-value（gfHigh 收緊後）×100。
    /// >100% = 超出該 GF 下水面允許值（出水即有減壓義務的視覺訊號）。
    ///
    /// ⚠️ 2026-07-30：trimix 解除繞過後新增 `pHe` 參數。air/nitrox 呼叫端傳入的
    /// `pHe` 全程為 0（`Buhlmann.tissueHePressures` 對 air/nitrox 恆回傳 0.0，
    /// 見 DiveKit `Compartment` 註解），這裡的加權合併在 `phe == 0` 時直接退化
    /// 為純 N2 公式，與新增前逐位元相同——不影響既有 air/nitrox 顯示。trimix
    /// 才會真正用到 aHe/bHe，公式與 DiveKit `Buhlmann.combinedAB()`（私有，
    /// 用於 `ceiling(at:)`）同一套加權規則，避免組織艙圖顯示忽略氦氣貢獻、
    /// 誤導性偏低的載荷百分比。
    ///
    /// ⚠️ 這裡只讀 `probe.gfHigh` 與 `probe.compartments[].{aN2,bN2,aHe,bHe}`——
    /// 這幾個欄位只由 `Buhlmann.zhl16cTable`（靜態常數表）決定，跟 `environment`
    /// 無關（`reset()` 只有 `pN2`/`pHe` 用到 environment，這裡完全不讀）。原本每次
    /// 呼叫都重建一個 `Buhlmann` 純粹是為了讀這幾個不變的欄位，互動拖曳剖面時
    /// （`selectedIndex` 每次變動都會呼叫這裡）等於每個拖曳幀都重新配置一次 16
    /// 隔室陣列。改成快取，只有 environment 真的變了才重建，避免不必要的配置。
    @MainActor private static var cachedProbe: Buhlmann?
    @MainActor private static var cachedEnvironment: DiveEnvironment?

    @MainActor
    static func tissueLoadPercent(
        pN2: [Double],
        pHe: [Double] = [],
        environment: DiveEnvironment = .seaLevel
    ) -> [Double] {
        let probe: Buhlmann
        if let cached = cachedProbe, cachedEnvironment == environment {
            probe = cached
        } else {
            probe = Buhlmann(environment: environment)
            cachedProbe = probe
            cachedEnvironment = environment
        }
        let gf = probe.gfHigh
        let surfaceBar = environment.surfacePressureBar
        let heValues = pHe.count == pN2.count ? pHe : Array(repeating: 0.0, count: pN2.count)
        return zip(zip(pN2, heValues), probe.compartments).map { pnHe, c in
            let (pn2, phe) = pnHe
            let pt = pn2 + phe
            let a: Double
            let b: Double
            if phe != 0, pt > 1e-9 {
                a = (c.aN2 * pn2 + c.aHe * phe) / pt
                b = (c.bN2 * pn2 + c.bHe * phe) / pt
            } else {
                a = c.aN2
                b = c.bN2
            }
            let mValue = surfaceBar * (gf / b + 1 - gf) + a * gf
            return (pt / mValue) * 100
        }
    }
}
