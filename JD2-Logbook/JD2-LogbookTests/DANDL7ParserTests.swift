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
    // 2026-07-19 二度校正：修好 DANDL7Parser 的兩個配對/解析 bug 後重新驗證。
    // 依 PyDL7（divelog/dl7/__init__.py）原始碼核對，ZDH／ZDT 用來配對的 dive
    // sequence number 是 raw field[2]（PyDL7 稱 internal sequence／
    // dive.sequence_number），不是 field[1]（那只是 export_sequence，檔案內
    // 流水號，兩個 ZDH 可以有不同 export_sequence 但相同/不同 sequence_number，
    // 之前誤用 field[1] 當 key 才會在第二組「配對失敗」）。內容為 3 組 ZDH/ZDT：
    //   1) ZDH|1|1|...20180101101000  / ZDT|1|1|10.0|20180101102000|25
    //      → field[2] 兩邊都是 "1"，正常配對。
    //   2) ZDH|2|2|...20180102101000  / ZDP{ 區塊，4 個樣本點 } /
    //      ZDT|1|2|10.0|20180102110000|25
    //      → field[2] 兩邊都是 "2"，正常配對；區塊內剖面樣本現在也會被解析
    //        （見下方欄位語意，同樣依 PyDL7 __parse_dive_profile 核對）。
    //   3) ZDH|1|3|...20180103101000  / ZDT|1|3|10.0|20180103102000|26
    //      → field[2] 兩邊都是 "3"，正常配對。
    //
    // 淨結果：dives.count == 3，中間那筆（Jan 2）帶 4 筆 profileSamples。
    func testParseRealSample() throws {
        let path = (danDir as NSString).appendingPathComponent("DL7.zxu")
        try skipIfMissing(path)
        let text = try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
        let dives = try DANDL7Parser.parseText(text)

        XCTAssertEqual(dives.count, 3, "field[2] 配對修好後，3 組 ZDH/ZDT 應全部配對成功")

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

        // 第二組（中間）：ZDH leave_surface_time=20180102101000／ZDT max_depth=10.0,
        // reach_surface_time=20180102110000（50 分鐘後）, min_water_temp=25，
        // 含 ZDP{...ZDP} 區塊剖面：|0|1|1||||／|60|10|||||／|3300|10|||||／|3600|0|||||
        // → (timeSeconds, depthMeters) = (0,1) (60,10) (3300,10) (3600,0)，
        //   waterTemp 皆為 nil（每行欄位數不足以取到 field[8]）。
        // 注意：最後一個樣本點 timeSeconds=3600 略超過 ZDT 算出的 diveTimeSeconds=3000，
        // 這是真實樣本本身的資料不一致（剖面記錄與 ZDT 摘要時長對不齊），profileSamples
        // 只是原樣保留讀到的資料，不做校正或臆造。
        let dive2 = dives[1]
        XCTAssertEqual(dive2.maxDepth, 10.0, accuracy: 0.001)
        XCTAssertEqual(dive2.diveTimeSeconds, 3000, "10:10:00 → 11:00:00，時長應為 3000 秒")
        XCTAssertEqual(dive2.waterTemperature, 25.0, accuracy: 0.001)
        XCTAssertEqual(dive2.sourceFormat, "dan-dl7")
        XCTAssertEqual(dive2.profileSamples.count, 4, "ZDP{...ZDP} 區塊應解析出 4 個樣本點")
        let expectedSamples: [(time: Double, depth: Double)] = [(0, 1), (60, 10), (3300, 10), (3600, 0)]
        for (index, expected) in expectedSamples.enumerated() {
            XCTAssertEqual(dive2.profileSamples[index].timeSeconds, expected.time, accuracy: 0.001,
                            "第 \(index) 個樣本點時間偏移不符")
            XCTAssertEqual(dive2.profileSamples[index].depthMeters, expected.depth, accuracy: 0.001,
                            "第 \(index) 個樣本點深度不符")
            XCTAssertNil(dive2.profileSamples[index].waterTemp, "區塊行欄位數不足，water_temp 應為 nil")
        }
        let comps2 = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: dive2.dateTime)
        XCTAssertEqual(comps2.year, 2018)
        XCTAssertEqual(comps2.month, 1)
        XCTAssertEqual(comps2.day, 2)
        XCTAssertEqual(comps2.hour, 10)
        XCTAssertEqual(comps2.minute, 10)

        // 第三組：ZDH leave_surface_time=20180103101000／ZDT max_depth=10.0,
        // reach_surface_time=20180103102000（10 分鐘後）, min_water_temp=26
        let dive3 = dives[2]
        XCTAssertEqual(dive3.maxDepth, 10.0, accuracy: 0.001)
        XCTAssertEqual(dive3.diveTimeSeconds, 600, "10:10:00 → 10:20:00，時長應為 600 秒")
        XCTAssertEqual(dive3.waterTemperature, 26.0, accuracy: 0.001)
        XCTAssertEqual(dive3.sourceFormat, "dan-dl7")
        XCTAssertTrue(dive3.profileSamples.isEmpty, "此組未含 ZDP 資料")
        let comps3 = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: dive3.dateTime)
        XCTAssertEqual(comps3.year, 2018)
        XCTAssertEqual(comps3.month, 1)
        XCTAssertEqual(comps3.day, 3)
        XCTAssertEqual(comps3.hour, 10)
        XCTAssertEqual(comps3.minute, 10)
    }

    // MARK: - ZDP{...ZDP} 多行區塊語法邊界情況

    func testParseZDPBlockEdgeCases() throws {
        let text = """
        FSH|^~\\&{}|TEST|ZXU|20240101000000+00:00|
        ZRH|^~\\&{}|||MFWG|ThM|C|bar|L|
        ZDH|1|1|I|QS|20240101100000|27|11|FO2|||
        ZDP{
        ZDP}
        ZDT|1|1|20.0|20240101103000|24||
        ZDH|2|2|I|QS|20240102100000|27|11|FO2|||
        ZDP{
        |0|2.0|||||
        |notanumber|5.0|||||
        |120|8.0|||||
        ZDP}
        ZDT|2|2|15.0|20240102101500|23||
        """
        let dives = try DANDL7Parser.parseText(text)
        XCTAssertEqual(dives.count, 2)

        // 第一筆：空區塊（ZDP{ 緊接 ZDP}），不應產生任何樣本，也不應影響配對。
        XCTAssertTrue(dives[0].profileSamples.isEmpty, "空的 ZDP{}區塊不應產生樣本")

        // 第二筆：區塊內有一行格式錯誤（elapsed 非數字），應被靜默略過，
        // 其餘合法行仍應正常解析，不因單一壞行中斷整個區塊。
        XCTAssertEqual(dives[1].profileSamples.count, 2, "格式錯誤的行應被略過，其餘 2 筆合法樣本仍應解析成功")
        XCTAssertEqual(dives[1].profileSamples[0].timeSeconds, 0, accuracy: 0.001)
        XCTAssertEqual(dives[1].profileSamples[0].depthMeters, 2.0, accuracy: 0.001)
        XCTAssertEqual(dives[1].profileSamples[1].timeSeconds, 120, accuracy: 0.001)
        XCTAssertEqual(dives[1].profileSamples[1].depthMeters, 8.0, accuracy: 0.001)
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

    // MARK: - Import 樣本驗證（00_Import_samples/DAN_DL7，供 App 匯入流程用的樣本檔）
    //
    // 結構與 `DL7.zxu`（Subsurface 官方測試檔）完全相同，僅日期改到 2026-06-01/02/03，
    // 用來確認匯入樣本目錄裡的檔案也能被修好的解析器正確處理（3 筆潛水，中間一筆
    // 含 ZDP{...ZDP} 區塊剖面）。
    func testParseImportSampleFile() throws {
        let here       = (#filePath as NSString).deletingLastPathComponent
        let moduleRoot = (here as NSString).deletingLastPathComponent
        let repoRoot   = (moduleRoot as NSString).deletingLastPathComponent
        let path = (repoRoot as NSString)
            .appendingPathComponent("../_JD2-family/00_Import_samples/DAN_DL7/dive_2026-06-01.zxu")
        try skipIfMissing(path)
        let text = try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
        let dives = try DANDL7Parser.parseText(text)

        XCTAssertEqual(dives.count, 3, "dive_2026-06-01.zxu 應解析出 3 筆潛水")

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        let dive1 = dives[0]
        XCTAssertEqual(dive1.maxDepth, 10.0, accuracy: 0.001)
        XCTAssertEqual(dive1.diveTimeSeconds, 600)
        XCTAssertTrue(dive1.profileSamples.isEmpty)
        let comps1 = cal.dateComponents([.year, .month, .day], from: dive1.dateTime)
        XCTAssertEqual(comps1.year, 2026)
        XCTAssertEqual(comps1.month, 6)
        XCTAssertEqual(comps1.day, 1)

        let dive2 = dives[1]
        XCTAssertEqual(dive2.maxDepth, 10.0, accuracy: 0.001)
        XCTAssertEqual(dive2.diveTimeSeconds, 3000)
        XCTAssertEqual(dive2.profileSamples.count, 4, "中間那筆應解析出 ZDP{} 區塊的 4 個樣本點")
        let expectedSamples: [(time: Double, depth: Double)] = [(0, 1), (60, 10), (3300, 10), (3600, 0)]
        for (index, expected) in expectedSamples.enumerated() {
            XCTAssertEqual(dive2.profileSamples[index].timeSeconds, expected.time, accuracy: 0.001)
            XCTAssertEqual(dive2.profileSamples[index].depthMeters, expected.depth, accuracy: 0.001)
        }
        let comps2 = cal.dateComponents([.year, .month, .day], from: dive2.dateTime)
        XCTAssertEqual(comps2.year, 2026)
        XCTAssertEqual(comps2.month, 6)
        XCTAssertEqual(comps2.day, 2)

        let dive3 = dives[2]
        XCTAssertEqual(dive3.maxDepth, 10.0, accuracy: 0.001)
        XCTAssertEqual(dive3.diveTimeSeconds, 600)
        XCTAssertTrue(dive3.profileSamples.isEmpty)
        let comps3 = cal.dateComponents([.year, .month, .day], from: dive3.dateTime)
        XCTAssertEqual(comps3.year, 2026)
        XCTAssertEqual(comps3.month, 6)
        XCTAssertEqual(comps3.day, 3)
    }
}
