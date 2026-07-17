// DANDL7ParserTests.swift — JD2-LogbookTests
// v1.1 格式擴充：DAN DL7 / ZXU 解析器測試
//
// 欄位對照已依開源 PyDL7（github.com/johnstonskj/PyDL7）實際解析邏輯校正，
// 非原始研究文件的初版猜測（ZDT 是 Dive Trailer 而非逐樣本剖面）。

import XCTest
@testable import JoyDive_

final class DANDL7ParserTests: XCTestCase {

    private var danDir: String {
        let here       = (#filePath as NSString).deletingLastPathComponent
        let moduleRoot = (here as NSString).deletingLastPathComponent
        let repoRoot   = (moduleRoot as NSString).deletingLastPathComponent
        return (repoRoot as NSString).appendingPathComponent("TestFiles/DAN")
    }

    private func skipIfMissing(_ path: String) throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: path),
                          "測試檔案不存在，略過：\((path as NSString).lastPathComponent)")
    }

    // MARK: - 格式偵測

    func testValidateContentWithFSHAndZXU() {
        let parser = DANDL7Parser()
        let data = "FSH|^~\\&{}|ANST01^12X456^A|ZXU|20180106163705+02:00|".data(using: .utf8)!
        XCTAssertTrue(parser.validateContent(data))
    }

    func testValidateContentRejectsOtherText() {
        let parser = DANDL7Parser()
        let data = "just some random text file".data(using: .utf8)!
        XCTAssertFalse(parser.validateContent(data))
    }

    // MARK: - 真實樣本解析（含一組完整 ZDH/ZDT 配對 + 一個沒有 ZDT 的截斷 ZDH）

    func testParseRealSample() throws {
        let path = (danDir as NSString).appendingPathComponent("DL7.zxu")
        try skipIfMissing(path)
        let text = try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
        let dives = try DANDL7Parser.parseText(text)

        // 檔案含 2 個 ZDH 但只有 1 個 ZDT，第二個 dive 沒有配對應被捨棄
        XCTAssertEqual(dives.count, 1, "沒有 ZDT 配對的 ZDH 應被捨棄，不臆造資料")
        let dive = dives[0]

        // ZDH: leave_surface_time = 20180101101000
        // ZDT: max_depth=10.0, reach_surface_time=20180101102000（10 分鐘後）, min_water_temp=25
        XCTAssertEqual(dive.maxDepth, 10.0, accuracy: 0.001)
        XCTAssertEqual(dive.diveTimeSeconds, 600, "10:00:00 → 10:10:00，時長應為 600 秒")
        XCTAssertEqual(dive.waterTemperature, 25.0, accuracy: 0.001)
        XCTAssertEqual(dive.sourceFormat, "dan-dl7")

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: dive.dateTime)
        XCTAssertEqual(comps.year, 2018)
        XCTAssertEqual(comps.month, 1)
        XCTAssertEqual(comps.day, 1)
        XCTAssertEqual(comps.hour, 10)
        XCTAssertEqual(comps.minute, 10)
    }

    // MARK: - 多筆潛水 + ZDP 剖面樣本（合成資料）

    func testParseMultipleDivesWithProfile() throws {
        let text = """
        FSH|^~\\&{}|TEST|ZXU|20240101000000+00:00|
        ZRH|^~\\&{}|||MFWG|ThM|C|bar|L|
        ZDH|1|1|I|QS|20240101100000|27|11|FO2|||
        ZDP|0|1.0|||||||||
        ZDP|60|5.0|||||||||
        ZDT|1|1|20.0|20240101103000|24||
        ZDH|2|2|I|QS|20240102100000|27|11|FO2|||
        ZDT|2|2|15.0|20240102101500|23||
        """
        let dives = try DANDL7Parser.parseText(text)
        XCTAssertEqual(dives.count, 2)
        XCTAssertEqual(dives[0].maxDepth, 20.0, accuracy: 0.001)
        XCTAssertEqual(dives[0].diveTimeSeconds, 1800)
        XCTAssertEqual(dives[0].profileSamples.count, 2)
        XCTAssertEqual(dives[1].maxDepth, 15.0, accuracy: 0.001)
        XCTAssertEqual(dives[1].diveTimeSeconds, 900)
    }

    func testParseNoValidDivesThrows() {
        let text = "FSH|^~\\&{}|TEST|ZXU|20240101000000+00:00|\nZRH|^~\\&{}|||MFWG|ThM|C|bar|L|"
        XCTAssertThrowsError(try DANDL7Parser.parseText(text))
    }
}
