// DiveExporterEdgeCaseTests.swift — JD2-LogbookTests/
// Week 12 整合測試：DiveExporter 邊緣案例
//
// 補充 DiveExporterTests.swift 未涵蓋的場景：
//   - 空陣列導出
//   - Trimix 氣體顯示名稱
//   - XML 特殊字元 escape（& < > " '）
//   - Freshwater / Altitude 環境寫入 CSV
//   - 檔案命名格式
//   - cleanupTempFiles 清除舊檔

import XCTest
import SwiftData
@testable import JD2_Logbook

final class DiveExporterEdgeCaseTests: XCTestCase {

    // MARK: - Helpers

    private func makeDive(
        location: String = "Test Site",
        depth: Double = 20.0,
        durationSeconds: Int = 3600,
        gasMixJSON: String = "\"air\"",
        temperature: Double = 26.0,
        buddy: String? = nil,
        notes: String = "",
        environment: String = "seawater"
    ) -> DiveLog {
        let dive = DiveLog(
            dateTime: Date(timeIntervalSince1970: 1_716_200_000),
            location: location,
            maxDepth: depth,
            diveTimeSeconds: durationSeconds,
            gasMixJSON: gasMixJSON,
            waterTemperature: temperature
        )
        dive.buddy = buddy
        dive.notes = notes
        dive.environmentType = environment
        return dive
    }

    // MARK: - 空陣列

