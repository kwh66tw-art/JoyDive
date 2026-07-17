// ShearwaterXMLParserTests.swift — JD2-LogbookTests
// v1.1 格式擴充：Shearwater Cloud/Desktop XML 解析器測試

import XCTest
@testable import JoyDive_

final class ShearwaterXMLParserTests: XCTestCase {

    private var shearwaterDir: String {
        let here       = (#filePath as NSString).deletingLastPathComponent
        let moduleRoot = (here as NSString).deletingLastPathComponent
        let repoRoot   = (moduleRoot as NSString).deletingLastPathComponent
        return (repoRoot as NSString).appendingPathComponent("TestFiles/SHEARWATER")
    }

    private func skipIfMissing(_ path: String) throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: path),
                          "測試檔案不存在，略過：\((path as NSString).lastPathComponent)")
    }

    // MARK: - 格式偵測（含 D4i 誤攔截防錯，原始 bug 根因）

    func testValidateContentWithLogbookAndComputerModel() {
        let parser = SHEARWATERParser()
        let data = "<logbook><dive><computer_model>Perdix 2</computer_model></dive></logbook>".data(using: .utf8)!
        XCTAssertTrue(parser.validateContent(data))
    }

    func testValidateContentRejectsSuuntoDM5XML() {
        // 原始 bug：預設 canHandle 只看副檔名，會誤攔截 D4i 等其他 XML 格式
        let parser = SHEARWATERParser()
        let data = "<Dive xmlns=\"http://schemas.datacontract.org/2004/07/Suunto.Diving.Dal\">".data(using: .utf8)!
        XCTAssertFalse(parser.validateContent(data), "不應誤判 Suunto DM5 XML 為 Shearwater 格式")
    }

    func testValidateContentRejectsSubsurfaceXML() {
        let parser = SHEARWATERParser()
        let data = "<divelog program='subsurface' version='3'>".data(using: .utf8)!
        XCTAssertFalse(parser.validateContent(data))
    }

    // MARK: - 真實樣本解析

    func testParseSampleDive() throws {
        let path = (shearwaterDir as NSString).appendingPathComponent("shearwater_dive.xml")
        try skipIfMissing(path)
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let dives = try SHEARWATERParser.parseXMLData(data)
        XCTAssertEqual(dives.count, 1)
        let dive = dives[0]

        XCTAssertEqual(dive.maxDepth, 30.5, accuracy: 0.001)
        XCTAssertEqual(dive.diveTimeSeconds, 3600)
        XCTAssertEqual(dive.avgDepth, 15.2, accuracy: 0.001)
        XCTAssertEqual(dive.waterTemperature, 25.0, accuracy: 0.001)
        XCTAssertEqual(dive.sourceFormat, "shearwater")
        XCTAssertEqual(dive.gasMixJSON, "\"air\"")   // Oxygen=21 → Air
        XCTAssertEqual(dive.profileSamples.count, 3)
    }

    func testGasPercentHeuristicForFractionValues() {
        // 部分匯出版本用 0.21 而非 21，需正確判定百分比 vs 分率
        let xml = """
        <logbook><dive>
          <start_time>2024-01-01T10:00:00</start_time>
          <duration>1800</duration>
          <max_depth>18.0</max_depth>
          <water_temp>24.0</water_temp>
          <computer_model>Teric</computer_model>
          <gases><gas><oxygen>0.32</oxygen><helium>0</helium></gas></gases>
        </dive></logbook>
        """
        guard let dives = try? SHEARWATERParser.parseXMLData(xml.data(using: .utf8)!) else {
            XCTFail("應可解析")
            return
        }
        guard let gasData = dives.first?.gasMixJSON.data(using: .utf8),
              let gas = try? JSONDecoder().decode(GasMix.self, from: gasData) else {
            XCTFail("gasMixJSON 應可解碼")
            return
        }
        if case .nitrox(let fO2) = gas {
            XCTAssertEqual(fO2, 0.32, accuracy: 0.001)
        } else {
            XCTFail("應為 Nitrox 32%，實際: \(gas)")
        }
    }

    func testParseEmptyDataThrows() {
        XCTAssertThrowsError(try SHEARWATERParser.parseXMLData(Data()))
    }
}
