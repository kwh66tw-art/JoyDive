// DiveImportKitAdapterTests.swift — JD2-LogbookTests
// F6 階段一：驗證「adapter 包裝解析器 → DiveLog」全流程接線。
//
// 解析邏輯本身已在 DiveImportKit 套件內完整測試（swift test 全綠），
// 此處只證明 App 端 adapter 對映無誤：用真實樣本 test42.uddf 走
// 本地 UDDFParser（Kit 薄包裝）→ ParsedDiveLog → DiveLog，
// 斷言關鍵欄位與搬遷前 UDDFParserTests 的既有期望值一致。
//
// test42.uddf 既有期望值（搬遷前 UDDFParserTests 檔頭記載）：
//   - 日期：2014-04-02T10:00:00Z（UTC）
//   - 地點：Lake Coleridge，GPS: -43.342295 / 171.545936
//   - 深度：38.99m，時間：4674s
//   - 氣體：TMx 16/45 → {"trimix":{"fO2":0.16,"fHe":0.45}}

import XCTest
import Foundation
@testable import JoyDive_

final class DiveImportKitAdapterTests: XCTestCase {

    /// 家族共用樣本目錄：../_JD2-family/dive-log-samples/UDDF/
    private var test42Path: String {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // JD2-LogbookTests/
            .deletingLastPathComponent()   // JD2-Logbook/
            .deletingLastPathComponent()   // JD2-Logbook/ (project root)
            .appendingPathComponent("../_JD2-family/dive-log-samples/UDDF/test42.uddf")
            .path
    }

    private func skipIfMissing(_ path: String) throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: path),
                          "測試檔案不存在，略過：\((path as NSString).lastPathComponent)")
    }

    // MARK: - 工廠選擇（factory → adapter 包裝版）

    func testFactorySelectsAdapterBackedUDDFParser() throws {
        try skipIfMissing(test42Path)
        let importer = DiveLogImporterFactory.selectImporter(for: test42Path)
        XCTAssertNotNil(importer)
        XCTAssertTrue(importer is UDDFParser)
        XCTAssertEqual(importer?.format, .uddf)
    }

    // MARK: - 全流程：Kit 解析 → adapter → DiveLog

    func testUDDFAdapterEndToEnd() throws {
        try skipIfMissing(test42Path)

        let dives = try UDDFParser().parse(from: test42Path)
        XCTAssertEqual(dives.count, 1)

        let dive = try XCTUnwrap(dives.first)

        // 日期時間：2014-04-02T10:00:00Z
        let fmt = ISO8601DateFormatter()
        XCTAssertEqual(dive.dateTime, fmt.date(from: "2014-04-02T10:00:00Z"))

        // 潛水參數
        XCTAssertEqual(dive.maxDepth, 38.99, accuracy: 0.01)
        XCTAssertEqual(dive.diveTimeSeconds, 4674)

        // 地點與 GPS
        XCTAssertEqual(dive.location, "Lake Coleridge")
        XCTAssertEqual(try XCTUnwrap(dive.latitude),  -43.342295, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(dive.longitude), 171.545936, accuracy: 0.000001)

        // 氣體：TMx 16/45
        XCTAssertTrue(dive.gasMixJSON.contains("trimix"),
                      "gasMixJSON 應為 trimix：\(dive.gasMixJSON)")

        // 剖面樣本：JSON 非空且可解碼（證明陣列 → JSON 字串轉換無誤）
        XCTAssertNotEqual(dive.profileSamplesJSON, "[]")
        let samples = dive.profileSamples
        XCTAssertFalse(samples.isEmpty, "剖面樣本應非空")
        XCTAssertEqual(samples.map(\.depthMeters).max() ?? 0, 38.99, accuracy: 0.5)

        // 來源格式
        XCTAssertEqual(dive.sourceFormat, "UDDF")
    }
}
