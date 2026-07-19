// SuuntoSMLParserTests.swift — JD2-LogbookTests
// v1.1 格式擴充：Suunto SML（Moveslink）解析器測試

import XCTest
@testable import JoyDive_

final class SuuntoSMLParserTests: XCTestCase {

    private var smlDir: String {
        let here       = (#filePath as NSString).deletingLastPathComponent
        let moduleRoot = (here as NSString).deletingLastPathComponent
        let repoRoot   = (moduleRoot as NSString).deletingLastPathComponent
        return (repoRoot as NSString).appendingPathComponent("../_JD2-family/dive-log-samples/Suunto/SML")
    }

    private func skipIfMissing(_ path: String) throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: path),
                          "測試檔案不存在，略過：\((path as NSString).lastPathComponent)")
    }

    // MARK: - 格式偵測

    func testValidateContentWithDeviceLogAndSuunto() {
        let parser = SuuntoSMLParser()
        let data = "<header><DeviceLog><Header><Device><Name>Suunto Ambit2</Name></Device></Header></DeviceLog></header>".data(using: .utf8)!
        XCTAssertTrue(parser.validateContent(data))
    }

    func testValidateContentRejectsWithoutDeviceLog() {
        let parser = SuuntoSMLParser()
        let data = "<somethingelse>Suunto</somethingelse>".data(using: .utf8)!
        XCTAssertFalse(parser.validateContent(data))
    }

    // MARK: - 真實樣本解析

    func testParseSampleLog() throws {
        let path = (smlDir as NSString).appendingPathComponent("sample_moveslink_log.sml")
        try skipIfMissing(path)
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let dives = try SuuntoSMLParser.parseXMLData(data)
        XCTAssertEqual(dives.count, 1)
        let dive = dives[0]

        XCTAssertEqual(dive.diveTimeSeconds, 3420)
        XCTAssertEqual(dive.sourceFormat, "suunto-sml")
        // MaxDepth 從樣本推算：10.5（三筆樣本中的最大值）
        XCTAssertEqual(dive.maxDepth, 10.5, accuracy: 0.001)
        XCTAssertEqual(dive.profileSamples.count, 3)

        // Kelvin → Celsius：298.15K = 25.0°C（第一筆樣本水溫）
        XCTAssertEqual(dive.profileSamples.first?.waterTemp ?? 0, 25.0, accuracy: 0.01)
        // 最低水溫（295.15K = 22.0°C）應成為 dive.waterTemperature
        XCTAssertEqual(dive.waterTemperature, 22.0, accuracy: 0.01)
    }

    func testKelvinConversionPrecise() {
        // 0°C = 273.15K
        let xml = """
        <header><DeviceLog><Header><Duration>60</Duration><DateTime>2024-01-01T00:00:00Z</DateTime></Header>
        <Samples>
          <Sample><Time>0</Time><Depth>1.0</Depth><Temperature>273.15</Temperature></Sample>
          <Sample><Time>10</Time><Depth>2.0</Depth><Temperature>273.15</Temperature></Sample>
        </Samples></DeviceLog></header>
        """
        guard let dives = try? SuuntoSMLParser.parseXMLData(xml.data(using: .utf8)!) else {
            XCTFail("應可解析")
            return
        }
        XCTAssertEqual(dives.first?.waterTemperature ?? -99, 0.0, accuracy: 0.01)
    }

    func testParseEmptyDataThrows() {
        XCTAssertThrowsError(try SuuntoSMLParser.parseXMLData(Data()))
    }

    func testParseNoSamplesThrows() {
        let xml = "<header><DeviceLog><Header><Duration>60</Duration><DateTime>2024-01-01T00:00:00Z</DateTime></Header><Samples></Samples></DeviceLog></header>"
        XCTAssertThrowsError(try SuuntoSMLParser.parseXMLData(xml.data(using: .utf8)!))
    }

    // MARK: - 真實 Moveslink 裝置匯出（2026-07-19 使用者提供，非模擬資料）
    //
    // 兩檔皆來自同一支錶（序號 99723006）連續兩次潛水。DateTime **不含時區
    // designator**（如 "2021-09-01T15:14:26"），驗證這兩檔時發現
    // ISO8601DateFormatter 對此一律回傳 nil，導致整筆解析失敗——已在
    // SuuntoSMLParser.parseISO8601 加無時區 fallback 修復（與
    // ShearwaterXMLParser／UDDFParser 既有慣例一致）。

    func testParseRealDeviceExport_2021_09_01() throws {
        let path = (smlDir as NSString)
            .appendingPathComponent("99723006-2021-09-01T15_14_26-0.sml")
        try skipIfMissing(path)
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let dives = try SuuntoSMLParser.parseXMLData(data)
        XCTAssertEqual(dives.count, 1)
        let dive = dives[0]

        // Header <Duration>2812</Duration>
        XCTAssertEqual(dive.diveTimeSeconds, 2812)
        XCTAssertEqual(dive.sourceFormat, "suunto-sml")
        // maxDepth 從樣本點推算（非 Header 的 <Depth><Max>14.11</Max>，
        // 兩者些微不同是預期行為，見 SuuntoSMLParser 檔頭註解）
        XCTAssertEqual(dive.maxDepth, 14.06, accuracy: 0.01)
        XCTAssertEqual(dive.profileSamples.count, 141)
        // 樣本水溫最低 302.15K = 29.0°C
        XCTAssertEqual(dive.waterTemperature, 29.0, accuracy: 0.01)
    }

    func testParseRealDeviceExport_2021_09_04() throws {
        let path = (smlDir as NSString)
            .appendingPathComponent("99723006-2021-09-04T10_45_17-0.sml")
        try skipIfMissing(path)
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let dives = try SuuntoSMLParser.parseXMLData(data)
        XCTAssertEqual(dives.count, 1)
        let dive = dives[0]

        XCTAssertEqual(dive.diveTimeSeconds, 2873)
        XCTAssertEqual(dive.sourceFormat, "suunto-sml")
        XCTAssertEqual(dive.maxDepth, 11.69, accuracy: 0.01)
        XCTAssertEqual(dive.profileSamples.count, 156)
        XCTAssertEqual(dive.waterTemperature, 28.0, accuracy: 0.01)
    }

    func testParseNoTimezoneDateTimeFallback() throws {
        // 迴歸測試：真機常見的無時區 DateTime 格式必須能解析成功
        let xml = """
        <header><DeviceLog><Header><Duration>60</Duration><DateTime>2021-09-01T15:14:26</DateTime></Header>
        <Samples>
          <Sample><Time>0</Time><Depth>1.0</Depth><Temperature>300.0</Temperature></Sample>
          <Sample><Time>10</Time><Depth>2.0</Depth><Temperature>300.0</Temperature></Sample>
        </Samples></DeviceLog></header>
        """
        let dives = try SuuntoSMLParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(dives.count, 1)
    }
}
