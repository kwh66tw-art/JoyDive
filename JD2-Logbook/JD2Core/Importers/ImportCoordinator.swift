// ImportCoordinator.swift — JD2Core/Importers/ImportCoordinator.swift
// v1.1
// AI-generated (Claude)
//
// 統一匯入流程協調器
// 負責檔案驗證、格式自動偵測、解析、資料庫儲存的完整流程

import Foundation

/// 匯入進度回調（已處理筆數, 總筆數）
typealias ImportProgressCallback = (Int, Int) -> Void

/// 單一檔案匯入結果
struct ImportFileResult {
    /// 實際新增的潛水日誌
    let dives: [DiveLog]

    /// 因去重（重複）而略過的筆數
    let skippedDuplicates: Int
}

/// 匯入結果統計
struct ImportStatistics {
    /// 成功匯入的日誌數
    let successCount: Int

    /// 失敗的日誌數
    let failureCount: Int

    /// 略過的日誌數（重複或無效）
    let skippedCount: Int

    /// 總耗時（秒）
    let elapsedTime: TimeInterval

    /// 錯誤詳情
    let errors: [String]

    var totalCount: Int {
        successCount + failureCount + skippedCount
    }

    var successRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(successCount) / Double(totalCount)
    }
}

/// 匯入協調器
@MainActor
final class ImportCoordinator {

    /// 資料庫實例
    let database: DiveLogDatabase

    /// 當前匯入狀態
    private(set) var isImporting: Bool = false

    /// 錯誤紀錄（`validateDives(_: [DiveLog])` 系列本地方法使用，供直接以
    /// SwiftData 型別測試驗證邏輯；實際匯入流程走下方 Kit 背景安全路徑，不經過這裡）
    private var importErrors: [String] = []

    // MARK: - 初始化

    // NOTE: DiveLogDatabase.shared is @MainActor isolated; do not use as default
    // parameter value in Swift 6 strict concurrency mode.
    init(database: DiveLogDatabase) {
        self.database = database
    }

    // MARK: - 主要匯入流程

    /// 匯入單個檔案
    /// - Parameters:
    ///   - filePath: 檔案路徑
    ///   - progressCallback: 進度回調（已處理, 總數）
    /// - Returns: 匯入的潛水日誌
    func importFile(
        _ filePath: String,
        progressCallback: ImportProgressCallback? = nil
    ) async throws -> ImportFileResult {
        isImporting = true
        importErrors.removeAll()

        defer { isImporting = false }

        // Step 1: 驗證檔案存在
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw DiveLogImportError.fileNotFound(filePath)
        }

        // Step 2+3：家族層 import 共用第二階段（2026-07-19）修復 SYNC #3——選格式＋
        // 解析＋驗證改呼叫 DiveImportKit（透過 DiveImportKitAdapter 的背景安全
        // 包裝函式），操作的是 Sendable 的 ParsedDiveLog，天生可以安全跑在背景
        // Task，不像本地 DiveLogImporter 協定回傳 SwiftData DiveLog 那樣有跨
        // actor 邊界的 Sendable 問題（先前用 Task.detached 硬包一層只能消掉
        // warning，Swift 6 語言模式下仍是編譯器明確標註的未解決問題）。
        let parsedDives = try await Task.detached(priority: .userInitiated) {
            if let name = formatDisplayName(for: filePath) {
                print("[Import] \(name): \(filePath)")
            }
            return try parseAndValidateForBackground(filePath: filePath)
        }.value

        // Step 4：去重（對照資料庫現有記錄；修復 SYNC #2，邏輯與 Kit 共用，
        // 不再各自維護容易走鐘的版本）
        let existing = try database.fetchAllDives()
        let (keptParsed, skippedCount) = dedupeAgainstExisting(parsedDives, existing: existing)
        if skippedCount > 0 {
            print("[Import] dedup: skipped \(skippedCount) duplicate(s)")
        }

        // Step 5：轉換回 SwiftData DiveLog（輕量、MainActor 上做無妨）＋
        // v1.1 #8：來源格式無 avgDepth 但有剖面樣本時，梯形近似重建
        let newDives = keptParsed.map(makeDiveLog(from:))
        for dive in newDives where dive.avgDepth <= 0 {
            dive.avgDepth = dive.reconstructedAvgDepth()
        }

        // Step 6：批次儲存到資料庫（單次 save，避免 N+1 效能問題）
        if !newDives.isEmpty {
            try database.addBatch(newDives)
        }
        for index in newDives.indices {
            progressCallback?(index + 1, newDives.count)
        }

