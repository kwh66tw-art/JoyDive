// SuuntoSMLParserTests.swift — JD2-LogbookTests
// v1.1 格式擴充：Suunto SML（Moveslink）解析器測試

import XCTest
@testable import JoyDive_

final class SuuntoSMLParserTests: XCTestCase {

    private var smlDir: String {
        let here       = (#filePath as NSString).deletingLastPathComponent
        let moduleRoot = (here as NSString).deletingLastPathComponent
        let repoRoot   = (moduleRoot as NSString).deletingLastPathComponent
        return (repoRoot as NSString).appendingPathComponent("TestFiles/Suunto/SML")
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
}
