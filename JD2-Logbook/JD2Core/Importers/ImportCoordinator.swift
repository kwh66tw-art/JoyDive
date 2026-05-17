// ImportCoordinator.swift — JD2Core/Importers/ImportCoordinator.swift
// v1.0 INITIAL
//
// 統一匯入流程協調器
// 負責檔案驗證、格式自動偵測、解析、資料庫儲存的完整流程

import Foundation

/// 匯入進度回調
typealias ImportProgressCallback = (Int, Int) -> Void
typealias ImportCompletionCallback = (Result<[DiveLog], Error>) -> Void

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

    init(database: DiveLogDatabase = .shared) {
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

        // Step 2: 自動選擇解析器
        guard let importer = DiveLogImporterFactory.selectImporter(for: filePath) else {
            throw DiveLogImportError.unsupportedFormat(filePath)
        }

        print("📥 匯入: \(importer.format.displayName) (\(filePath))")

        // Step 3: 解析檔案
        let dives = try importer.parse(from: filePath)

        guard !dives.isEmpty else {
            throw DiveLogImportError.emptyFile
        }

        // Step 4: 驗證與預處理
        let validatedDives = validateDives(dives)

        // Step 5: 儲存到資料庫
        for (index, dive) in validatedDives.enumerated() {
            try database.add(dive)
            progressCallback?(index + 1, validatedDives.count)
        }

        print("✅ 成功匯入 \(validatedDives.count) 個潛水日誌")
        return validatedDives
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
        var skippedCount = 0
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
    ///   - recursive: 是否遞迴搜尋子資料夾
    ///   - progressCallback: 進度回調
    /// - Returns: 匯入統計
    func importFromDirectory(
        _ directoryPath: String,
        recursive: Bool = false,
        progressCallback: ImportProgressCallback? = nil
    ) async -> ImportStatistics {
        let fileManager = FileManager.default

        // 列出所有支援的副檔名
        let supportedExtensions = Set(
            DiveLogFormat.allCases.flatMap { $0.supportedExtensions }
        )

        // 掃描目錄
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
    private func validateDives(_ dives: [DiveLog]) -> [DiveLog] {
        return dives.filter { dive in
            // 基本驗證
            guard dive.maxDepth >= 0 else {
                importErrors.append("⚠️ 略過: 深度為負值 (\(dive.location))")
                return false
            }

            guard dive.diveTimeSeconds > 0 else {
                importErrors.append("⚠️ 略過: 潛水時間為 0 (\(dive.location))")
                return false
            }

            guard !dive.location.trimmingCharacters(in: .whitespaces).isEmpty else {
                importErrors.append("⚠️ 略過: 地點為空 (\(dive.dateFormatted))")
                return false
            }

            // 警告（但不略過）
            if dive.maxDepth > 40 {
                importErrors.append("⚠️ 警告: 深度超過 40m (\(dive.location) - \(dive.maxDepth)m)")
            }

            if dive.diveTimeSeconds > 14400 {  // 4 小時
                importErrors.append("⚠️ 警告: 潛水時間超過 4 小時 (\(dive.location))")
            }

            return true
        }
    }

    /// 檢測重複日誌（相同日期、地點、深度）
    /// - Parameter dives: 候選日誌
    /// - Returns: 未重複的日誌
    func deduplicateDives(_ dives: [DiveLog]) async throws -> [DiveLog] {
        let existing = try database.fetchAllDives()

        return dives.filter { dive in
            !existing.contains { existing in
                Calendar.current.isDate(existing.dateTime, inSameDayAs: dive.dateTime)
                    && existing.location == dive.location
                    && existing.maxDepth == dive.maxDepth
            }
        }
    }

    // MARK: - 統計與報告

    /// 生成匯入報告
    /// - Parameter statistics: 匯入統計
    /// - Returns: 格式化的報告字串
    func generateReport(_ statistics: ImportStatistics) -> String {
        var report = """
        ===============================
        📊 匯入完成報告
        ===============================
        ✅ 成功: \(statistics.successCount) 個日誌
        ❌ 失敗: \(statistics.failureCount) 個日誌
        ⏭️  略過: \(statistics.skippedCount) 個日誌
        ─────────────────────────────
        📈 成功率: \(String(format: "%.1f%%", statistics.successRate * 100))
        ⏱️  耗時: \(String(format: "%.2f", statistics.elapsedTime)) 秒
        """

        if !statistics.errors.isEmpty {
            report += "\n\n❌ 錯誤詳情:\n"
            for error in statistics.errors.prefix(5) {
                report += "  • \(error)\n"
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
