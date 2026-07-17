// OxygenToxicity.swift — DiveKit/Algorithm
// 基底：JD2Core DiveEngine 內的 NOAA CNS Oxygen Clock（Audit Fix #3）
// JD2-Ultra 變更：
//   - 抽出為獨立模組，新增 OTU（Pulmonary）追蹤
//   - OLF% = max(CNS%, OTU%)（業界規格：顯示兩者較大值）
//   - 全狀態 Codable，供持久化（氧暴露跨重啟保留）

import Foundation

public struct OxygenTracker: Codable, Equatable, Sendable {

    /// CNS 累積（0–200%，NOAA 時間積分）
    public private(set) var cnsPercent: Double = 0.0

    /// OTU 累積（Oxygen Toxicity Units）
    public private(set) var otuUnits: Double = 0.0

    public init() {}

    // MARK: - OLF（Oxygen Limit Fraction）

    /// OTU 換算百分比：以單日限值 300 OTU 為 100%
    public var otuPercent: Double {
        otuUnits / AlgorithmConstants.otuDailyLimit * 100.0
    }

    /// OLF%：CNS% 與 OTU% 取大者
    public var olfPercent: Double { max(cnsPercent, otuPercent) }

    public var isWarning: Bool { olfPercent >= AlgorithmConstants.olfWarnPercent }
    public var isCritical: Bool { olfPercent >= AlgorithmConstants.olfCriticalPercent }

    // MARK: - NOAA CNS Oxygen Clock
    //
    // 原理：每秒的 CNS 累積量 = 100% ÷ 該 PO₂ 的 NOAA 允許暴露時間（秒）
    //   cnsPercent += (100.0 / limitSec) × deltaT
    //
    // 水面衰減：半衰期 90 分鐘（NOAA 標準）
    // ⚠️ 積分式：PO₂ 降低時 CNS 不會瞬間歸零（過去累積的氧毒素仍存在）

    // NOAA Diving Manual Table 3-5（PO₂ bar → 允許暴露時間 min）
    static let noaaCNSTable: [(po2: Double, limitMin: Double)] = [
        (0.60, 720.0),
        (0.70, 570.0),
        (0.80, 450.0),
        (0.90, 360.0),
        (1.00, 300.0),
        (1.10, 240.0),
        (1.20, 210.0),
        (1.30, 180.0),
        (1.40, 150.0),
        (1.50, 120.0),
        (1.60,  45.0),
    ]

    /// 依 PO₂ 查 NOAA 表格並線性插值，回傳允許暴露時間（分鐘）
    /// PO₂ < 0.6 → 無 CNS 風險，回傳 0；>= 1.6 → 使用最嚴格限制 45 min
    static func cnsLimitMinutes(for po2: Double) -> Double {
        let table = noaaCNSTable
        guard po2 >= table.first!.po2 else { return 0.0 }
        if po2 >= table.last!.po2 { return table.last!.limitMin }
        for i in 0..<(table.count - 1) {
            if po2 >= table[i].po2 && po2 < table[i + 1].po2 {
                let frac = (po2 - table[i].po2) / (table[i + 1].po2 - table[i].po2)
                return table[i].limitMin + frac * (table[i + 1].limitMin - table[i].limitMin)
            }
        }
        return table.last!.limitMin
    }

    // MARK: - OTU（REPEX / NOAA Pulmonary）
    //
    // OTU 累積率（每分鐘）= ((PO₂ − 0.5) / 0.5)^0.833，PO₂ ≤ 0.5 不累積
    // 來源：R.W. Hamilton REPEX 標準公式（業界潛水電腦通用）
    static func otuRatePerMinute(po2: Double) -> Double {
        guard po2 > 0.5 else { return 0.0 }
        return pow((po2 - 0.5) / 0.5, 0.833)
    }

    // MARK: - Update

    /// 每 tick 更新氧暴露。
    /// - Parameters:
    ///   - po2: 目前氧分壓（bar）
    ///   - deltaT: 距上次更新秒數
    ///   - isUnderwater: 水下累積；水面 CNS 指數衰減（OTU 不衰減——單日累積概念）
    public mutating func update(po2: Double, deltaT: Double, isUnderwater: Bool) {
        if isUnderwater {
            if po2 >= 0.6 {
                let limitSec = Self.cnsLimitMinutes(for: po2) * 60.0
                if limitSec > 0 {
                    cnsPercent += (100.0 / limitSec) * deltaT
                }
            }
            otuUnits += Self.otuRatePerMinute(po2: po2) * (deltaT / 60.0)
        } else {
            // 水面指數衰減：半衰期 90 分鐘（NOAA 標準）
            let halfTimeSec = AlgorithmConstants.cnsSurfaceHalfTimeMin * 60.0
            let decayFactor = exp(-log(2.0) / halfTimeSec * deltaT)
            cnsPercent *= decayFactor
        }
        cnsPercent = max(0.0, min(200.0, cnsPercent))  // 200% 上限（保護，OLF 顯示範圍 0–200%）
        otuUnits = max(0.0, otuUnits)
    }

    /// 跨日重置 OTU（單日限值概念；由上層在日界或長水面間隔時呼叫）
    public mutating func resetDailyOTU() {
        otuUnits = 0.0
    }

    public mutating func reset() {
        cnsPercent = 0.0
        otuUnits = 0.0
    }
}
