// SuuntoDM5XMLParserTests.swift — JD2-LogbookTests
// v1.1 格式擴充：Suunto DM4/DM5 WCF XML 解析器測試（真實 D4i 匯出樣本）

import XCTest
@testable import JoyDive_

final class SuuntoDM5XMLParserTests: XCTestCase {

    private var dm5Dir: String {
        let here       = (#filePath as NSString).deletingLastPathComponent
        let moduleRoot = (here as NSString).deletingLastPathComponent
        let repoRoot   = (moduleRoot as NSString).deletingLastPathComponent
        return (repoRoot as NSString).appendingPathComponent("TestFiles/Suunto/DM5")
    }

    private func dm5Path(_ filename: String) -> String {
        (dm5Dir as NSString).appendingPathComponent(filename)
    }

    private func skipIfMissing(_ path: String) throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: path),
                          "測試檔案不存在，略過：\((path as NSString).lastPathComponent)")
    }

    // MARK: - 格式偵測

    func testCanHandleRequiresXMLExtension() {
        let parser = SuuntoDM5XMLParser()
        XCTAssertFalse(parser.canHandle(filePath: "/path/to/file.json"))
    }

    func testValidateContentWithSuuntoDivingDal() {
        let parser = SuuntoDM5XMLParser()
        let data = "<Dive xmlns=\"http://schemas.datacontract.org/2004/07/Suunto.Diving.Dal\">".data(using: .utf8)!
        XCTAssertTrue(parser.validateContent(data))
    }

    func testValidateContentRejectsOtherXML() {
        let parser = SuuntoDM5XMLParser()
        let data = "<divelog program='subsurface' version='3'>".data(using: .utf8)!
        XCTAssertFalse(parser.validateContent(data))
    }

    // MARK: - 真實 D4i 樣本解析（file_format_research 驗證過的地面真相）

    func testParseRealD4iSample() throws {
        let path = dm5Path("Dive_2026-06-03-0821.xml")
        try skipIfMissing(path)
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let dives = try SuuntoDM5XMLParser.parseXMLData(data)
        XCTAssertEqual(dives.count, 1)
        let dive = dives[0]

        XCTAssertEqual(dive.maxDepth, 23.88, accuracy: 0.001)
        XCTAssertEqual(dive.diveTimeSeconds, 2269)
        XCTAssertEqual(dive.avgDepth, 15.76, accuracy: 0.001)
        XCTAssertEqual(dive.waterTemperature, 28, accuracy: 0.001)
        XCTAssertEqual(dive.sourceFormat, "suunto-dm5")

        // Nitrox 30%（Oxygen=30 → fO2=0.30）
        guard let gasData = dive.gasMixJSON.data(using: .utf8),
              let gas = try? JSONDecoder().decode(GasMix.self, from: gasData) else {
            XCTFail("gasMixJSON 應可解碼")
            return
        }
        if case .nitrox(let fO2) = gas {
            XCTAssertEqual(fO2, 0.30, accuracy: 0.001)
        } else {
            XCTFail("應為 Nitrox 30%，實際: \(gas)")
        }

        XCTAssertFalse(dive.profileSamples.isEmpty, "應含深度剖面樣本")
        // 第一筆樣本：Time=0, Depth=1.56
        XCTAssertEqual(dive.profileSamples.first?.timeSeconds, 0)
        XCTAssertEqual(dive.profileSamples.first?.depthMeters ?? 0, 1.56, accuracy: 0.001)
    }

    func testParseRealShortD4iSample() throws {
        let path = dm5Path("Dive_2021-10-09-0902.xml")
        try skipIfMissing(path)
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let dives = try SuuntoDM5XMLParser.parseXMLData(data)
        XCTAssertEqual(dives.count, 1)
        let dive = dives[0]

        XCTAssertEqual(dive.maxDepth, 9.93, accuracy: 0.001)
        XCTAssertEqual(dive.diveTimeSeconds, 428)
        XCTAssertEqual(dive.avgDepth, 4.54, accuracy: 0.001)
    }

    // MARK: - 合成資料錯誤處理

    func testParseMissingRequiredFieldsThrows() {
        let xml = "<Dive xmlns=\"http://schemas.datacontract.org/2004/07/Suunto.Diving.Dal\"></Dive>"
        let data = xml.data(using: .utf8)!
        XCTAssertThrowsError(try SuuntoDM5XMLParser.parseXMLData(data))
    }

    // MARK: - 工廠整合

    func testFactorySelectsForRealSample() throws {
        let path = dm5Path("Dive_2026-06-03-0821.xml")
        try skipIfMissing(path)
        let importer = DiveLogImporterFactory.selectImporter(for: path)
        XCTAssertEqual(importer?.format, .suuntoDM5)
    }
}
