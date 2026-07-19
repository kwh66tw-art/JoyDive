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
        return (repoRoot as NSString).appendingPathComponent("../_JD2-family/dive-log-samples/DAN")
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

    // MARK: - 真實樣本解析（Subsurface 官方測試檔完整版，3 組 ZDH/ZDT + 1 組 ZDP{} 剖面區塊）
    //
    // 2026-07-19 校正：`DL7.zxu` 已從截斷版換成 Subsurface 官方 GitHub 測試目錄的完整版
    // （逐字元核對前 5 行與遠端一致），內容為 3 組 ZDH/ZDT：
    //   1) ZDH|1|1|...20180101101000  / ZDT|1|1|10.0|20180101102000|25   → 正常配對
    //   2) ZDH|2|2|...20180102101000  / ZDP{ 區塊 } / ZDT|1|2|10.0|20180102110000|25
    //      → ZDH 的 dive sequence 是 "2"（field[1]），但配對的 ZDT 卻是 "1"，兩者不對稱。
    //        `DANDL7Parser.parseText` 目前用 field[1] 當 pending 字典的 key 做配對，
    //        seq "1" 已在第 1) 組用掉並移除，所以這組 ZDT 找不到 pending["1"]，
    //        guard 失敗直接跳過——這組潛水（含 ZDP 剖面）因此被**靜默捨棄**，
    //        不會出現在 dives 陣列裡。這是真實資料首次曝露此配對規則的邊界案例，
    //        照實記錄，不在測試裡假裝它有被解析出來。
    //        另外 `ZDP{` / `|...|` / `ZDP}` 這種多行區塊語法，switch 只精確比對
    //        recordType == "ZDP"，並不比對 "ZDP{"／""／"ZDP}"，所以即使配對邏輯
    //        沒有這個問題，這個區塊格式的剖面樣本目前也**完全不會被解析**——
    //        parser 檔頭註解裡「若真實檔案有 ZDP 則一併支援」目前只涵蓋單行
    //        `ZDP|time|depth|...` 格式（見 testParseMultipleDivesWithProfile），
    //        不涵蓋這種區塊格式。此為已知落差，回報總指揮，未在此修解析器本體。
    //   3) ZDH|1|3|...20180103101000  / ZDT|1|3|10.0|20180103102000|26   → 正常配對
    //        （seq "1" 在第 2) 組結束時已釋出，這裡重新使用不衝突）
    //
    // 淨結果：dives.count == 2（第 1、3 組），profileSamples 兩筆皆為空陣列。
    func testParseRealSample() throws {
        let path = (danDir as NSString).appendingPathComponent("DL7.zxu")
        try skipIfMissing(path)
        let text = try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
        let dives = try DANDL7Parser.parseText(text)

        // 中間那組 ZDH(seq=2)/ZDT(seq=1) 因 sequence 不對稱配對失敗被捨棄，
        // 只剩頭尾兩組正常配對的潛水。
        XCTAssertEqual(dives.count, 2, "中間那組 ZDH/ZDT sequence 不對稱應配對失敗被捨棄，僅存頭尾兩組")

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        // 第一組：ZDH leave_surface_time=20180101101000／ZDT max_depth=10.0,
        // reach_surface_time=20180101102000（10 分鐘後）, min_water_temp=25
        let dive1 = dives[0]
        XCTAssertEqual(dive1.maxDepth, 10.0, accuracy: 0.001)
        XCTAssertEqual(dive1.diveTimeSeconds, 600, "10:10:00 → 10:20:00，時長應為 600 秒")
        XCTAssertEqual(dive1.waterTemperature, 25.0, accuracy: 0.001)
        XCTAssertEqual(dive1.sourceFormat, "dan-dl7")
        XCTAssertTrue(dive1.profileSamples.isEmpty, "此組未含 ZDP 資料")
        let comps1 = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: dive1.dateTime)
        XCTAssertEqual(comps1.year, 2018)
        XCTAssertEqual(comps1.month, 1)
        XCTAssertEqual(comps1.day, 1)
        XCTAssertEqual(comps1.hour, 10)
        XCTAssertEqual(comps1.minute, 10)

        // 第三組：ZDH leave_surface_time=20180103101000／ZDT max_depth=10.0,
        // reach_surface_time=20180103102000（10 分鐘後）, min_water_temp=26
        let dive2 = dives[1]
        XCTAssertEqual(dive2.maxDepth, 10.0, accuracy: 0.001)
        XCTAssertEqual(dive2.diveTimeSeconds, 600, "10:10:00 → 10:20:00，時長應為 600 秒")
        XCTAssertEqual(dive2.waterTemperature, 26.0, accuracy: 0.001)
        XCTAssertEqual(dive2.sourceFormat, "dan-dl7")
        // 中間那組（含 ZDP{} 剖面區塊）配對失敗被整組捨棄，不會有任何殘留樣本
        // 混進這一筆；同時也再次確認區塊格式本身目前不會產出 profileSamples。
        XCTAssertTrue(dive2.profileSamples.isEmpty, "區塊格式 ZDP{} 目前不被解析，且此組本身也未含 ZDP 資料")
        let comps2 = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: dive2.dateTime)
        XCTAssertEqual(comps2.year, 2018)
        XCTAssertEqual(comps2.month, 1)
        XCTAssertEqual(comps2.day, 3)
        XCTAssertEqual(comps2.hour, 10)
        XCTAssertEqual(comps2.minute, 10)
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
