// ReefnetSensusParserTests.swift — JD2-LogbookTests
// v1.1 格式擴充：Reefnet Sensus CSV 解析器測試

import XCTest
@testable import JoyDive_

final class ReefnetSensusParserTests: XCTestCase {

    private var sensusPath: String {
        let here       = (#filePath as NSString).deletingLastPathComponent
        let moduleRoot = (here as NSString).deletingLastPathComponent
        let repoRoot   = (moduleRoot as NSString).deletingLastPathComponent
        return (repoRoot as NSString).appendingPathComponent("../_JD2-family/dive-log-samples/Sensus/TestSensusSingle.csv")
    }

    private func skipIfMissing(_ path: String) throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: path),
                          "測試檔案不存在，略過：\((path as NSString).lastPathComponent)")
    }

    // MARK: - 格式偵測

    func testValidateContentWithSensusStructure() {
        let parser = ReefnetSensusParser()
        let sample = "1,SU-10000,0023469553,2011,3,27,11,25,29,0,1214,287,67\n" +
                     "1,SU-10000,0023469553,2011,3,27,11,25,29,10,1507,287,69"
        XCTAssertTrue(parser.validateContent(Data(sample.utf8)))
    }

    func testValidateContentRejectsSubsurfaceCSV() {
        let parser = ReefnetSensusParser()
        let sample = "#Nr;Date;Time\n1;1/1/24;10:00"
        XCTAssertFalse(parser.validateContent(Data(sample.utf8)))
    }

    func testValidateContentRejectsWrongFieldCount() {
        let parser = ReefnetSensusParser()
        XCTAssertFalse(parser.validateContent(Data("1,2,3\n1,2,3".utf8)))
    }

    // MARK: - 真實樣本解析

    func testParseRealSample() throws {
        try skipIfMissing(sensusPath)
        let importer = ReefnetSensusParser()
        let dives = try importer.parse(from: sensusPath)
        XCTAssertEqual(dives.count, 1)
        let dive = dives[0]

        XCTAssertEqual(dive.sourceFormat, "reefnet-sensus")
        XCTAssertEqual(dive.diveTimeSeconds, 6970)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: dive.dateTime)
        XCTAssertEqual(comps.year, 2011)
        XCTAssertEqual(comps.month, 3)
        XCTAssertEqual(comps.day, 27)
        XCTAssertEqual(comps.hour, 11)
        XCTAssertEqual(comps.minute, 25)
        XCTAssertEqual(comps.second, 29)

        // 第一筆樣本 pressure=1214mbar → depth=(1214-1013)*0.00975=1.95975m
        XCTAssertEqual(dive.profileSamples.first?.depthMeters ?? -1, 1.95975, accuracy: 0.001)
        XCTAssertFalse(dive.profileSamples.isEmpty)
    }

    func testFactorySelectsForRealSample() throws {
        try skipIfMissing(sensusPath)
        let importer = DiveLogImporterFactory.selectImporter(for: sensusPath)
        XCTAssertEqual(importer?.format, .sensus)
    }

    // MARK: - 壓力轉深度公式

    func testDepthFormulaSyntheticData() throws {
        // pressure=1013mbar（surface）→ depth≈0；pressure=2000mbar → depth≈9.62m
        let text = """
        1,SU-TEST,000001,2024,1,1,10,0,0,0,1013,287,60
        1,SU-TEST,000001,2024,1,1,10,0,0,10,2000,287,60
        """
        let dives = try ReefnetSensusParser.parseText(text)
        XCTAssertEqual(dives.count, 1)
        let samples = dives[0].profileSamples
        XCTAssertEqual(samples[0].depthMeters, 0, accuracy: 0.01)
        XCTAssertEqual(samples[1].depthMeters, (2000.0 - 1013) * 0.00975, accuracy: 0.001)
    }

    func testParseNoValidRowsThrows() {
        XCTAssertThrowsError(try ReefnetSensusParser.parseText("not,valid,sensus,data"))
    }
}
