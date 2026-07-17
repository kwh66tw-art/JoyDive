// SimulatedDiveProfile.swift — DiveKit/Models
// JD2-Ultra: 模擬潛水剖面（純數學，無平台依賴）
//
// 用途：
//   1. 模擬器/展示模式的深度來源（SimulatedDepthProvider 包裝）
//   2. 單元測試的標準剖面
//
// 剖面 = 分段線性（時間點, 深度）折線；depth(at:) 內插取值。

import Foundation

public struct SimulatedDiveProfile: Codable, Equatable, Sendable {

    /// （經過秒數, 深度 m）節點，時間遞增
    public struct Node: Codable, Equatable, Sendable {
        public let timeSec: Double
        public let depthMeters: Double
        public init(timeSec: Double, depthMeters: Double) {
            self.timeSec = timeSec
            self.depthMeters = depthMeters
        }
    }

    public let name: String
    public let nodes: [Node]
    /// 模擬水溫（°C）
    public let waterTemperature: Double

    public init(name: String, nodes: [Node], waterTemperature: Double = 26.0) {
        self.name = name
        self.nodes = nodes.sorted { $0.timeSec < $1.timeSec }
        self.waterTemperature = waterTemperature
    }

    public var totalDuration: Double { nodes.last?.timeSec ?? 0 }

    /// 線性內插深度；超出範圍回傳端點值
    public func depth(at timeSec: Double) -> Double {
        guard let first = nodes.first, let last = nodes.last else { return 0 }
        if timeSec <= first.timeSec { return first.depthMeters }
        if timeSec >= last.timeSec { return last.depthMeters }
        for i in 1..<nodes.count {
            let a = nodes[i - 1], b = nodes[i]
            if timeSec <= b.timeSec {
                let f = (timeSec - a.timeSec) / max(b.timeSec - a.timeSec, 0.001)
                return a.depthMeters + (b.depthMeters - a.depthMeters) * f
            }
        }
        return last.depthMeters
    }

    // MARK: - 內建展示剖面

    /// 18m / 25min 標準免減壓潛水（含安全停留）
    public static let standardNoDeco = SimulatedDiveProfile(
        name: "18m No-Deco",
        nodes: [
            .init(timeSec: 0, depthMeters: 0),
            .init(timeSec: 90, depthMeters: 18),      // 12 m/min 下潛
            .init(timeSec: 25 * 60, depthMeters: 18), // 底部
            .init(timeSec: 27 * 60, depthMeters: 5),  // 6.5 m/min 上升
            .init(timeSec: 30 * 60, depthMeters: 5),  // 安全停留 3 min
            .init(timeSec: 31 * 60, depthMeters: 0),
        ])

    /// 32m 深潛（觸發深停與深度警報）
    public static let deepWithDeepstop = SimulatedDiveProfile(
        name: "32m Deepstop",
        nodes: [
            .init(timeSec: 0, depthMeters: 0),
            .init(timeSec: 2 * 60, depthMeters: 32),
            .init(timeSec: 14 * 60, depthMeters: 32),
            .init(timeSec: 16 * 60, depthMeters: 16),  // 8 m/min → 深停區
            .init(timeSec: 18 * 60, depthMeters: 16),  // 深停 2 min
            .init(timeSec: 19 * 60, depthMeters: 5),
            .init(timeSec: 22 * 60, depthMeters: 5),   // 安全停留
            .init(timeSec: 23 * 60, depthMeters: 0),
        ])

    /// 30m 超時 → 進入減壓（展示完整減壓引導）
    public static let decompressionDive = SimulatedDiveProfile(
        name: "30m Deco",
        nodes: [
            .init(timeSec: 0, depthMeters: 0),
            .init(timeSec: 2 * 60, depthMeters: 30),
            .init(timeSec: 32 * 60, depthMeters: 30),  // 超過 NDL
            .init(timeSec: 35 * 60, depthMeters: 9),
            .init(timeSec: 44 * 60, depthMeters: 4),   // 跟著 ceiling 減壓
            .init(timeSec: 46 * 60, depthMeters: 0),
        ])

    /// 自由潛水（3 趟 15–20m）
    public static let freedive = SimulatedDiveProfile(
        name: "Freedive 3x",
        nodes: [
            .init(timeSec: 0, depthMeters: 0),
            .init(timeSec: 30, depthMeters: 15),
            .init(timeSec: 60, depthMeters: 0),
            .init(timeSec: 3 * 60, depthMeters: 0),    // 水面休息
            .init(timeSec: 3 * 60 + 40, depthMeters: 20),
            .init(timeSec: 4 * 60 + 20, depthMeters: 0),
            .init(timeSec: 7 * 60, depthMeters: 0),
            .init(timeSec: 7 * 60 + 35, depthMeters: 18),
            .init(timeSec: 8 * 60 + 10, depthMeters: 0),
        ], waterTemperature: 27)

    public static let builtin: [SimulatedDiveProfile] = [
        .standardNoDeco, .deepWithDeepstop, .decompressionDive, .freedive,
    ]
}
