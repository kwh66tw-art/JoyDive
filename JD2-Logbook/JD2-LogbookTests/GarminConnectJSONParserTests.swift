// GarminConnectJSONParserTests.swift — JD2-LogbookTests
// v1.1 #12/#13：GarminConnectJSONParser 單元測試（合成 JSON，無需真實匯出樣本）
//
// 測試覆蓋：
//   - 格式偵測（canHandle 副檔名 + validateContent 內容特徵）
//   - 不誤吞 Suunto JSON（DeviceLog 特徵互斥）
//   - 單一 activity 物件 與 activity 陣列 兩種根結構
//   - summaryDTO 各欄位映射（duration / maxDepth / averageDepth / temperature / GPS）
//   - 日期格式（ISO 8601 含毫秒/Z、無時區 Connect 格式）
//   - 深度剖面（samples）與 sourceFormat = "garmin-json"
//   - 錯誤處理（空資料、缺少必填欄位）

import XCTest
@testable import JoyDive_

final class GarminConnectJSONParserTests: XCTestCase {

    // MARK: - 格式偵測

    func testCanHandleRequiresJSONExtension() {
        let parser = GarminConnectJSONParser()
        XCTAssertFalse(parser.canHandle(filePath: "/path/to/file.fit"))
        XCTAssertFalse(parser.canHandle(filePath: "/path/to/file.xml"))
    }

    func testValidateContentWithSummaryDTO() {
        let parser = GarminConnectJSONParser()
        let data = "{\"summaryDTO\":{\"duration\":100}}".data(using: .utf8)!
        XCTAssertTrue(parser.validateContent(data), "含 summaryDTO 應通過驗證")
    }

    func testValidateContentWithActivityId() {
        let parser = GarminConnectJSONParser()
        let data = "{\"activityId\":12345}".data(using: .utf8)!
        XCTAssertTrue(parser.validateContent(data), "含 activityId 應通過驗證")
    }

    func testValidateContentExcludesSuuntoDeviceLog() {
        let parser = GarminConnectJSONParser()
        let data = "{\"DeviceLog\":{\"summaryDTO\":{}}}".data(using: .utf8)!
        XCTAssertFalse(parser.validateContent(data), "含 DeviceLog 特徵應被排除，避免誤吞 Suunto JSON")
    }

    func testValidateContentRejectsUnrelatedJSON() {
        let parser = GarminConnectJSONParser()
        let data = "{\"foo\":\"bar\"}".data(using: .utf8)!
        XCTAssertFalse(parser.validateContent(data))
    }

    func testValidateContentEmptyData() {
        let parser = GarminConnectJSONParser()
        XCTAssertFalse(parser.validateContent(Data()))
    }

    // MARK: - 單一 activity 物件解析

    func testParseSingleActivityWithFullFields() throws {
        let json = """
        {
          "activityId": 123,
          "activityName": "Blue Corner",
          "description": "Great viz",
          "summaryDTO": {
            "startTimeGMT": "2024-06-01T08:30:00.0",
            "duration": 2400,
            "maxDepth": 28.5,
            "averageDepth": 15.2,
            "minTemperature": 26.0,
            "startLatitude": 4.1234,
            "startLongitude": 118.6789
          },
          "samples": [
            {"t": 0, "d": 0},
            {"t": 60, "d": 10},
            {"t": 1200, "d": 28.5}
          ]
        }
        """.data(using: .utf8)!

        let dives = try GarminConnectJSONParser.parseJSONData(json)
        XCTAssertEqual(dives.count, 1)
        let dive = dives[0]
        XCTAssertEqual(dive.location, "Blue Corner")
        XCTAssertEqual(dive.maxDepth, 28.5, accuracy: 0.001)
        XCTAssertEqual(dive.diveTimeSeconds, 2400)
        XCTAssertEqual(dive.avgDepth, 15.2, accuracy: 0.001)
        XCTAssertEqual(dive.waterTemperature, 26.0, accuracy: 0.001)
        XCTAssertEqual(dive.notes, "Great viz")
        XCTAssertEqual(dive.sourceFormat, "garmin-json")
        XCTAssertEqual(dive.latitude ?? 0, 4.1234, accuracy: 0.0001)
        XCTAssertEqual(dive.longitude ?? 0, 118.6789, accuracy: 0.0001)
        XCTAssertEqual(dive.profileSamples.count, 3)
        // Connect 匯出無氣體資訊 → 一律 Air
        XCTAssertEqual(dive.gasMixJSON, "\"air\"")
    }

