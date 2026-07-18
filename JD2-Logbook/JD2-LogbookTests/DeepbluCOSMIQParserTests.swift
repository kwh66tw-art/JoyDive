// DeepbluCOSMIQParserTests.swift — JD2-LogbookTests
// v1.1 格式擴充：Deepblu COSMIQ+ JSON 解析器測試
//
// ⚠️ 樣本為依公開推測欄位建構的假設格式（非真機資料），測試驗證的是「解析器
// 正確處理其自身假設的欄位定義」，非「與真實裝置匯出檔案位元相符」——與
// GarminConnectJSONParserTests 相同性質的既有慣例。

import XCTest
@testable import JoyDive_

final class DeepbluCOSMIQParserTests: XCTestCase {

    private var samplePath: String {
        let here       = (#filePath as NSString).deletingLastPathComponent
        let moduleRoot = (here as NSString).deletingLastPathComponent
        let repoRoot   = (moduleRoot as NSString).deletingLastPathComponent
        return (repoRoot as NSString).appendingPathComponent("../_JD2-family/dive-log-samples/Deepblu/deepblu_cosmiq.json")
    }

    private func skipIfMissing(_ path: String) throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: path),
                          "測試檔案不存在，略過：\((path as NSString).lastPathComponent)")
    }

    func testValidateContentRequiresAllThreeMarkers() {
        let parser = DeepbluCOSMIQParser()
        let full = """
        {"dive_time_seconds":100,"max_depth_meter":10,"profile_points":[]}
        """
        XCTAssertTrue(parser.validateContent(Data(full.utf8)))

        let partial = """
        {"dive_time_seconds":100,"max_depth_meter":10}
        """
        XCTAssertFalse(parser.validateContent(Data(partial.utf8)),
                       "缺 profile_points 標記不應誤判為 Deepblu 格式")
    }

    func testValidateContentRejectsGarminConnectJSON() {
        let parser = DeepbluCOSMIQParser()
        let garmin = """
        {"summaryDTO":{"duration":100,"maxDepth":10}}
        """
        XCTAssertFalse(parser.validateContent(Data(garmin.utf8)))
    }

    func testParseSampleFile() throws {
        try skipIfMissing(samplePath)
        let data = try Data(contentsOf: URL(fileURLWithPath: samplePath))
        let dives = try DeepbluCOSMIQParser.parseJSONData(data)
        XCTAssertEqual(dives.count, 1)
        let dive = dives[0]

        XCTAssertEqual(dive.diveTimeSeconds, 2700)
        XCTAssertEqual(dive.maxDepth, 22.4, accuracy: 0.001)
        XCTAssertEqual(dive.waterTemperature, 26.0, accuracy: 0.001)
        XCTAssertEqual(dive.sourceFormat, "deepblu-cosmiq")
        XCTAssertEqual(dive.profileSamples.count, 4)
        XCTAssertEqual(dive.profileSamples.last?.depthMeters ?? -1, 22.4, accuracy: 0.001)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.year, .month, .day], from: dive.dateTime)
        XCTAssertEqual(comps.year, 2023)
        XCTAssertEqual(comps.month, 10)
        XCTAssertEqual(comps.day, 21)
    }

    func testParseMissingRequiredFieldsThrows() {
        let json = """
        {"dive_time_seconds":100}
        """
        XCTAssertThrowsError(try DeepbluCOSMIQParser.parseJSONData(Data(json.utf8)))
    }

    func testParseArrayOfDives() throws {
        let json = """
        [
          {"dive_time_seconds":600,"max_depth_meter":10.0,"start_datetime":"2024-01-01T10:00:00Z","profile_points":[]},
          {"dive_time_seconds":900,"max_depth_meter":15.0,"start_datetime":"2024-01-02T10:00:00Z","profile_points":[]}
        ]
        """
        let dives = try DeepbluCOSMIQParser.parseJSONData(Data(json.utf8))
        XCTAssertEqual(dives.count, 2)
    }
}
