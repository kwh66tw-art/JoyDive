// DiveLogDatabase.swift — JD2Core/Models/DiveLogDatabase.swift
// v1.0 INITIAL
//
// SwiftData 數據庫初始化與管理
// 負責 DiveLog 的持久化、查詢、更新操作

import Foundation
import SwiftData

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
    func fetchDives(at location: String) throws -> [DiveLog] {
        let descriptor = FetchDescriptor<DiveLog>(
            predicate: #Predicate { dive in
                dive.location.localizedCaseInsensitiveContains(location)
            },
            sortBy: [SortDescriptor(\.dateTime, order: .reverse)]
        )
        return try context.fetch(descriptor)
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
    /// - Returns: 包含 count, totalTime, averageDepth 的字典
    func getStatistics() throws -> [String: Any] {
        let dives = try fetchAllDives()

        let count = dives.count
        let totalTime = dives.reduce(0) { $0 + $1.diveTimeSeconds }
        let averageDepth = dives.isEmpty ? 0.0 : dives.reduce(0) { $0 + $1.maxDepth } / Double(count)
        let maxDepthRecord = dives.map { $0.maxDepth }.max() ?? 0.0

        return [
            "count": count,
            "totalTime": totalTime,
            "averageDepth": averageDepth,
            "maxDepth": maxDepthRecord
        ]
    }

    // MARK: - 數據維護

    /// 清除所有潛水日誌（危險操作）
    func deleteAllDives() throws {
        try context.delete(model: DiveLog.self)
        try context.save()
    }

    /// 導出所有潛水日誌為 JSON（用於備份）
    func exportAsJSON() throws -> Data {
        let dives = try fetchAllDives()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(dives)
    }

    /// 導入潛水日誌從 JSON
    func importFromJSON(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dives = try decoder.decode([DiveLog].self, from: data)

        for dive in dives {
            context.insert(dive)
        }
        try context.save()
    }
}
