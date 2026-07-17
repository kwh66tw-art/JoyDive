// ImportCoordinator.swift — JD2Core/Importers/ImportCoordinator.swift
// v1.1
// AI-generated (Claude)
//
// 統一匯入流程協調器
// 負責檔案驗證、格式自動偵測、解析、資料庫儲存的完整流程

import Foundation

/// 匯入進度回調（已處理筆數, 總筆數）
typealias ImportProgressCallback = (Int, Int) -> Void

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

    /// 錯誤紀錄
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
    ) async throws -> [DiveLog] {
        isImporting = true
        importErrors.removeAll()

        defer { isImporting = false }

        // Step 1: 驗證檔案存在
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw DiveLogImportError.fileNotFound(filePath)
        }

        // Step 2+3：稽核修復 #3 — 選格式＋解析檔案是同步、CPU 密集的工作，原本直接
        // 在 @MainActor 的 ImportCoordinator 內執行，大檔案或批次匯入多檔時會讓主
        // 執行緒卡住數秒，UI 凍結掉幀，iOS/watchOS 上甚至可能觸發 Watchdog 強制關閉
        // App。改到背景執行緒跑完整段選格式＋解析，只有結果回到主執行緒後才繼續寫
        // 資料庫（Step 4 起）。
        // ⚠️ 已知技術債：模組預設 @MainActor 隔離（-default-isolation=MainActor），
        // DiveLogImporterFactory/parse() 未標記 nonisolated，DiveLog（SwiftData
        // @Model）也非 Sendable，現行編譯設定（Swift 5 + 部分 upcoming features）
        // 下僅產生 warning、明確標註「this is an error in the Swift 6 language
        // mode」。要徹底消除需將 DiveLogImporter 協定三個方法＋全部 20 個解析器
        // 實作＋Factory 標記 nonisolated，並處理 DiveLog 跨 actor 傳遞的 Sendable
        // 問題（規模已超出本次稽核修復範圍，建議另開任務處理，屆時一併評估是否
        // 遷移到完整 Swift 6 language mode）。
        let dives = try await Task.detached(priority: .userInitiated) {
            guard let importer = DiveLogImporterFactory.selectImporter(for: filePath) else {
                throw DiveLogImportError.unsupportedFormat(filePath)
            }
            print("[Import] \(importer.format.displayName): \(filePath)")
            return try importer.parse(from: filePath)
        }.value

        guard !dives.isEmpty else {
            throw DiveLogImportError.emptyFile
        }

        // Step 4: 驗證與預處理
        let validatedDives = validateDives(dives)

        // Step 4.5: 去重（對照資料庫現有記錄，避免重複匯入）
        let newDives = try await deduplicateDives(validatedDives)
        let skippedCount = validatedDives.count - newDives.count
        if skippedCount > 0 {
            print("[Import] dedup: skipped \(skippedCount) duplicate(s)")
        }

        // Step 5: 批次儲存到資料庫（單次 save，避免 N+1 效能問題）
        if !newDives.isEmpty {
            try database.addBatch(newDives)
        }
        for index in newDives.indices {
            progressCallback?(index + 1, newDives.count)
        }

        print("[Import] done: \(newDives.count) dives imported, \(skippedCount) skipped")
        return newDives
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
                let dives = try await importFile(filePath) { processed, total in
                    totalProcessed = processed
                    progressCallback?(totalProcessed, filePaths.count * total)
                }
                successCount += dives.count
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
