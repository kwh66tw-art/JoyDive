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

    struct ReplayPoint {
        let timeSeconds: Double
        let depthMeters: Double
        let waterTemp: Double?
        let ceilingDepth: Double
        let ndlSeconds: Int
        /// 該時刻的 16 隔室 N₂ 分壓（bar）— 驅動組織艙長條隨拖曳即時反應
        let tissuePressures: [Double]
    }

    struct ReplayResult {
        var points: [ReplayPoint] = []
        /// F5（2026-07-18）：trimix 潛水不提供減壓生理數據（見下方 replay() 說明）。
        /// true 時 UI 應隱藏 Ceiling／No-Deco／組織艙，只顯示深度/時間/溫度剖面。
        var decoDataUnavailable: Bool = false

        var maxCeiling: Double { points.map(\.ceilingDepth).max() ?? 0 }
        var enteredDeco: Bool { maxCeiling > 0 }
        var finalTissuePressures: [Double] { points.last?.tissuePressures ?? [] }
    }

    /// 重放整條剖面；樣本間線性內插、步長 ≤10s，與 Ultra 驗證過的取樣尺度一致。
    ///
    /// ⚠️ F5（2026-07-18）：DiveKit 的 `Buhlmann` 目前只追蹤氮氣分壓（`Compartment.pN2`），
    /// 氦氣完全未計入組織負荷計算，`ndlSeconds(at:gasMix:)` 對 trimix 直接
    /// `assertionFailure`（v2.0 項目，尚未實作）。故 trimix 潛水**不跑減壓生理重放**，
    /// 只回傳深度/時間/溫度供剖面圖顯示，`decoDataUnavailable = true`。
    /// 真正的 trimix 支援待 DiveKit 補齊氦氣隔室後再開放（家族決策待補）。
    @MainActor
    static func replay(
        samples: [DiveProfileSample],
        gasMix: GasMix,
        environment: DiveEnvironment = .seaLevel
    ) -> ReplayResult {
        guard samples.count >= 2 else { return ReplayResult() }
        let sorted = samples.sorted { $0.timeSeconds < $1.timeSeconds }

        if gasMix.isTrimix {
            let points = sorted.map { s in
                ReplayPoint(timeSeconds: s.timeSeconds, depthMeters: s.depthMeters,
                           waterTemp: s.waterTemp, ceilingDepth: 0, ndlSeconds: 0,
                           tissuePressures: [])
            }
            return ReplayResult(points: points, decoDataUnavailable: true)
        }

        let buhlmann = Buhlmann(environment: environment)
        buhlmann.updateSurface(deltaT: 1.0)   // DiveKit 慣例：update() 前先水面初始化

        var points: [ReplayPoint] = []
        points.reserveCapacity(sorted.count)

        var prev = sorted[0]
        points.append(makePoint(sample: prev, buhlmann: buhlmann, gasMix: gasMix))

        for sample in sorted.dropFirst() {
            let span = sample.timeSeconds - prev.timeSeconds
            guard span > 0 else { continue }
            // 線性內插，步長 ≤10s（避免大樣本間隔造成深度瞬間跳變的失真）
            var elapsed = 0.0
            while elapsed < span - 0.001 {
                let dt = min(10, span - elapsed)
                let frac = (elapsed + dt) / span
                let depth = prev.depthMeters + (sample.depthMeters - prev.depthMeters) * frac
                buhlmann.update(depth: depth, gasMix: gasMix, deltaT: dt)
                elapsed += dt
            }
            points.append(makePoint(sample: sample, buhlmann: buhlmann, gasMix: gasMix))
            prev = sample
        }
        return ReplayResult(points: points)
    }

    private static func makePoint(sample: DiveProfileSample, buhlmann: Buhlmann, gasMix: GasMix) -> ReplayPoint {
        ReplayPoint(
            timeSeconds: sample.timeSeconds,
            depthMeters: sample.depthMeters,
            waterTemp: sample.waterTemp,
            ceilingDepth: buhlmann.ceiling(at: sample.depthMeters),
            ndlSeconds: buhlmann.ndlSeconds(at: max(sample.depthMeters, 0), gasMix: gasMix),
            tissuePressures: buhlmann.tissuePressures
        )
    }

    // MARK: - 組織艙飽和度（視覺化用）

    /// 隔室載荷百分比：pN2 / 水面 M-value（gfHigh 收緊後）×100。
    /// >100% = 超出該 GF 下水面允許值（出水即有減壓義務的視覺訊號）。
    @MainActor
    static func tissueLoadPercent(
        pN2: [Double],
        environment: DiveEnvironment = .seaLevel
    ) -> [Double] {
        let probe = Buhlmann(environment: environment)
        let gf = probe.gfHigh
        let surfaceBar = environment.surfacePressureBar
        return zip(pN2, probe.compartments).map { p, c in
            let mValue = surfaceBar * (gf / c.bN2 + 1 - gf) + c.aN2 * gf
            return (p / mValue) * 100
        }
    }
}
