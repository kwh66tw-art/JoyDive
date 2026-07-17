// SuuntoSDEParserTests.swift — JD2-LogbookTests
// v1.1 格式擴充：Suunto SDE（ZIP 包裝的 DM3 XML）解析器測試

import XCTest
@testable import JoyDive_

final class SuuntoSDEParserTests: XCTestCase {

    private var sdePath: String {
        let here       = (#filePath as NSString).deletingLastPathComponent
        let moduleRoot = (here as NSString).deletingLastPathComponent
        let repoRoot   = (moduleRoot as NSString).deletingLastPathComponent
        return (repoRoot as NSString).appendingPathComponent("TestFiles/Suunto/SDE/TestDiveDM3.SDE")
    }

    private func skipIfMissing(_ path: String) throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: path),
                          "測試檔案不存在，略過：\((path as NSString).lastPathComponent)")
    }

    // MARK: - 格式偵測

    func testValidateContentWithZipMagic() {
        let parser = SuuntoSDEParser()
        let data = Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00])
        XCTAssertTrue(parser.validateContent(data))
    }

    func testValidateContentRejectsNonZip() {
        let parser = SuuntoSDEParser()
        XCTAssertFalse(parser.validateContent(Data("not a zip".utf8)))
    }

    // MARK: - 真實樣本解析

    func testParseRealSample() throws {
        let path = sdePath
        try skipIfMissing(path)
        let importer = SuuntoSDEParser()
        let dives = try importer.parse(from: path)
        XCTAssertEqual(dives.count, 1)
        let dive = dives[0]

        // MAXDEPTH="24,69" MEANDEPTH="11,89" DIVETIMESEC=1890
        XCTAssertEqual(dive.maxDepth, 24.69, accuracy: 0.001)
        XCTAssertEqual(dive.avgDepth, 11.89, accuracy: 0.001)
        XCTAssertEqual(dive.diveTimeSeconds, 1890)
        XCTAssertEqual(dive.sourceFormat, "suunto-sde")
        XCTAssertEqual(dive.location, "Sund Rock, Hoodsport, WA")

        // O2PCT=32 → Nitrox 32%
        guard let gasData = dive.gasMixJSON.data(using: .utf8),
              let gas = try? JSONDecoder().decode(GasMix.self, from: gasData) else {
            XCTFail("gasMixJSON 應可解碼")
            return
        }
        if case .nitrox(let fO2) = gas {
            XCTAssertEqual(fO2, 0.32, accuracy: 0.001)
        } else {
            XCTFail("應為 Nitrox 32%，實際: \(gas)")
        }

        // DATE="17.05.2011" TIME="11:01:00"
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: dive.dateTime)
        XCTAssertEqual(comps.year, 2011)
        XCTAssertEqual(comps.month, 5)
        XCTAssertEqual(comps.day, 17)
        XCTAssertEqual(comps.hour, 11)
        XCTAssertEqual(comps.minute, 1)

        XCTAssertFalse(dive.profileSamples.isEmpty)
        // 第一筆樣本：SAMPLETIME=0, DEPTH=0
        XCTAssertEqual(dive.profileSamples.first?.timeSeconds, 0)
        XCTAssertEqual(dive.profileSamples.first?.depthMeters ?? -1, 0, accuracy: 0.001)
    }

    func testFactorySelectsForRealSample() throws {
        try skipIfMissing(sdePath)
        let importer = DiveLogImporterFactory.selectImporter(for: sdePath)
        XCTAssertEqual(importer?.format, .suuntoSDE)
    }

    // MARK: - 逗號小數轉換

    func testCommaDecimalParsingInSyntheticXML() throws {
        let xml = """
        <SUUNTO><HEADER></HEADER><MSG>
        <DATE>01.01.2024</DATE><TIME>10:00:00</TIME>
        <MAXDEPTH>15,5</MAXDEPTH><MEANDEPTH>8,25</MEANDEPTH><DIVETIMESEC>1200</DIVETIMESEC>
        <O2PCT>21</O2PCT>
        <SAMPLE><SAMPLETIME>0</SAMPLETIME><DEPTH>0,0</DEPTH><TEMPERATURE>20</TEMPERATURE></SAMPLE>
        </MSG></SUUNTO>
        """
        let dives = try SuuntoSDEParser.parseDM3XMLData(Data(xml.utf8))
        XCTAssertEqual(dives.count, 1)
        XCTAssertEqual(dives[0].maxDepth, 15.5, accuracy: 0.001)
        XCTAssertEqual(dives[0].avgDepth, 8.25, accuracy: 0.001)
    }

    func testParseEmptyDataThrows() {
        XCTAssertThrowsError(try SuuntoSDEParser.parseDM3XMLData(Data()))
    }
}
