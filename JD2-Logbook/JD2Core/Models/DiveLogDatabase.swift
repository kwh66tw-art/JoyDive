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
        // v1.3（PM 2026-10-04 核准 D2）：原本失敗即 `fatalError` ⇒ 升級失敗的使用者每次開 App 都閃退。
        // 改為：記下錯誤、改用記憶體內容器讓 App 能啟動，畫面改顯示錯誤頁（`DatabaseOpenErrorView`）；
        // **不刪除、不重建、不覆寫磁碟上的資料檔**——修好之後的版本還能讀回原資料。
        switch Self.openPersistentContainer(schema: schema, configuration: modelConfiguration) {
        case .success(let container):
            self.modelContainer = container
            self.openError = nil
            Self.migrateLegacySDEZeroWaterTemperature(context: container.mainContext)
        case .failure(let error):
            self.modelContainer = Self.inMemoryFallback(schema: schema)
            self.openError = error
        }
    }

    /// 開啟磁碟上的資料庫失敗時的錯誤；`nil`＝正常。非 nil 時 App 只顯示錯誤頁、不顯示（也不寫入）日誌。
    let openError: Error?

    /// 開啟磁碟資料庫；失敗回傳錯誤而非終止程式（抽出為靜態函式以便測試）。
    static func openPersistentContainer(schema: Schema,
                                        configuration: ModelConfiguration) -> Result<ModelContainer, Error> {
        do {
            return .success(try ModelContainer(for: schema, configurations: [configuration]))
        } catch {
            return .failure(error)
        }
    }

    /// 開檔失敗時的備援：只在記憶體、不碰磁碟。連這個都建不起來代表執行環境本身壞了，才終止。
    static func inMemoryFallback(schema: Schema) -> ModelContainer {
        do {
            return try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            )
        } catch {
            fatalError("無法建立記憶體內 SwiftData 容器: \(error)")
        }
    }

    // MARK: - 一次性資料修正

    /// v1.3 舊資料遷移旗標（UserDefaults key）。
    static let sdeZeroTempMigrationKey = "jd2.migration.v13.sdeZeroWaterTemp"

    /// v1.3（PM 2026-10-06 裁示 A）：舊版 SDE 匯入把「感測器沒有讀數」的 0 存成水溫 0 °C
    /// （DiveImportKit v0.3.0 起取全部樣本最小值，SDE 缺值樣本寫 0）。v0.7.3 起新匯入已改為 nil；
    /// 這裡把**已匯入**的 `suunto-sde` 且水溫恰為 0 的紀錄改為「未記錄」。只跑一次（旗標）。
    /// 已知代價：真實 0 °C 的 SDE 紀錄也會變成未記錄（PM 接受；SDE 無法區分兩者）。
    /// - Returns: 修正筆數；已跑過回傳 nil。
    @discardableResult
    static func migrateLegacySDEZeroWaterTemperature(context: ModelContext,
                                                     defaults: UserDefaults = .standard) -> Int? {
        guard !defaults.bool(forKey: sdeZeroTempMigrationKey) else { return nil }
        let descriptor = FetchDescriptor<DiveLog>(
            predicate: #Predicate { $0.sourceFormat == "suunto-sde" && $0.waterTemperature == 0 }
        )
        do {
            let dives = try context.fetch(descriptor)
            for dive in dives { dive.waterTemperature = nil }
            if !dives.isEmpty { try context.save() }
            defaults.set(true, forKey: sdeZeroTempMigrationKey)
            return dives.count
        } catch {
            // 失敗不設旗標，下次啟動重試；不影響 App 使用。
            print("[Migration] SDE 0 °C 修正失敗：\(error)")
            return 0
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