    func testCSVExportEmptyArray() {
        let data = DiveExporter.export([DiveLog](), as: .csv)
        let csv  = String(data: data, encoding: .utf8) ?? ""
        // 只有 header，沒有資料列
        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 1, "空陣列應只輸出 header 一行")
        XCTAssertTrue(lines[0].hasPrefix("Date,Time,Location"))
    }

    func testUDDFExportEmptyArray() {
        let data = DiveExporter.export([DiveLog](), as: .uddf)
        let xml  = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(xml.contains("<uddf"), "空陣列 UDDF 仍應有根元素")
        XCTAssertTrue(xml.contains("version=\"3.2.2\""))
        XCTAssertFalse(xml.contains("<dive id="), "空陣列不應有任何 <dive> 元素")
    }

    // MARK: - Trimix 氣體

    func testCSVExportTrimixGasName() {
        let trimixJSON = "{\"trimix\":{\"fO2\":0.21,\"fHe\":0.35}}"
        let dive = makeDive(gasMixJSON: trimixJSON)
        let csv = String(data: DiveExporter.export([dive], as: .csv), encoding: .utf8) ?? ""
        XCTAssertTrue(csv.contains("Tx21/35"), "Trimix 應顯示為 Tx21/35")
    }

    func testUDDFExportTrimixPresent() {
        // UDDF 不特別處理氣體欄位（目前僅輸出 <samples/>），不應 crash
        let trimixJSON = "{\"trimix\":{\"fO2\":0.21,\"fHe\":0.35}}"
        let dive = makeDive(gasMixJSON: trimixJSON)
        let xml = String(data: DiveExporter.export([dive], as: .uddf), encoding: .utf8) ?? ""
        XCTAssertTrue(xml.contains("<dive id=\"dive1\">"))
    }

    // MARK: - XML Escape

    func testUDDFXMLEscapeAmpersand() {
        let dive = makeDive(location: "Blue & Green Wall")
        let xml = String(data: DiveExporter.export([dive], as: .uddf), encoding: .utf8) ?? ""
        XCTAssertTrue(xml.contains("Blue &amp; Green Wall"),
                      "& 必須轉義為 &amp;")
        XCTAssertFalse(xml.contains("Blue & Green"),
                       "原始 & 不應出現在 XML 中")
    }

    func testUDDFXMLEscapeLtGt() {
        let dive = makeDive(location: "<Kenting>")
        let xml = String(data: DiveExporter.export([dive], as: .uddf), encoding: .utf8) ?? ""
        XCTAssertTrue(xml.contains("&lt;Kenting&gt;"))
    }

    func testUDDFXMLEscapeQuotes() {
        let dive = makeDive(notes: "Saw a \"huge\" turtle")
        let xml = String(data: DiveExporter.export([dive], as: .uddf), encoding: .utf8) ?? ""
        XCTAssertTrue(xml.contains("&quot;huge&quot;"))
    }

    func testUDDFEmptyLocationFallsBackToUnknown() {
        let dive = makeDive(location: "")
        let xml = String(data: DiveExporter.export([dive], as: .uddf), encoding: .utf8) ?? ""
        XCTAssertTrue(xml.contains("<name>Unknown</name>"),
                      "空地點應 fallback 為 Unknown")
    }

    // MARK: - Environment 欄位（CSV）

    func testCSVExportFreshwaterEnvironment() {
        let dive = makeDive(environment: "freshwater")
        let csv = String(data: DiveExporter.export([dive], as: .csv), encoding: .utf8) ?? ""
        XCTAssertTrue(csv.contains("freshwater"))
    }

    func testCSVExportAltitudeEnvironment() {
        let dive = makeDive(environment: "altitude")
        let csv = String(data: DiveExporter.export([dive], as: .csv), encoding: .utf8) ?? ""
        XCTAssertTrue(csv.contains("altitude"))
    }

    // MARK: - GPS nil → 空欄位（CSV Null Island 保護）

    func testCSVNullIslandProtection_NoGPS() {
        let dive = makeDive()
        XCTAssertNil(dive.latitude)
        XCTAssertNil(dive.longitude)
        let csv = String(data: DiveExporter.export([dive], as: .csv), encoding: .utf8) ?? ""
        // 最後兩個欄位（Latitude, Longitude）應為空，不應出現 "0.000000"
        XCTAssertFalse(csv.contains("0.000000"),
                       "無 GPS 時不應輸出 0,0（Null Island）")
    }

    // MARK: - UDDF 溫度 Kelvin 精度

    func testUDDFKelvinConversion_0Celsius() {
        let dive = makeDive(temperature: 0.0)
        let xml = String(data: DiveExporter.export([dive], as: .uddf), encoding: .utf8) ?? ""
        // 0°C = 273.15 K → "273.15"
        XCTAssertTrue(xml.contains("<temperaturemin>273.15</temperaturemin>"))
    }

    func testUDDFKelvinConversion_NegativeTemp() {
        // 冰下潛水 -2°C → 271.15 K
        let dive = makeDive(temperature: -2.0)
        let xml = String(data: DiveExporter.export([dive], as: .uddf), encoding: .utf8) ?? ""
        XCTAssertTrue(xml.contains("<temperaturemin>271.15</temperaturemin>"))
    }

    // MARK: - 檔案命名格式

    func testFileNameContainsDiveCount() {
        let name = DiveExporter.fileName(for: .uddf, diveCount: 5)
        XCTAssertTrue(name.contains("5dives"), "檔名應包含潛水次數")
    }

    func testFileNameExtension_UDDF() {
        let name = DiveExporter.fileName(for: .uddf, diveCount: 1)
        XCTAssertTrue(name.hasSuffix(".uddf"))
    }

    func testFileNameExtension_CSV() {
        let name = DiveExporter.fileName(for: .csv, diveCount: 10)
        XCTAssertTrue(name.hasSuffix(".csv"))
    }

    func testFileNamePrefix() {
        let name = DiveExporter.fileName(for: .csv, diveCount: 3)
        XCTAssertTrue(name.hasPrefix("JD2-Logbook-"))
    }

    // MARK: - cleanupTempFiles

    func testCleanupRemovesJD2TempFiles() throws {
        // 在 temp 目錄建立假的 JD2-Logbook- 檔案
        let tmp = FileManager.default.temporaryDirectory
        let dummy = tmp.appendingPathComponent("JD2-Logbook-test-cleanup.uddf")
        try Data("dummy".utf8).write(to: dummy)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dummy.path))

        DiveExporter.cleanupTempFiles()

        XCTAssertFalse(FileManager.default.fileExists(atPath: dummy.path),
                       "cleanupTempFiles 應移除 JD2-Logbook-* 檔案")
    }

    func testCleanupDoesNotRemoveOtherTempFiles() throws {
        // 其他 temp 檔案不應被刪除
        let tmp = FileManager.default.temporaryDirectory
        let other = tmp.appendingPathComponent("unrelated-temp-file.txt")
        try Data("keep".utf8).write(to: other)
        defer { try? FileManager.default.removeItem(at: other) }

        DiveExporter.cleanupTempFiles()

        XCTAssertTrue(FileManager.default.fileExists(atPath: other.path),
                      "非 JD2-Logbook- 開頭的檔案不應被清除")
    }

    // MARK: - Multiple Dives

    func testCSVExportMultipleDivesRowCount() {
        let dives = (1...5).map { i in
            makeDive(location: "Site \(i)", depth: Double(i * 5))
        }
        let csv = String(data: DiveExporter.export(dives, as: .csv), encoding: .utf8) ?? ""
        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        // 1 header + 5 data rows
        XCTAssertEqual(lines.count, 6)
    }

    func testUDDFExportMultipleDiveIDs() {
        let dives = (1...3).map { _ in makeDive() }
        let xml = String(data: DiveExporter.export(dives, as: .uddf), encoding: .utf8) ?? ""
        XCTAssertTrue(xml.contains("<dive id=\"dive1\">"))
        XCTAssertTrue(xml.contains("<dive id=\"dive2\">"))
        XCTAssertTrue(xml.contains("<dive id=\"dive3\">"))
    }
}