    func testParseActivityArrayRoot() throws {
        let json = """
        [
          { "activityId": 1, "summaryDTO": { "startTimeGMT": "2024-01-01T00:00:00Z", "duration": 1800, "maxDepth": 10.0 } },
          { "activityId": 2, "summaryDTO": { "startTimeGMT": "2024-01-02T00:00:00Z", "duration": 3600, "maxDepth": 20.0 } }
        ]
        """.data(using: .utf8)!

        let dives = try GarminConnectJSONParser.parseJSONData(json)
        XCTAssertEqual(dives.count, 2)
        XCTAssertEqual(dives[0].maxDepth, 10.0, accuracy: 0.001)
        XCTAssertEqual(dives[1].maxDepth, 20.0, accuracy: 0.001)
    }

    func testMissingOptionalFieldsDefaultGracefully() throws {
        // 無 averageDepth / temperature / GPS / samples / description → 應使用預設值而非失敗
        let json = """
        {
          "activityId": 9,
          "summaryDTO": { "startTimeGMT": "2024-03-01T10:00:00.0", "duration": 1500, "maxDepth": 12.0 }
        }
        """.data(using: .utf8)!

        let dives = try GarminConnectJSONParser.parseJSONData(json)
        XCTAssertEqual(dives.count, 1)
        let dive = dives[0]
        XCTAssertEqual(dive.avgDepth, 0, "缺少 averageDepth 應維持預設 0")
        XCTAssertEqual(dive.waterTemperature, 15.0, accuracy: 0.001, "缺少溫度應預設 15.0（同 FIT 路線）")
        XCTAssertNil(dive.latitude)
        XCTAssertTrue(dive.profileSamples.isEmpty)
        XCTAssertEqual(dive.location, "", "缺少 activityName 應為空字串")
    }

    // MARK: - 日期格式

    func testParseGarminDateNoTimezoneTreatedAsGMT() {
        let date = GarminConnectJSONParser.parseGarminDate("2023-08-17T08:51:59.0")
        XCTAssertNotNil(date)
    }

    func testParseGarminDateISO8601WithZ() {
        let date = GarminConnectJSONParser.parseGarminDate("2023-08-17T08:51:59Z")
        XCTAssertNotNil(date)
    }

    func testParseGarminDateInvalidReturnsNil() {
        XCTAssertNil(GarminConnectJSONParser.parseGarminDate("not-a-date"))
    }

    // MARK: - 錯誤處理

    func testParseEmptyDataThrows() {
        XCTAssertThrowsError(try GarminConnectJSONParser.parseJSONData(Data()))
    }

    func testParseMissingSummaryFieldsSkipsActivity() {
        // 缺少 duration/maxDepth 的 activity 應被略過；若全部無效則丟錯
        let json = "{\"activityId\": 1, \"summaryDTO\": {}}".data(using: .utf8)!
        XCTAssertThrowsError(try GarminConnectJSONParser.parseJSONData(json))
    }

    func testParseNonActivityStructureThrows() {
        let json = "[1, 2, 3]".data(using: .utf8)!
        XCTAssertThrowsError(try GarminConnectJSONParser.parseJSONData(json))
    }

    // MARK: - 工廠整合

    func testFactoryFormatIncludesJSONExtension() {
        XCTAssertTrue(DiveLogFormat.garmin.supportedExtensions.contains("json"))
        XCTAssertTrue(DiveLogFormat.garmin.supportedExtensions.contains("fit"))
    }
}
