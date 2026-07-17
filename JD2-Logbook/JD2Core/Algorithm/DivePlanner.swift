// DivePlanner.swift — DiveKit/Algorithm
// JD2-Ultra 新增：免減壓計劃模式（PLAN NoDeco）
//
// 輸入：目前組織狀態（含殘氮）＋可調整的額外水面間隔
// 輸出：9–45m（3m 一檔）各深度的免減壓極限時間
//
// 業界標準行為對齊：
//   - 計入既有殘氮（直接使用現行 Buhlmann 組織壓力）
//   - SURFTIME+：可加上未來水面間隔，模擬脫飽和後再計算
//   - 演算法鎖定（Er）或 dive mode off 時，PLAN 停用（由呼叫端依 SurfaceStatus 判斷）

import Foundation

public struct DivePlanEntry: Equatable, Identifiable, Sendable {
    public var id: Double { depthMeters }
    public let depthMeters: Double
    /// 免減壓極限（秒）；Buhlmann.ndlUnlimitedMarker = 顯示 99+
    public let ndlSeconds: Int
}

public enum DivePlanner {

    /// 計算各計劃深度的 NDL。
    /// - Parameters:
    ///   - buhlmann: 即時引擎的 Buhlmann（只讀，不改動實機狀態）
    ///   - gasMix: 計劃使用的氣體
    ///   - additionalSurfaceSeconds: SURFTIME+，模擬先在水面停留再下水
    public static func plan(buhlmann: Buhlmann,
                            gasMix: GasMix,
                            additionalSurfaceSeconds: Int = 0) -> [DivePlanEntry] {
        let sim = preparedSim(buhlmann: buhlmann,
                              additionalSurfaceSeconds: additionalSurfaceSeconds)
        var entries: [DivePlanEntry] = []
        var depth = AlgorithmConstants.planMinDepth
        while depth <= AlgorithmConstants.planMaxDepth + 0.001 {
            entries.append(DivePlanEntry(depthMeters: depth,
                                         ndlSeconds: sim.ndlSeconds(at: depth, gasMix: gasMix)))
            depth += AlgorithmConstants.planDepthStep
        }
        return entries
    }

    /// 單一目標深度的 NDL（0.2.2 M17：輸入式 PLAN）。
    /// 與 `plan()` 共用同一份組織/SURFTIME+/firstCeilingBar 設定，結果一致。
    public static func ndl(at depthMeters: Double,
                           buhlmann: Buhlmann,
                           gasMix: GasMix,
                           additionalSurfaceSeconds: Int = 0) -> Int {
        let sim = preparedSim(buhlmann: buhlmann,
                              additionalSurfaceSeconds: additionalSurfaceSeconds)
        return sim.ndlSeconds(at: depthMeters, gasMix: gasMix)
    }

    /// 複製實機組織狀態到模擬器（不動實機）＋ SURFTIME+ 脫飽和 ＋ firstCeilingBar=nil（下水當下視角）。
    private static func preparedSim(buhlmann: Buhlmann,
                                    additionalSurfaceSeconds: Int) -> Buhlmann {
        let sim = Buhlmann(environment: buhlmann.environment)
        sim.gfLow = buhlmann.gfLow
        sim.gfHigh = buhlmann.gfHigh
        sim.restoreTissues(buhlmann.tissuePressures)

        // SURFTIME+ 水面脫飽和模擬（恆定 Palv，解析解步長無誤差，分塊防極端值）
        if additionalSurfaceSeconds > 0 {
            var remaining = Double(additionalSurfaceSeconds)
            let chunk = 600.0
            while remaining > 0.001 {
                let dt = min(chunk, remaining)
                sim.updateSurface(deltaT: dt)
                remaining -= dt
            }
        }
        // 計算「下水當下」的 NDL：firstCeilingBar 為 nil → 使用 gfHigh（與實機開始新潛水一致）
        sim.firstCeilingBar = nil
        return sim
    }

    /// 目前剩餘脫飽和時間（PLAN 進入畫面時短暫顯示，業界規格 步驟 2）
    public static func desaturationSeconds(buhlmann: Buhlmann) -> Int {
        DiveComputerState.desaturationSeconds(tissuePN2: buhlmann.tissuePressures,
                                              environment: buhlmann.environment)
    }
}
