// DiveLogDatabase.swift — JD2Core/Models/DiveLogDatabase.swift
// v1.0 INITIAL
//
// SwiftData 數據庫初始化與管理
// 負責 DiveLog 的持久化、查詢、更新操作

import Foundation
import SwiftData

/// 潛水日誌彙總統計（次數/總時長/平均深度/最大深度）
struct DiveStatistics {
    let count: Int
    let totalTime: Int
    let averageDepth: Double
    let maxDepth: Double
}

/// SwiftData 模型容器與數據操作管理器
@MainActor
final class DiveLogDatabase {

    /// 共享全域實例
    static let shared = DiveLogDatabase()

    /// SwiftData ModelContainer
    let modelContainer: ModelContainer

    /// SwiftData ModelContext
    var context: ModelContext {
        modelContainer.mainContext
    }

    // MARK: - 初始化

    private init() {
        // 設定 SwiftData schema
        let schema = Schema([
            DiveLog.self
        ])

        // 設定 ModelConfiguration
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,  // 持久化到磁碟
            allowsSave: true
        )

        // 初始化 ModelContainer
        do {
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("無法初始化 SwiftData ModelContainer: \(error)")
        }
    }

    // MARK: - CRUD 操作

    /// 新增潛水日誌
    /// - Parameter diveLog: 潛水日誌實例
    func add(_ diveLog: DiveLog) throws {
        context.insert(diveLog)
        try context.save()
    }

    /// 批次新增多筆潛水日誌（僅 save 一次，避免 N+1 save）
    /// - Parameter diveLogs: 潛水日誌陣列
    func addBatch(_ diveLogs: [DiveLog]) throws {
        guard !diveLogs.isEmpty else { return }
        for diveLog in diveLogs {
            context.insert(diveLog)
        }
        try context.save()
    }

    /// 刪除潛水日誌
    /// - Parameter diveLog: 潛水日誌實例
    func delete(_ diveLog: DiveLog) throws {
        context.delete(diveLog)
        try context.save()
    }

    /// 更新潛水日誌
    /// - Parameter diveLog: 修改後的潛水日誌
    func update(_ diveLog: DiveLog) throws {
        try context.save()
    }

    // MARK: - 查詢操作

    /// 取得所有潛水日誌（按日期降序）
    func fetchAllDives() throws -> [DiveLog] {
        let descriptor = FetchDescriptor<DiveLog>(
            sortBy: [SortDescriptor(\.dateTime, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// 取得特定日期範圍的潛水日誌
    /// - Parameters:
    ///   - startDate: 開始日期
    ///   - endDate: 結束日期
    func fetchDives(from startDate: Date, to endDate: Date) throws -> [DiveLog] {
        let descriptor = FetchDescriptor<DiveLog>(
            predicate: #Predicate { dive in
                dive.dateTime >= startDate && dive.dateTime <= endDate
            },
            sortBy: [SortDescriptor(\.dateTime, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// 取得特定地點的所有潛水日誌
    /// - Parameter location: 地點名稱
    /// - Note: SwiftData #Predicate 不支援 localizedCaseInsensitiveContains，改為 fetch-then-filter
    func fetchDives(at location: String) throws -> [DiveLog] {
        let descriptor = FetchDescriptor<DiveLog>(
            sortBy: [SortDescriptor(\.dateTime, order: .reverse)]
        )
        let all = try context.fetch(descriptor)
        return all.filter { $0.location.localizedCaseInsensitiveContains(location) }
    }

    /// 取得深度超過閾值的潛水日誌
    /// - Parameter depth: 深度閾值（公尺）
    func fetchDeepDives(greaterThan depth: Double) throws -> [DiveLog] {
        let descriptor = FetchDescriptor<DiveLog>(
            predicate: #Predicate { dive in
                dive.maxDepth > depth
            },
            sortBy: [SortDescriptor(\.maxDepth, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// 取得總潛水日誌數
    func countDives() throws -> Int {
        return try context.fetchCount(FetchDescriptor<DiveLog>())
    }

    /// 取得統計信息
    func getStatistics() throws -> DiveStatistics {
        let dives = try fetchAllDives()

        let count = dives.count
        let totalTime = dives.reduce(0) { $0 + $1.diveTimeSeconds }
        let averageDepth = dives.isEmpty ? 0.0 : dives.reduce(0) { $0 + $1.maxDepth } / Double(count)
        let maxDepthRecord = dives.map { $0.maxDepth }.max() ?? 0.0

        return DiveStatistics(
            count: count,
            totalTime: totalTime,
            averageDepth: averageDepth,
            maxDepth: maxDepthRecord
        )
    }

    // MARK: - 數據維護

    /// 清除所有潛水日誌（危險操作）
    func deleteAllDives() throws {
        try context.delete(model: DiveLog.self)
        try context.save()
    }

    /// 導出所有潛水日誌為 JSON（用於備份）
    /// v1.1 #14：DiveLogBackupEntry DTO 承載完整欄位（含 profileSamplesJSON / importExtrasJSON）
    func exportAsJSON() throws -> Data {
        let dives = try fetchAllDives()
        let entries = dives.map(DiveLogBackupEntry.init(from:))
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
        let backup = DiveLogBackup(appVersion: appVersion, dives: entries)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    /// 導入潛水日誌從 JSON（備份還原）
    /// - 去重規則與 ImportCoordinator 一致：同地點、同深度、時間差 < 60 秒視為重複
    /// - Returns: (imported, skipped) 筆數
    @discardableResult
    func importFromJSON(_ data: Data) throws -> (imported: Int, skipped: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup: DiveLogBackup
        do {
            backup = try decoder.decode(DiveLogBackup.self, from: data)
        } catch {
            throw DiveLogImportError.parsingFailed("備份檔案格式錯誤", underlyingError: error)
        }
        guard !backup.dives.isEmpty else { throw DiveLogImportError.emptyFile }

        let existing = try fetchAllDives()
        let (kept, skippedCount) = dedupeBackupEntries(backup.dives, against: existing)
        for entry in kept {
            context.insert(entry.makeDiveLog())
        }

        if !kept.isEmpty {
            try context.save()
        }
        return (kept.count, skippedCount)
    }
}
