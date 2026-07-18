// DivingLogSQLiteParserTests.swift — JD2-LogbookTests
// v1.1 格式擴充：Diving Log 6.0 SQLite 解析器測試（真實樣本資料庫）

import XCTest
import DiveKit
@testable import JoyDive_

final class DivingLogSQLiteParserTests: XCTestCase {

    private var dbPath: String {
        let here       = (#filePath as NSString).deletingLastPathComponent
        let moduleRoot = (here as NSString).deletingLastPathComponent
        let repoRoot   = (moduleRoot as NSString).deletingLastPathComponent
        return (repoRoot as NSString).appendingPathComponent("../_JD2-family/dive-log-samples/DivingLog/TestDivingLog4.1.1.sql")
    }

    private func skipIfMissing(_ path: String) throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: path),
                          "測試檔案不存在，略過：\((path as NSString).lastPathComponent)")
    }

    // MARK: - 格式偵測

    func testValidateContentWithSQLiteMagicAndLogbookTable() throws {
        try skipIfMissing(dbPath)
        let parser = DivingLogSQLiteParser()
        let data = try Data(contentsOf: URL(fileURLWithPath: dbPath))
        XCTAssertTrue(parser.validateContent(data))
    }

    func testValidateContentRejectsNonSQLite() {
        let parser = DivingLogSQLiteParser()
        XCTAssertFalse(parser.validateContent(Data("not a sqlite db".utf8)))
    }

    func testValidateContentRejectsOtherSQLiteSchemas() {
        // SQLite header 對，但沒有 Logbook 資料表 → 不應誤判為 Diving Log
        let parser = DivingLogSQLiteParser()
        var bytes = Array("SQLite format 3\0".utf8)
        bytes.append(contentsOf: Array("CREATE TABLE SomethingElse (id INTEGER)".utf8))
        XCTAssertFalse(parser.validateContent(Data(bytes)))
    }

    // MARK: - 真實樣本解析

    func testParseRealSample() throws {
        try skipIfMissing(dbPath)
        let importer = DivingLogSQLiteParser()
        let dives = try importer.parse(from: dbPath)
        XCTAssertEqual(dives.count, 1)
        let dive = dives[0]

        XCTAssertEqual(dive.maxDepth, 81.5, accuracy: 0.01)
        XCTAssertEqual(dive.diveTimeSeconds, 100 * 60)   // Divetime=100.0 分鐘
        XCTAssertEqual(dive.avgDepth, 22.4599990844727, accuracy: 0.01)
        XCTAssertEqual(dive.waterTemperature, 5.09999990463257, accuracy: 0.01)
        XCTAssertEqual(dive.sourceFormat, "divinglog")
        XCTAssertTrue(dive.location.contains("Hälvälä") || dive.location.contains("Suomi"))

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: dive.dateTime)
        XCTAssertEqual(comps.year, 2015)
        XCTAssertEqual(comps.month, 5)
        XCTAssertEqual(comps.day, 23)
        XCTAssertEqual(comps.hour, 13)
        XCTAssertEqual(comps.minute, 23)

        // O2=50.0 He=6.0 → Trimix
        guard let gasData = dive.gasMixJSON.data(using: .utf8),
              let gas = try? JSONDecoder().decode(GasMix.self, from: gasData) else {
            XCTFail("gasMixJSON 應可解碼")
            return
        }
        if case .trimix(let fO2, let fHe) = gas {
            XCTAssertEqual(fO2, 0.50, accuracy: 0.01)
            XCTAssertEqual(fHe, 0.06, accuracy: 0.01)
        } else {
            XCTFail("應為 Trimix 50/6，實際: \(gas)")
        }
    }

    func testFactorySelectsForRealSample() throws {
        try skipIfMissing(dbPath)
        let importer = DiveLogImporterFactory.selectImporter(for: dbPath)
        XCTAssertEqual(importer?.format, .divingLog)
    }

    // MARK: - 錯誤處理

    func testParseNonexistentFileThrows() {
        XCTAssertThrowsError(try DivingLogSQLiteParser.parseDatabase(at: "/nonexistent/path.sql"))
    }
}
