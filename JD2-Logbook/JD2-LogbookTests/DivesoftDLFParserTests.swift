// DivesoftDLFParserTests.swift — JD2-LogbookTests
// v1.1 格式擴充：Divesoft DLF 二進位解析器測試
//
// 地面真相（ground truth）來源：TestFiles/Divesoft/*.dlf.xml 為 Subsurface
// 對這批真實二進位樣本的官方解碼結果；header 欄位（start_time/max_depth/
// min_temperature）已手動逐位元核對到位元組層級精確吻合，寫入以下斷言。
// duration 欄位為裝置原始記錄值（3327s），與 Subsurface 顯示值（55:01=3301s，
// 已去除頭尾修剪）略有差異，屬預期行為，非本解析器誤差。

import XCTest
@testable import JoyDive_

final class DivesoftDLFParserTests: XCTestCase {

    private var divesoftDir: String {
        let here       = (#filePath as NSString).deletingLastPathComponent
        let moduleRoot = (here as NSString).deletingLastPathComponent
        let repoRoot   = (moduleRoot as NSString).deletingLastPathComponent
        return (repoRoot as NSString).appendingPathComponent("../_JD2-family/dive-log-samples/Divesoft")
    }

    private func dlfPath(_ filename: String) -> String {
        (divesoftDir as NSString).appendingPathComponent(filename)
    }

    private func skipIfMissing(_ path: String) throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: path),
                          "測試檔案不存在，略過：\((path as NSString).lastPathComponent)")
    }

    // MARK: - 格式偵測

    func testValidateContentWithDivEMagic() {
        let parser = DivesoftDLFParser()
        var bytes = Array("DivE".utf8)
        bytes.append(contentsOf: [UInt8](repeating: 0, count: 28))
        XCTAssertTrue(parser.validateContent(Data(bytes)))
    }

    func testValidateContentRejectsOtherMagic() {
        let parser = DivesoftDLFParser()
        var bytes = Array("XXXX".utf8)
        bytes.append(contentsOf: [UInt8](repeating: 0, count: 28))
        XCTAssertFalse(parser.validateContent(Data(bytes)))
    }

    func testValidateContentRejectsTruncated() {
        let parser = DivesoftDLFParser()
        XCTAssertFalse(parser.validateContent(Data(Array("DivE".utf8))))
    }

    // MARK: - 真實樣本解析（header 欄位已手動逐位元核對）

    func testParseRealSampleHeaderFields() throws {
        let path = dlfPath("Freedom_MIX_header_v1_00000115.dlf")
        try skipIfMissing(path)
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let dives = try DivesoftDLFParser.parseBinaryData(data)
        XCTAssertEqual(dives.count, 1)
        let dive = dives[0]

        // max_depth：header offset 20-21，uint16 LE ÷100 = 31.56m（與 .dlf.xml mean/max 吻合）
        XCTAssertEqual(dive.maxDepth, 31.56, accuracy: 0.001)
        // min_temperature：header bit_array_2 bits[18:28] ÷10 = 3.9°C（與 .dlf.xml water temp 吻合）
        XCTAssertEqual(dive.waterTemperature, 3.9, accuracy: 0.001)
        // duration：header bit_array_1 bits[0:17] = 3327s（裝置原始值，見上方說明）
        XCTAssertEqual(dive.diveTimeSeconds, 3327)
        XCTAssertEqual(dive.sourceFormat, "divesoft-dlf")

        // start_time：946684800（2000-01-01 epoch）+ header uint32 = 2019-02-10T10:09:13Z
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: dive.dateTime)
        XCTAssertEqual(comps.year, 2019)
        XCTAssertEqual(comps.month, 2)
        XCTAssertEqual(comps.day, 10)
        XCTAssertEqual(comps.hour, 10)
        XCTAssertEqual(comps.minute, 9)
        XCTAssertEqual(comps.second, 13)
    }

    func testParseRealSampleProfileSamples() throws {
        let path = dlfPath("Freedom_MIX_header_v1_00000115.dlf")
        try skipIfMissing(path)
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let dives = try DivesoftDLFParser.parseBinaryData(data)
        let dive = dives[0]

        XCTAssertFalse(dive.profileSamples.isEmpty, "應解析出至少部分 Point 型別記錄")
        // 剖面深度不應超過 header 宣稱的 max_depth（容許裝置量測誤差）
        let sampledMax = dive.profileSamples.map(\.depthMeters).max() ?? 0
        XCTAssertLessThanOrEqual(sampledMax, dive.maxDepth + 1.0)
        // 樣本時間應遞增排序且非負
        let times = dive.profileSamples.map(\.timeSeconds)
        XCTAssertEqual(times, times.sorted())
        XCTAssertTrue(times.allSatisfy { $0 >= 0 })
    }

    // MARK: - 其餘真實樣本

    /// Liberty CCR 樣本的 magic bytes 為 "DivE"（與本解析器支援的 v1 header 格式相同），
    /// header 欄位（log_number=11 與檔名吻合、dive_record_count 與檔案大小整除吻合）
    /// 手動核對過，應能成功解析。
    func testParseCCRSample() throws {
        let path = dlfPath("Liberty_CCR_header_v1_00000011.dlf")
        try skipIfMissing(path)
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let dives = try DivesoftDLFParser.parseBinaryData(data)
        XCTAssertEqual(dives.count, 1)
        XCTAssertGreaterThan(dives[0].maxDepth, 0)
        XCTAssertGreaterThan(dives[0].diveTimeSeconds, 0)
    }

    /// "Freedom_*_header_v2_*.dlf" 樣本的 magic bytes 是 "DiVE"（大寫 V），與本解析器
    /// 支援的 v1 header 格式（"DivE"）不同——這是韌體的 header 版本欄位差異，不是
    /// 損毀檔案。目前尚未取得 v2 header 的欄位對照，明確拒絕優於臆測欄位位移
    /// （臆測錯了會產生「看起來合理但實際錯誤」的深度/時間資料，比不支援更危險）。
    func testParseV2HeaderSamplesAreExplicitlyRejected() throws {
        let filenames = [
            "Freedom_MIX_header_v2_00000003.dlf",
            "Freedom_MIX2_header_v2_00000007.dlf",
            "Freedom_MIX2_header_v2_factory_test_00000001.dlf",
        ]
        for filename in filenames {
            let path = dlfPath(filename)
            try skipIfMissing(path)
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            XCTAssertThrowsError(try DivesoftDLFParser.parseBinaryData(data),
                                "\(filename)（DiVE v2 header）應明確拋出不支援錯誤，而非臆測解析")
        }
    }

    // MARK: - 錯誤處理

    func testParseInvalidMagicThrows() {
        var bytes = Array("XXXX".utf8)
        bytes.append(contentsOf: [UInt8](repeating: 0, count: 28))
        XCTAssertThrowsError(try DivesoftDLFParser.parseBinaryData(Data(bytes)))
    }

    func testParseTruncatedDataThrows() {
        XCTAssertThrowsError(try DivesoftDLFParser.parseBinaryData(Data(Array("DivE".utf8))))
    }
}
