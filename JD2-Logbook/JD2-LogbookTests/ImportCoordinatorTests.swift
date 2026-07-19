// ImportCoordinatorTests.swift — JD2-LogbookTests
// Week 6：ImportCoordinator 整合測試
// AI-generated (Claude)
//
// 測試策略：
//   DiveLogDatabase 為 @MainActor singleton，無法在單元測試中替換。
//   本測試專注在不碰資料庫的邏輯層：
//     - DiveLogImporterFactory 格式偵測（4 種格式）
//     - validateDives 合法性過濾（深度負值、時間 0、location 空字串可通過）
//     - generateReport 報告格式
//     - ImportStatistics 計算（successRate、totalCount）
//     - 各解析器 parse(from:) 能正確解析真實檔案
//
// 測試樣本（TestFiles/，位於 repo 根目錄）：
//   UDDF/test42.uddf
//   CSV/test41.csv
//   Suunto/suunto_eon_core_nitrox.json
//   Suunto/suunto_ocean_air.json

import XCTest
@testable import JoyDive_

@MainActor
final class ImportCoordinatorTests: XCTestCase {

    // MARK: - 路徑工具

    /// repo 根目錄（TestFiles/ 的父目錄）
    private var repoRoot: String {
        let here       = (#filePath as NSString).deletingLastPathComponent  // .../JD2-LogbookTests
        let moduleRoot = (here as NSString).deletingLastPathComponent       // .../JD2-Logbook
        return (moduleRoot as NSString).deletingLastPathComponent           // .../JD2-Logbook (repo)
    }

    private func testFilePath(_ relativePath: String) -> String {
        (repoRoot as NSString).appendingPathComponent("../_JD2-family/dive-log-samples/\(relativePath)")
    }

    // MARK: - 輔助：建立最小合法 DiveLog

    private func makeDive(
        depth: Double = 20.0,
        duration: Int = 3600,
        location: String = "Test Site"
    ) -> DiveLog {
        let dive = DiveLog(
            dateTime: Date(),
            location: location,
            maxDepth: depth,
            diveTimeSeconds: duration,
            gasMixJSON: "\"air\"",
            waterTemperature: 25.0
        )
        dive.sourceFormat = "test"
        return dive
    }

    // MARK: - ImportCoordinator 建立

    private func makeCoordinator() -> ImportCoordinator {
        // 使用共享資料庫；本測試不呼叫 importFile，不會實際寫入
        ImportCoordinator(database: .shared)
    }

    // MARK: - validateDives

    func testValidateDivesPassesNormalDive() {
        let coordinator = makeCoordinator()
        let dives = [makeDive()]
        let result = coordinator.validateDives(dives)
        XCTAssertEqual(result.count, 1)
    }

    func testValidateDivesRejectsNegativeDepth() {
        let coordinator = makeCoordinator()
        let dives = [makeDive(depth: -1.0)]
        let result = coordinator.validateDives(dives)
        XCTAssertEqual(result.count, 0, "負深度應被過濾")
    }

    func testValidateDivesRejectsZeroDuration() {
        let coordinator = makeCoordinator()
        let dives = [makeDive(duration: 0)]
        let result = coordinator.validateDives(dives)
        XCTAssertEqual(result.count, 0, "潛水時間為 0 應被過濾")
    }

    func testValidateDivesAllowsZeroDepth() {
        // 零深度（例如海面訓練記錄）不應被過濾
        let coordinator = makeCoordinator()
        let dives = [makeDive(depth: 0.0)]
        let result = coordinator.validateDives(dives)
        XCTAssertEqual(result.count, 1, "深度 0 應通過（>=0）")
    }

    func testValidateDivesAllowsEmptyLocation() {
        // CSV 及 Suunto JSON 匯入時 location 為空字串，不應被過濾
        let coordinator = makeCoordinator()
        let dives = [makeDive(location: ""), makeDive(location: "   ")]
        let result = coordinator.validateDives(dives)
        XCTAssertEqual(result.count, 2, "location 為空字串或空白應通過（CSV/Suunto JSON 的正常情況）")
    }

    func testValidateDivesFiltersMultipleInvalid() {
        let coordinator = makeCoordinator()
        let dives = [
            makeDive(depth: 20, duration: 3600),   // valid
            makeDive(depth: -5, duration: 3600),   // invalid: negative depth
            makeDive(depth: 20, duration: 0),      // invalid: zero duration
            makeDive(depth: 0,  duration: 1800),   // valid: zero depth is ok
        ]
        let result = coordinator.validateDives(dives)
        XCTAssertEqual(result.count, 2)
    }

    func testValidateDivesDeepDivePassesWithWarning() {
        // 超過 40m 應通過（只是加入警告訊息，不過濾）
        let coordinator = makeCoordinator()
        let dives = [makeDive(depth: 45.0, duration: 2400)]
        let result = coordinator.validateDives(dives)
        XCTAssertEqual(result.count, 1, "超過 40m 深度應通過驗證（記錄警告但不過濾）")
    }

    func testValidateDivesLongDivePassesWithWarning() {
        // 超過 4 小時應通過（只是加入警告訊息，不過濾）
        let coordinator = makeCoordinator()
        let dives = [makeDive(duration: 18000)]  // 5 小時
        let result = coordinator.validateDives(dives)
        XCTAssertEqual(result.count, 1, "超過 4 小時的潛水應通過驗證（記錄警告但不過濾）")
    }

    // MARK: - ImportStatistics

    func testImportStatisticsTotalCount() {
        let stats = ImportStatistics(
            successCount: 10,
            failureCount: 2,
            skippedCount: 1,
            elapsedTime: 1.5,
            errors: []
        )
        XCTAssertEqual(stats.totalCount, 13)
    }

    func testImportStatisticsSuccessRate() {
        let stats = ImportStatistics(
            successCount: 8,
            failureCount: 2,
            skippedCount: 0,
            elapsedTime: 0.5,
            errors: []
        )
        XCTAssertEqual(stats.successRate, 0.8, accuracy: 0.001)
    }

    func testImportStatisticsSuccessRateZeroWhenEmpty() {
        let stats = ImportStatistics(
            successCount: 0,
            failureCount: 0,
            skippedCount: 0,
            elapsedTime: 0,
            errors: []
        )
        XCTAssertEqual(stats.successRate, 0.0)
    }

    // MARK: - generateReport

    func testGenerateReportContainsSuccessCount() {
        let coordinator = makeCoordinator()
        let stats = ImportStatistics(
            successCount: 5,
            failureCount: 1,
            skippedCount: 2,
            elapsedTime: 0.3,
            errors: []
        )
        let report = coordinator.generateReport(stats)
        XCTAssertTrue(report.contains("5"), "報告應包含成功數 5")
        XCTAssertTrue(report.contains("1"), "報告應包含失敗數 1")
        XCTAssertTrue(report.contains("2"), "報告應包含略過數 2")
    }

    func testGenerateReportContainsSuccessRate() {
        let coordinator = makeCoordinator()
        let stats = ImportStatistics(
            successCount: 1,
            failureCount: 1,
            skippedCount: 0,
            elapsedTime: 0.1,
            errors: []
        )
        let report = coordinator.generateReport(stats)
        XCTAssertTrue(report.contains("50.0%"), "報告應包含成功率 50.0%")
    }

    func testGenerateReportIncludesErrorsWhenPresent() {
        let coordinator = makeCoordinator()
        let stats = ImportStatistics(
            successCount: 0,
            failureCount: 1,
            skippedCount: 0,
            elapsedTime: 0.05,
            errors: ["[file.csv] 格式不支援"]
        )
        let report = coordinator.generateReport(stats)
        XCTAssertTrue(report.contains("file.csv"), "報告應包含錯誤詳情")
    }

    func testGenerateReportOmitsErrorSectionWhenNoErrors() {
        let coordinator = makeCoordinator()
        let stats = ImportStatistics(
            successCount: 3,
            failureCount: 0,
            skippedCount: 0,
            elapsedTime: 0.2,
            errors: []
        )
        let report = coordinator.generateReport(stats)
        XCTAssertFalse(report.contains("錯誤詳情"), "無錯誤時不應出現錯誤詳情章節")
    }

    func testGenerateReportTruncatesLongErrorList() {
        let coordinator = makeCoordinator()
        let manyErrors = (1...10).map { "error \($0)" }
        let stats = ImportStatistics(
            successCount: 0,
            failureCount: 10,
            skippedCount: 0,
            elapsedTime: 1.0,
            errors: manyErrors
        )
        let report = coordinator.generateReport(stats)
        // 只顯示前 5 條，其餘顯示摘要
        XCTAssertTrue(report.contains("5 個錯誤"), "超過 5 條錯誤時應顯示剩餘數量摘要")
    }

    // MARK: - DiveLogImporterFactory 格式偵測

    func testFactorySelectsUDDFParser() {
        let path = testFilePath("UDDF/test42.uddf")
        let importer = DiveLogImporterFactory.selectImporter(for: path)
        XCTAssertNotNil(importer, "應找到 UDDF 解析器")
        XCTAssertEqual(importer?.format, .uddf)
    }

    func testFactorySelectsCSVParser() throws {
        let path = testFilePath("CSV/test41.csv")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: path),
                          "測試檔案不存在，略過：test41.csv")
        let importer = DiveLogImporterFactory.selectImporter(for: path)
        XCTAssertNotNil(importer, "應找到 CSV 解析器")
        XCTAssertEqual(importer?.format, .csv)
    }

    func testFactorySelectsSuuntoJSONParser() throws {
        let path = testFilePath("Suunto/suunto_eon_core_nitrox.json")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: path),
                          "測試檔案不存在，略過：suunto_eon_core_nitrox.json")
        let importer = DiveLogImporterFactory.selectImporter(for: path)
        XCTAssertNotNil(importer, "應找到 Suunto JSON 解析器")
        XCTAssertEqual(importer?.format, .suunto)
    }

    func testFactoryReturnsNilForUnsupportedExtension() {
        let importer = DiveLogImporterFactory.selectImporter(for: "/some/file.xyz")
        XCTAssertNil(importer, "不支援的副檔名應返回 nil")
    }

    func testFactoryReturnsNilForNonExistentFile() {
        let importer = DiveLogImporterFactory.selectImporter(for: "/nonexistent/file.json")
        XCTAssertNil(importer, "不存在的 JSON 檔案應返回 nil（canHandle 檔案讀取失敗）")
    }

    // MARK: - 跨格式整合：各解析器 parse(from:) 回傳合理結果

    func testUDDFParserProducesDives() throws {
        let path = testFilePath("UDDF/test42.uddf")
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("../_JD2-family/dive-log-samples/UDDF/test42.uddf 不存在")
        }
        let parser = UDDFParser()
        let dives = try parser.parse(from: path)
        XCTAssertFalse(dives.isEmpty, "UDDF 解析應產生至少一筆日誌")
        for dive in dives {
            XCTAssertGreaterThan(dive.diveTimeSeconds, 0)
            XCTAssertGreaterThanOrEqual(dive.maxDepth, 0.0)
            XCTAssertEqual(dive.sourceFormat, "UDDF")
        }
    }

    func testCSVParserProducesDivesWithEmptyLocation() throws {
        let path = testFilePath("CSV/test41.csv")
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("../_JD2-family/dive-log-samples/CSV/test41.csv 不存在")
        }
        // SubsurfaceCSVParser 為 DiveLogImporter（透過工廠取得）
        guard let parser = DiveLogImporterFactory.selectImporter(for: path) else {
            XCTFail("找不到 CSV 解析器")
            return
        }
        let dives = try parser.parse(from: path)
        XCTAssertFalse(dives.isEmpty, "CSV 解析應產生至少一筆日誌")
        XCTAssertEqual(dives.first?.sourceFormat, "csv")
        // CSV 解析的 location 為空字串（Subsurface CSV 格式無 site 欄位）
        // validateDives 不應過濾這些日誌
        let coordinator = makeCoordinator()
        let validated = coordinator.validateDives(dives)
        XCTAssertEqual(validated.count, dives.count, "所有 CSV 日誌都應通過 validateDives（包含 location 為空的情況）")
    }

    func testSuuntoJSONParserProducesDivesWithEmptyLocation() throws {
        let path = testFilePath("Suunto/suunto_ocean_air.json")
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("../_JD2-family/dive-log-samples/Suunto/suunto_ocean_air.json 不存在")
        }
        // 2026-07-19 家族層 import 共用第二階段：SuuntoJSONParser 實作已搬遷至
        // DiveImportKit，本地薄包裝只透過 DiveLogImporter 協定的 parse(from:) 存取，
        // 不再提供 static parseJSONData 靜態輔助。
        guard let parser = DiveLogImporterFactory.selectImporter(for: path) else {
            XCTFail("找不到 Suunto JSON 解析器")
            return
        }
        let dives = try parser.parse(from: path)
        XCTAssertFalse(dives.isEmpty, "Suunto JSON 解析應產生至少一筆日誌")
        XCTAssertEqual(dives.first?.sourceFormat, "suunto-json")
        // Suunto JSON location 為空字串，validateDives 不應過濾
        let coordinator = makeCoordinator()
        let validated = coordinator.validateDives(dives)
        XCTAssertEqual(validated.count, dives.count, "所有 Suunto JSON 日誌都應通過 validateDives（包含 location 為空的情況）")
    }

    func testCrossFormatAllParsersPassValidation() throws {
        // 四種格式的解析結果都應能通過 validateDives
        let files: [(String, String)] = [
            ("UDDF/test42.uddf",                       "UDDF"),
            ("CSV/test41.csv",                          "csv"),
            ("Suunto/suunto_eon_core_nitrox.json",      "suunto-json"),
            ("Suunto/suunto_ocean_air.json",            "suunto-json"),
        ]

        let coordinator = makeCoordinator()

        for (relativePath, expectedFormat) in files {
            let path = testFilePath(relativePath)
            guard FileManager.default.fileExists(atPath: path) else {
                continue  // 測試環境中缺少該檔案則略過
            }
            guard let parser = DiveLogImporterFactory.selectImporter(for: path) else {
                XCTFail("找不到 \(relativePath) 的解析器")
                continue
            }
            let dives = try parser.parse(from: path)
            XCTAssertFalse(dives.isEmpty, "\(relativePath) 應解析出日誌")

            let validated = coordinator.validateDives(dives)
            XCTAssertEqual(validated.count, dives.count,
                "\(relativePath)（\(expectedFormat)）的所有日誌都應通過 validateDives")
        }
    }

    // MARK: - 效能基線測試（Week 8）

    /// 測試所有可用測試檔案的批量解析效能
    /// 目標：< 2 秒解析全部（9+ 個檔案）
    func testPerformance_BatchParse_AllFormats() throws {
        let allTestFiles: [String] = [
            testFilePath("UDDF/test42.uddf"),
            testFilePath("UDDF/test-apd-inspiration.uddf"),
            testFilePath("CSV/test41.csv"),
            testFilePath("Suunto/suunto_eon_core_nitrox.json"),
            testFilePath("Suunto/suunto_nautic_sidemount.json"),
            testFilePath("Suunto/suunto_ocean_air.json"),
            testFilePath("Suunto/suunto_eon_core_nitrox.xml"),
            testFilePath("Garmin/2018-08-11-09-56-30.fit"),
            testFilePath("Garmin/2018-08-11-14-11-36.fit"),
            testFilePath("Garmin/2018-08-13-13-48-26.fit"),
            testFilePath("Seabear/TestDiveSeabearHUDC.csv"),
        ].filter { FileManager.default.fileExists(atPath: $0) }

        XCTAssertGreaterThanOrEqual(allTestFiles.count, 5,
            "至少需要 5 個測試檔案才能進行有意義的效能測試")

        let start = Date()
        var totalDives = 0
        var parsedFiles = 0
        var failedFiles = 0

        for path in allTestFiles {
            guard let parser = DiveLogImporterFactory.selectImporter(for: path) else {
                failedFiles += 1
                continue
            }
            do {
                let dives = try parser.parse(from: path)
                totalDives += dives.count
                parsedFiles += 1
            } catch {
                failedFiles += 1
            }
        }

        let elapsed = Date().timeIntervalSince(start)

        print("[Performance] \(parsedFiles) files, \(totalDives) dives, \(String(format: "%.3f", elapsed))s")
        print("[Performance] failed: \(failedFiles) / \(allTestFiles.count)")

        // 目標：< 10s（保守基線，Garmin FIT 使用 C SDK 較慢）
        XCTAssertLessThan(elapsed, 10.0,
            "批量解析 \(allTestFiles.count) 個檔案應在 10 秒內完成，實際: \(String(format: "%.3f", elapsed))s")
        XCTAssertGreaterThan(totalDives, 0, "至少應解析出 1 筆潛水記錄")
        XCTAssertEqual(failedFiles, 0, "所有可用測試檔案都應能成功解析")
    }

    /// 測試單一格式的重複解析效能（Suunto JSON，純 Swift 解析，速度最快）
    func testPerformance_SuuntoJSON_Repeated() throws {
        let path = testFilePath("Suunto/suunto_eon_core_nitrox.json")
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("../_JD2-family/dive-log-samples/Suunto/suunto_eon_core_nitrox.json 不存在")
        }
        let parser = SuuntoJSONParser()
        let iterations = 50

        let start = Date()
        for _ in 0..<iterations {
            let dives = try parser.parse(from: path)
            XCTAssertEqual(dives.count, 1)
        }
        let elapsed = Date().timeIntervalSince(start)
        let perParse = elapsed / Double(iterations) * 1000  // ms

        print("[Performance] SuuntoJSON x\(iterations): \(String(format: "%.1f", perParse))ms/parse")

        // 每次解析 < 100ms
        XCTAssertLessThan(perParse, 100.0,
            "SuuntoJSON 單次解析應 < 100ms，實際: \(String(format: "%.1f", perParse))ms")
    }

    /// 驗證去重邏輯效能（validateDives + 確認 deduplicateDives 不被誤呼叫）
    func testPerformance_ValidateDives_1000Dives() {
        let coordinator = makeCoordinator()
        var dives: [DiveLog] = []
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

        for i in 0..<1000 {
            let dive = DiveLog(
                dateTime: baseDate.addingTimeInterval(Double(i) * 3600),
                location: "Site \(i % 10)",
                maxDepth: 15.0 + Double(i % 25),
                diveTimeSeconds: 1800 + (i % 1800),
                gasMixJSON: "\"air\"",
                waterTemperature: 25.0
            )
            dives.append(dive)
        }

        let start = Date()
        let validated = coordinator.validateDives(dives)
        let elapsed = Date().timeIntervalSince(start)

        print("[Performance] validateDives(1000): \(String(format: "%.3f", elapsed))s")

        XCTAssertEqual(validated.count, 1000, "1000 筆合法潛水應全部通過驗證")
        XCTAssertLessThan(elapsed, 1.0, "validateDives 1000 筆應在 1 秒內完成")
    }

    // MARK: - supportedFormats

    func testSupportedFormatsIsNotEmpty() {
        let formats = ImportCoordinator.supportedFormats()
        XCTAssertFalse(formats.isEmpty)
    }

    func testSupportedFormatsContainsSuunto() {
        let formats = ImportCoordinator.supportedFormats()
        XCTAssertTrue(formats.contains(.suunto), "supportedFormats 應包含 .suunto")
    }

    func testIsFormatSupportedForKnownFormat() {
        // rawValues are case-sensitive: "UDDF", "Suunto", "CSV"
        XCTAssertTrue(ImportCoordinator.isFormatSupported("UDDF"))
        XCTAssertTrue(ImportCoordinator.isFormatSupported("Suunto"))
        XCTAssertTrue(ImportCoordinator.isFormatSupported("CSV"))
    }

    func testIsFormatSupportedReturnsFalseForUnknown() {
        XCTAssertFalse(ImportCoordinator.isFormatSupported("unknown-format"))
        XCTAssertFalse(ImportCoordinator.isFormatSupported(""))
    }

    // MARK: - 稽核修復 #2：dedupe 同批次內部重複漏檢

    /// 稽核報告風險 #2：原本的 .filter 只對照資料庫既有記錄，同一批次（甚至單一檔案）
    /// 內部彼此重複的日誌會互相漏檢、全數通過。改用純邏輯版本 Self.dedupe 測試，
    /// 不碰資料庫。
    func testDedupeFiltersDuplicatesWithinSameBatch() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let dive1 = makeDive(depth: 20.0, location: "Reef A")
        dive1.dateTime = base
        let dive2 = makeDive(depth: 20.0, location: "Reef A")
        dive2.dateTime = base.addingTimeInterval(10)   // 同批次內幾乎同一筆（10s 內、同地點同深度）

        let result = ImportCoordinator.dedupe([dive1, dive2], against: [])

        XCTAssertEqual(result.count, 1,
            "同一批次內彼此重複的日誌應只保留一筆（修復前：existing 是靜態快照，兩筆都會通過）")
    }

    func testDedupeKeepsNonDuplicatesWithinSameBatch() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let dive1 = makeDive(depth: 20.0, location: "Reef A")
        dive1.dateTime = base
        let dive2 = makeDive(depth: 30.0, location: "Reef B")
        dive2.dateTime = base.addingTimeInterval(3600)   // 明顯不同的一次潛水

        let result = ImportCoordinator.dedupe([dive1, dive2], against: [])

        XCTAssertEqual(result.count, 2, "不重複的日誌都應保留")
    }

    func testDedupeFiltersAgainstExistingDatabaseRecords() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let existingDive = makeDive(depth: 20.0, location: "Reef A")
        existingDive.dateTime = base

        let incoming = makeDive(depth: 20.0, location: "Reef A")
        incoming.dateTime = base.addingTimeInterval(5)

        let result = ImportCoordinator.dedupe([incoming], against: [existingDive])

        XCTAssertEqual(result.count, 0, "與資料庫既有記錄重複的日誌應被過濾")
    }

    func testDedupeThreeIdenticalDivesInSameBatchKeepsOnlyOne() {
        // 更貼近真實場景：同一個匯入檔案內因來源軟體匯出瑕疵，含 3 筆完全相同的日誌
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let dives = (0..<3).map { i -> DiveLog in
            let d = makeDive(depth: 18.5, location: "Wreck Point")
            d.dateTime = base.addingTimeInterval(Double(i))  // 彼此相差 0~2 秒
            return d
        }

        let result = ImportCoordinator.dedupe(dives, against: [])

        XCTAssertEqual(result.count, 1, "3 筆幾乎相同的日誌應只保留第一筆")
    }
}