        print("[Import] done: \(newDives.count) dives imported, \(skippedCount) skipped")
        return ImportFileResult(dives: newDives, skippedDuplicates: skippedCount)
    }

    /// 批量匯入多個檔案
    /// - Parameters:
    ///   - filePaths: 檔案路徑陣列
    ///   - progressCallback: 進度回調
    /// - Returns: 匯入統計
    func importMultipleFiles(
        _ filePaths: [String],
        progressCallback: ImportProgressCallback? = nil
    ) async -> ImportStatistics {
        let startTime = Date()
        var successCount = 0
        var failureCount = 0
        let skippedCount = 0
        var allErrors: [String] = []
        var totalProcessed = 0

        for filePath in filePaths {
            do {
                let result = try await importFile(filePath) { processed, total in
                    totalProcessed = processed
                    progressCallback?(totalProcessed, filePaths.count * total)
                }
                successCount += result.dives.count
            } catch {
                failureCount += 1
                allErrors.append("[\(filePath)] \(error.localizedDescription)")
            }
        }

        let elapsedTime = Date().timeIntervalSince(startTime)

        return ImportStatistics(
            successCount: successCount,
            failureCount: failureCount,
            skippedCount: skippedCount,
            elapsedTime: elapsedTime,
            errors: allErrors
        )
    }

    /// 從目錄匯入所有支援格式的檔案
    /// - Parameters:
    ///   - directoryPath: 目錄路徑
    ///   - progressCallback: 進度回調
    /// - Returns: 匯入統計
    /// - Note: 目前只掃描第一層，不遞迴。Week 8 再實作遞迴版本。
    func importFromDirectory(
        _ directoryPath: String,
        progressCallback: ImportProgressCallback? = nil
    ) async -> ImportStatistics {
        let fileManager = FileManager.default

        // 列出所有支援的副檔名
        let supportedExtensions = Set(
            DiveLogFormat.allCases.flatMap { $0.supportedExtensions }
        )

        // 掃描第一層目錄（非遞迴）
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directoryPath) else {
            return ImportStatistics(
                successCount: 0,
                failureCount: 0,
                skippedCount: 0,
                elapsedTime: 0,
                errors: ["無法讀取目錄: \(directoryPath)"]
            )
        }

        let filePaths = contents
            .filter { filename in
                let ext = (filename as NSString).pathExtension.lowercased()
                return supportedExtensions.contains(ext)
            }
            .map { (directoryPath as NSString).appendingPathComponent($0) }

        return await importMultipleFiles(filePaths, progressCallback: progressCallback)
    }

    // MARK: - 驗證與預處理

    /// 驗證潛水日誌合理性
    /// - Parameter dives: 潛水日誌陣列
    /// - Returns: 有效的潛水日誌
    /// - Note: location 可為空字串（CSV 及 Suunto JSON 匯入時不填 location），不作為過濾條件
    func validateDives(_ dives: [DiveLog]) -> [DiveLog] {
        return dives.filter { dive in
            // 基本驗證
            guard dive.maxDepth >= 0 else {
                importErrors.append("[skip] negative depth (\(dive.location))")
                return false
            }

            guard dive.diveTimeSeconds > 0 else {
                importErrors.append("[skip] zero dive time (\(dive.location))")
                return false
            }

            // v1.1 #8：來源格式無 avgDepth 但有剖面樣本時，梯形近似重建
            if dive.avgDepth <= 0 {
                dive.avgDepth = dive.reconstructedAvgDepth()
            }

            // 警告（但不略過）
            if dive.maxDepth > 40 {
                importErrors.append("[warn] depth > 40m (\(dive.location) - \(dive.maxDepth)m)")
            }

            if dive.diveTimeSeconds > 14400 {  // 4 小時
                importErrors.append("[warn] dive time > 4h (\(dive.location))")
            }

            return true
        }
    }

    /// 檢測重複日誌（相同地點、深度，且時間差小於 60 秒）
    /// - Parameter dives: 候選日誌
    /// - Returns: 未重複的日誌
    /// - Note: 使用精確時間差比對（< 60s），避免同一天兩次相同深度的潛水被誤判重複。
    // 稽核修復 #2：原本用 .filter 對照資料庫既有記錄，若同一批次（甚至單一檔案）
    // 內部含有彼此重複的日誌，因為此時都尚未寫入資料庫，會互相漏檢、全數通過。
    // 改為逐筆比對＋動態把已確認非重複的日誌併入比對陣列，與 DiveLogDatabase.
    // importFromJSON 的既有正確做法一致（見該檔案備份還原邏輯）。
    func deduplicateDives(_ dives: [DiveLog]) async throws -> [DiveLog] {
        let existing = try database.fetchAllDives()
        return Self.dedupe(dives, against: existing)
    }

    /// 純邏輯版本，不碰資料庫，方便單元測試（與上面 deduplicateDives 共用）
    static func dedupe(_ dives: [DiveLog], against existing: [DiveLog]) -> [DiveLog] {
        var existing = existing
        var newDives: [DiveLog] = []

        for dive in dives {
            let isDuplicate = existing.contains { ex in
                abs(ex.dateTime.timeIntervalSince(dive.dateTime)) < 60
                    && ex.location == dive.location
                    && ex.maxDepth == dive.maxDepth
            }
            guard !isDuplicate else { continue }
            newDives.append(dive)
            existing.append(dive)   // 避免同一批次內的重複條目互相漏檢
        }

        return newDives
    }

    // MARK: - 統計與報告

    /// 生成匯入報告
    /// - Parameter statistics: 匯入統計
    /// - Returns: 格式化的報告字串
    func generateReport(_ statistics: ImportStatistics) -> String {
        var report = """
        ===============================
        匯入完成報告
        ===============================
        成功: \(statistics.successCount) 個日誌
        失敗: \(statistics.failureCount) 個日誌
        略過: \(statistics.skippedCount) 個日誌
        -------------------------------
        成功率: \(String(format: "%.1f%%", statistics.successRate * 100))
        耗時: \(String(format: "%.2f", statistics.elapsedTime)) 秒
        """

        if !statistics.errors.isEmpty {
            report += "\n\n錯誤詳情:\n"
            for error in statistics.errors.prefix(5) {
                report += "  - \(error)\n"
            }
            if statistics.errors.count > 5 {
                report += "  ... 及其他 \(statistics.errors.count - 5) 個錯誤\n"
            }
        }

        report += "\n==============================="
        return report
    }

    // MARK: - 工具方法

    /// 取得支援的格式清單
    static func supportedFormats() -> [DiveLogFormat] {
        DiveLogFormat.allCases
    }

    /// 驗證檔案格式是否支援
    static func isFormatSupported(_ format: String) -> Bool {
        DiveLogFormat(rawValue: format) != nil
    }
}
