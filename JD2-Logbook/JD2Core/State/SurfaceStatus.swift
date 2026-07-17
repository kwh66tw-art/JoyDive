// SurfaceStatus.swift — DiveKit/State
// JD2-Ultra 新增：水面間隔 / 禁飛時間 / 演算法鎖定（Er）狀態
// 對應減壓鎖定（Er）與水面/禁飛時間
//
// ⚠️ 安全狀態：必須隨 DiveComputerState 持久化，App 重啟後正確還原。

import Foundation

public struct SurfaceStatus: Codable, Equatable, Sendable {

    /// 最近一次浮出水面時間（nil = 尚無潛水紀錄）
    public var lastSurfacedAt: Date?

    /// 禁飛截止時間（nil = 無禁飛限制）
    public var noFlyUntil: Date?

    /// 演算法鎖定（Er）截止時間（nil = 未鎖定）
    /// 業界規格：omit deco > 3 分鐘 → 鎖定 48 小時；鎖定中再潛 → 浮出時重置 48h
    public var algorithmLockedUntil: Date?

    /// 0.2.0(A7)：Gauge 模式使用後的演算法鎖定（24h 內組織數據不可信，
    /// 只能 Gauge/Free；業界同款行為）。Optional：舊快照無此欄位，解碼為 nil
    public var gaugeLockedUntil: Date?

    /// 本次連續潛水系列的潛水支數（禁飛結束後歸零；「連續潛水系列」）
    public var divesInSeries: Int = 0

    /// M22：上次潛水摘要（watch face／complication 顯示）。Optional：舊快照無此欄位，解碼為 nil
    public var lastDiveMaxDepth: Double?
    public var lastDiveDurationSec: Int?

    /// 稽核 2026-07-03 B：最後一次「水中活動」時間（浮潛等無氮負載活動）。
    /// 僅供水面間隔**顯示**——刻意與 `lastSurfacedAt`（系列/禁飛判定輸入）分離，
    /// 避免無氮負載的浮潛把下一次水肺誤判成重複潛水系列。Optional：舊快照相容。
    public var lastWaterActivityAt: Date?

    public init() {}

    // MARK: - 查詢

    public func surfaceIntervalSeconds(now: Date = Date()) -> Int? {
        // 顯示用：取「最近一次出水」——含浮潛等水中活動（lastWaterActivityAt）
        let candidates = [lastSurfacedAt, lastWaterActivityAt].compactMap { $0 }
        guard let t = candidates.max() else { return nil }
        return max(0, Int(now.timeIntervalSince(t)))
    }

    public func noFlyRemainingSeconds(now: Date = Date()) -> Int {
        guard let until = noFlyUntil else { return 0 }
        return max(0, Int(until.timeIntervalSince(now)))
    }

    public func isAlgorithmLocked(now: Date = Date()) -> Bool {
        guard let until = algorithmLockedUntil else { return false }
        return now < until
    }

    public func algorithmLockRemainingSeconds(now: Date = Date()) -> Int {
        guard let until = algorithmLockedUntil else { return 0 }
        return max(0, Int(until.timeIntervalSince(now)))
    }

    // 0.2.0(A7)：Gauge 鎖定查詢
    public func isGaugeLocked(now: Date = Date()) -> Bool {
        guard let until = gaugeLockedUntil else { return false }
        return now < until
    }

    public func gaugeLockRemainingSeconds(now: Date = Date()) -> Int {
        guard let until = gaugeLockedUntil else { return 0 }
        return max(0, Int(until.timeIntervalSince(now)))
    }

    /// 0.2.0(A7)：Gauge 潛水結束 → 鎖定 24h（再用 Gauge 重置）
    public mutating func gaugeDiveEnded(at now: Date = Date()) {
        gaugeLockedUntil = now.addingTimeInterval(24 * 3600)
    }

    // MARK: - 事件

    /// 潛水結束（浮出且確認）時呼叫，更新禁飛與系列計數。
    /// - Parameters:
    ///   - decoViolated: 本次潛水是否觸發演算法鎖定（Er）
    ///   - desaturationSeconds: 估計脫飽和時間（秒）；業界慣例：禁飛 = max(12h, 脫飽和時間)
    public mutating func diveEnded(at now: Date = Date(),
                                   decoViolated: Bool,
                                   desaturationSeconds: Int) {
        // 系列判定：禁飛尚未結束（或 12h 內）再潛 → 同一系列
        if let last = lastSurfacedAt,
           now.timeIntervalSince(last) < Double(AlgorithmConstants.repetitiveDiveWindowHours) * 3600 {
            divesInSeries += 1
        } else {
            divesInSeries = 1
        }
        lastSurfacedAt = now

        // 審計 R4（業界規格 明文）：「鎖定狀態下再潛水，浮出時鎖定重置為 48 小時」——
        // 不論本次潛水是否再違規，只要結束時仍在鎖定期就重置
        if decoViolated || isAlgorithmLocked(now: now) {
            algorithmLockedUntil = now.addingTimeInterval(
                Double(AlgorithmConstants.algorithmLockHours) * 3600)
        }

        // 禁飛時間（業界規格 + DAN）：
        //   Er 違規 → 48h
        //   多次重複潛水系列 → 至少 18h
        //   單次 → 至少 12h
        //   脫飽和時間 > 下限 → 取脫飽和時間
        //   脫飽和 < 70 min → 不顯示禁飛（業界慣例：desaturation < 70min 不顯示）
        let baseHours: Int
        if isAlgorithmLocked(now: now) {
            baseHours = AlgorithmConstants.noFlyDecoViolationHours
        } else if divesInSeries > 1 {
            baseHours = AlgorithmConstants.noFlyMinHoursMulti
        } else {
            baseHours = AlgorithmConstants.noFlyMinHoursSingle
        }

        if desaturationSeconds < AlgorithmConstants.noFlyShowThresholdMin * 60
            && !isAlgorithmLocked(now: now) && divesInSeries <= 1 {
            noFlyUntil = nil   // 短淺潛水：不顯示禁飛
        } else {
            let noFlySec = max(baseHours * 3600, desaturationSeconds)
            noFlyUntil = now.addingTimeInterval(Double(noFlySec))
        }
    }

    /// 跨重啟還原後的清理：過期的鎖定/禁飛歸零、系列計數逾時重置
    public mutating func refresh(now: Date = Date()) {
        if let until = algorithmLockedUntil, now >= until {
            algorithmLockedUntil = nil
        }
        if let until = gaugeLockedUntil, now >= until {
            gaugeLockedUntil = nil
        }
        if let until = noFlyUntil, now >= until {
            noFlyUntil = nil
        }
        if let last = lastSurfacedAt,
           now.timeIntervalSince(last) >= Double(AlgorithmConstants.repetitiveDiveWindowHours) * 3600,
           noFlyUntil == nil {
            divesInSeries = 0
        }
    }
}
