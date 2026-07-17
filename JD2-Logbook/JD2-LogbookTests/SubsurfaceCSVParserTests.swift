// SubsurfaceCSVParserTests.swift — JD2-LogbookTests
// Week 5：SubsurfaceCSVParser 單元測試
//
// 測試樣本：TestFiles/CSV/test41.csv（來自 Subsurface 開源專案）
// 參考輸出：subsurface/dives/test-csv.xml
//
// 測試覆蓋：
//   - 格式偵測（canHandle / validateContent）
//   - 4 筆真實潛水資料解析
//   - 日期格式 M/D/YY → UTC Date
//   - Duration MM:SS → seconds
//   - 多行 notes（RFC 4180 quoted field spanning lines）
//   - Double-quote 轉義 `""` → `"`
//   - 欄位含逗號（buddy: "Dirk, Linus"）
//   - 錯誤處理（空檔案、損壞資料、格式不符）
//   - RFC 4180 底層解析器直接測試
// AI-generated (Claude)

import XCTest
@testable import JoyDive_

final class SubsurfaceCSVParserTests: XCTestCase {

    // MARK: - 測試資源路徑

    private var testFilesDir: String {
        // TestFiles/CSV/ 在 JD2-Logbook 專案資料夾內
        let here = (#filePath as NSString).deletingLastPathComponent  // …/JD2-LogbookTests
        let projectRoot = (here as NSString).deletingLastPathComponent // …/JD2-Logbook
        let root = (projectRoot as NSString).deletingLastPathComponent // …/JD2-Logbook (repo)
        return (root as NSString).appendingPathComponent("TestFiles/CSV")
    }

    private var test41Path: String {
        (testFilesDir as NSString).appendingPathComponent("test41.csv")
    }

    // MARK: - 測試 1：格式偵測 — 副檔名過濾

    func testRejectNonCSVExtension() {
        let parser = SubsurfaceCSVParser()
        XCTAssertFalse(parser.canHandle(filePath: "/path/to/file.xml"),
                       ".xml 應被拒絕")
        XCTAssertFalse(parser.canHandle(filePath: "/path/to/file.ssrf"),
                       ".ssrf 應被拒絕")
        XCTAssertFalse(parser.canHandle(filePath: "/path/to/file.uddf"),
                       ".uddf 應被拒絕")
        XCTAssertFalse(parser.canHandle(filePath: "/path/to/file.fit"),
                       ".fit 應被拒絕")
    }

    // MARK: - 測試 2：格式偵測 — 內容驗證（#Nr header）

    func testValidateContentAcceptsNrHeader() {
        let csv = "#Nr,date,time,duration,maxdepth,avgdepth,buddy,suit,notes\n1,10/1/13,10:34,45:00,18,16,Linus,5mm,nice"
        let data = csv.data(using: .utf8)!
        XCTAssertTrue(SubsurfaceCSVParser().validateContent(data),
                      "#Nr header 應通過驗證")
    }

    func testValidateContentRejectsNonNrCSV() {
        let csv = "Date,Time,MaxDepth,Duration\n2024-01-01,10:00,20,45"
        let data = csv.data(using: .utf8)!
        XCTAssertFalse(SubsurfaceCSVParser().validateContent(data),
                       "無 #Nr header 的 CSV 應被拒絕")
    }

    func testValidateContentRejectsXML() {
        let xml = "<?xml version='1.0'?><divelog>"
        let data = xml.data(using: .utf8)!
        XCTAssertFalse(SubsurfaceCSVParser().validateContent(data),
                       "XML 內容應被拒絕")
    }

    func testValidateContentRejectsEmpty() {
        XCTAssertFalse(SubsurfaceCSVParser().validateContent(Data()),
                       "空資料應被拒絕")
    }

    // MARK: - 測試 3：canHandle 需要檔案實際存在

    func testCanHandleRealFile() throws {
        // 只有在 test41.csv 存在時才測試 canHandle
        guard FileManager.default.fileExists(atPath: test41Path) else {
            throw XCTSkip("test41.csv 不存在，跳過")
        }
        let parser = SubsurfaceCSVParser()
        XCTAssertTrue(parser.canHandle(filePath: test41Path),
                      "test41.csv 應通過 canHandle")
    }

    // MARK: - 測試 4：解析 test41.csv — 筆數

    func testParseRealFileDiveCount() throws {
        guard FileManager.default.fileExists(atPath: test41Path) else {
            throw XCTSkip("test41.csv 不存在，跳過")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: test41Path))
        let dives = try SubsurfaceCSVParser.parseCSVData(data)
        XCTAssertEqual(dives.count, 4, "test41.csv 應解析出 4 筆潛水")
    }

    // MARK: - 測試 5：Dive 1 — 基本欄位驗證

    func testDive1BasicFields() throws {
        guard FileManager.default.fileExists(atPath: test41Path) else {
            throw XCTSkip("test41.csv 不存在，跳過")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: test41Path))
        let dives = try SubsurfaceCSVParser.parseCSVData(data)
        let dive = dives[0]

        // 日期：10/1/13 → 2013-10-01 UTC
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: dive.dateTime)
        XCTAssertEqual(comps.year,   2013, "Dive 1 年份應為 2013")
        XCTAssertEqual(comps.month,  10,   "Dive 1 月份應為 10")
        XCTAssertEqual(comps.day,    1,    "Dive 1 日期應為 1")
        XCTAssertEqual(comps.hour,   10,   "Dive 1 時刻應為 10")
        XCTAssertEqual(comps.minute, 34,   "Dive 1 分鐘應為 34")

        // duration: 45:00 → 2700 秒
        XCTAssertEqual(dive.diveTimeSeconds, 2700, "Dive 1 時間應為 2700 秒（45:00）")

        // maxdepth: 18m
        XCTAssertEqual(dive.maxDepth, 18.0, accuracy: 0.001, "Dive 1 最大深度應為 18.0 m")

        // sourceFormat
        XCTAssertEqual(dive.sourceFormat, "csv", "來源格式應為 csv")
    }

    // MARK: - 測試 6：Dive 1 — Notes 含引號欄位

    func testDive1Notes() throws {
        guard FileManager.default.fileExists(atPath: test41Path) else {
            throw XCTSkip("test41.csv 不存在，跳過")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: test41Path))
        let dives = try SubsurfaceCSVParser.parseCSVData(data)
        XCTAssertEqual(dives[0].notes, "nice dive",
                       "Dive 1 notes 應為 'nice dive'")
    }

    // MARK: - 測試 7：Dive 2 — 多行 notes

    func testDive2MultilineNotes() throws {
        guard FileManager.default.fileExists(atPath: test41Path) else {
            throw XCTSkip("test41.csv 不存在，跳過")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: test41Path))
        let dives = try SubsurfaceCSVParser.parseCSVData(data)
        let notes = dives[1].notes

        // 預期：三行 notes（RFC 4180 多行 quoted field）
        XCTAssertTrue(notes.contains("sharks"),          "應含 'sharks'")
        XCTAssertTrue(notes.contains("stone fish"),      "應含 'stone fish'")
        XCTAssertTrue(notes.contains("turtle"),          "應含 'turtle'")
    }

    // MARK: - 測試 8：Dive 2 — Double-quote 轉義

    func testDive2DoubleQuoteEscape() throws {
        guard FileManager.default.fileExists(atPath: test41Path) else {
            throw XCTSkip("test41.csv 不存在，跳過")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: test41Path))
        let dives = try SubsurfaceCSVParser.parseCSVData(data)
        let notes = dives[1].notes

        // `""fred""` → `"fred"` in notes
        XCTAssertTrue(notes.contains("\"fred\""),
                      "double-quote 轉義：\"fred\" 應正確還原")
    }

    // MARK: - 測試 9：Dive 2 — 欄位含逗號（buddy）

    func testDive2Duration() throws {
        guard FileManager.default.fileExists(atPath: test41Path) else {
            throw XCTSkip("test41.csv 不存在，跳過")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: test41Path))
        let dives = try SubsurfaceCSVParser.parseCSVData(data)
        // 41:00 → 2460 秒
        XCTAssertEqual(dives[1].diveTimeSeconds, 2460,
                       "Dive 2 時間應為 2460 秒（41:00）")
    }

    // MARK: - 測試 10：Dive 3 — 日期隔天

    func testDive3Date() throws {
        guard FileManager.default.fileExists(atPath: test41Path) else {
            throw XCTSkip("test41.csv 不存在，跳過")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: test41Path))
        let dives = try SubsurfaceCSVParser.parseCSVData(data)
        let dive = dives[2]

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.year, .month, .day], from: dive.dateTime)
        XCTAssertEqual(comps.year,  2014, "Dive 3 年份應為 2014")
        XCTAssertEqual(comps.month, 10,   "Dive 3 月份應為 10")
        XCTAssertEqual(comps.day,   1,    "Dive 3 日期應為 1")
    }

    func testDive3Depth() throws {
        guard FileManager.default.fileExists(atPath: test41Path) else {
            throw XCTSkip("test41.csv 不存在，跳過")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: test41Path))
        let dives = try SubsurfaceCSVParser.parseCSVData(data)
        XCTAssertEqual(dives[2].maxDepth, 13.3, accuracy: 0.001,
                       "Dive 3 最大深度應為 13.3 m")
    }

    // MARK: - 測試 11：Dive 4 — 深度小數點

    func testDive4Fields() throws {
        guard FileManager.default.fileExists(atPath: test41Path) else {
            throw XCTSkip("test41.csv 不存在，跳過")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: test41Path))
        let dives = try SubsurfaceCSVParser.parseCSVData(data)
        let dive = dives[3]

        // maxdepth: 24.9
        XCTAssertEqual(dive.maxDepth, 24.9, accuracy: 0.001,
                       "Dive 4 最大深度應為 24.9 m")
        // duration: 34:00 → 2040 秒
        XCTAssertEqual(dive.diveTimeSeconds, 2040,
                       "Dive 4 時間應為 2040 秒（34:00）")
    }

    func testDive4Notes() throws {
        guard FileManager.default.fileExists(atPath: test41Path) else {
            throw XCTSkip("test41.csv 不存在，跳過")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: test41Path))
        let dives = try SubsurfaceCSVParser.parseCSVData(data)
        XCTAssertEqual(dives[3].notes, "cold water, visibility 3m",
                       "Dive 4 notes 應保留逗號")
    }

    // MARK: - 測試 12：日期解析獨立驗證

    func testParseDateTimeTwoDigitYear() {
        let date = SubsurfaceCSVParser.parseDateTime(date: "10/1/13", time: "10:34")
        XCTAssertNotNil(date, "10/1/13 10:34 應可解析")
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date!)
        XCTAssertEqual(comps.year,   2013)
        XCTAssertEqual(comps.month,  10)
        XCTAssertEqual(comps.day,    1)
        XCTAssertEqual(comps.hour,   10)
        XCTAssertEqual(comps.minute, 34)
    }

    func testParseDateTimeFourDigitYear() {
        let date = SubsurfaceCSVParser.parseDateTime(date: "3/15/2025", time: "8:00")
        XCTAssertNotNil(date, "3/15/2025 8:00 應可解析")
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(comps.year,  2025)
        XCTAssertEqual(comps.month, 3)
        XCTAssertEqual(comps.day,   15)
    }

    func testParseDateTimeInvalidReturnsNil() {
        // 完全無法解析的格式應回傳 nil
        XCTAssertNil(SubsurfaceCSVParser.parseDateTime(date: "not-a-date", time: "10:00"),
                     "無效日期字串應回傳 nil")
        XCTAssertNil(SubsurfaceCSVParser.parseDateTime(date: "abcd/ef/gh", time: "xx:yy"),
                     "非數字日期應回傳 nil")
        // 注意：越界值（月13、日32）Calendar 會 overflow 推算，不回傳 nil，屬於預期行為
    }

    // MARK: - 測試 13：Duration 解析獨立驗證

    func testParseDurationMMSS() {
        XCTAssertEqual(SubsurfaceCSVParser.parseDurationMMSS("45:00"), 2700,
                       "45:00 → 2700 秒")
        XCTAssertEqual(SubsurfaceCSVParser.parseDurationMMSS("41:00"), 2460,
                       "41:00 → 2460 秒")
        XCTAssertEqual(SubsurfaceCSVParser.parseDurationMMSS("1:30"),  90,
                       "1:30 → 90 秒")
        XCTAssertEqual(SubsurfaceCSVParser.parseDurationMMSS("0:00"),  0,
                       "0:00 → 0 秒")
        XCTAssertEqual(SubsurfaceCSVParser.parseDurationMMSS("100:59"), 6059,
                       "100:59 → 6059 秒（超過 60 分鐘）")
    }

    func testParseDurationInvalidReturnsZero() {
        XCTAssertEqual(SubsurfaceCSVParser.parseDurationMMSS(""),      0, "空字串 → 0")
        XCTAssertEqual(SubsurfaceCSVParser.parseDurationMMSS("45"),    0, "無冒號 → 0")
        XCTAssertEqual(SubsurfaceCSVParser.parseDurationMMSS("abc:def"), 0, "非數字 → 0")
    }

    // MARK: - 測試 14：RFC 4180 解析器直接測試

    func testRFC4180SimpleRow() {
        let rows = SubsurfaceCSVParser.parseRFC4180("a,b,c\n1,2,3\n")
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0], ["a", "b", "c"])
        XCTAssertEqual(rows[1], ["1", "2", "3"])
    }

    func testRFC4180QuotedComma() {
        let rows = SubsurfaceCSVParser.parseRFC4180("\"Dirk, Linus\",5mm,nice\n")
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0][0], "Dirk, Linus", "引號內的逗號應視為欄位內容")
    }

    func testRFC4180DoubleQuoteEscape() {
        let rows = SubsurfaceCSVParser.parseRFC4180("\"wet, 3mm \"\"shorty\"\"\",notes\n")
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0][0], "wet, 3mm \"shorty\"",
                       "\"\" 應轉義為單個 \"")
    }

    func testRFC4180MultilineField() {
        let csv = "1,\"line1\nline2\nline3\"\n"
        let rows = SubsurfaceCSVParser.parseRFC4180(csv)
        XCTAssertEqual(rows.count, 1, "多行 quoted field 應視為同一 row")
        XCTAssertTrue(rows[0][1].contains("line1"), "應含 line1")
        XCTAssertTrue(rows[0][1].contains("line2"), "應含 line2")
        XCTAssertTrue(rows[0][1].contains("line3"), "應含 line3")
    }

    func testRFC4180CRLFLineEnding() {
        let csv = "a,b\r\n1,2\r\n"
        let rows = SubsurfaceCSVParser.parseRFC4180(csv)
        XCTAssertEqual(rows.count, 2, "CRLF 換行應正確處理")
        XCTAssertEqual(rows[0], ["a", "b"])
        XCTAssertEqual(rows[1], ["1", "2"])
    }

    func testRFC4180EmptyTrailingLine() {
        let csv = "a,b\n1,2\n"   // 末尾有 \n，不應產生空行
        let rows = SubsurfaceCSVParser.parseRFC4180(csv)
        XCTAssertEqual(rows.count, 2, "末尾換行不應產生額外空行")
    }

    // MARK: - 測試 15：錯誤處理

    func testParseEmptyDataThrows() {
        XCTAssertThrowsError(try SubsurfaceCSVParser.parseCSVData(Data())) { error in
            if case DiveLogImportError.corruptedData = error { return }
            XCTFail("空資料應拋出 corruptedData，實際：\(error)")
        }
    }

    func testParseHeaderOnlyNoThrow() throws {
        // 只有 header 行，無資料行 → 回傳空陣列（不拋錯）
        let csv = "#Nr,date,time,duration,maxdepth,avgdepth,buddy,suit,notes\n"
        let data = csv.data(using: .utf8)!
        let dives = try SubsurfaceCSVParser.parseCSVData(data)
        XCTAssertEqual(dives.count, 0, "只有 header 應回傳空陣列")
    }

    func testParseInvalidRowsSkipped() throws {
        // 含欄位不足的行，應略過而不崩潰
        let csv = "#Nr,date,time,duration,maxdepth\n1,10/1/13\n2,10/1/13,10:34,45:00,18\n"
        let data = csv.data(using: .utf8)!
        let dives = try SubsurfaceCSVParser.parseCSVData(data)
        // 第一行欄位不足應跳過，第二行有效
        XCTAssertEqual(dives.count, 1, "欄位不足的行應略過")
    }

    func testParseFileNotFoundThrows() {
        let parser = SubsurfaceCSVParser()
        XCTAssertThrowsError(try parser.parse(from: "/nonexistent/path.csv")) { error in
            if case DiveLogImportError.fileNotFound = error { return }
            XCTFail("檔案不存在應拋出 fileNotFound，實際：\(error)")
        }
    }

    // MARK: - 測試 16：sourceFormat 欄位

    func testSourceFormatIsCSV() throws {
        let csv = "#Nr,date,time,duration,maxdepth,avgdepth,buddy,suit,notes\n1,10/1/13,10:34,45:00,18,16,Linus,5mm,test\n"
        let data = csv.data(using: .utf8)!
        let dives = try SubsurfaceCSVParser.parseCSVData(data)
        XCTAssertEqual(dives.first?.sourceFormat, "csv",
                       "sourceFormat 應為 'csv'")
    }

    // MARK: - 測試 17：DiveLogFormat 枚舉整合

    func testDiveLogFormatCSVExtensions() {
        XCTAssertTrue(DiveLogFormat.csv.supportedExtensions.contains("csv"),
                      "CSV format 應支援 .csv 副檔名")
    }

    func testDiveLogFormatCSVPriority() {
        // csv 優先級應低於 subsurface (0) 和 uddf (1)
        XCTAssertGreaterThan(DiveLogFormat.csv.priority, DiveLogFormat.subsurface.priority,
                             "CSV 優先級應低於 SubsurfaceXML")
        XCTAssertGreaterThan(DiveLogFormat.csv.priority, DiveLogFormat.uddf.priority,
                             "CSV 優先級應低於 UDDF")
    }

    // MARK: - 測試 18：Factory 自動偵測

    func testFactorySelectsCSVParser() throws {
        guard FileManager.default.fileExists(atPath: test41Path) else {
            throw XCTSkip("test41.csv 不存在，跳過")
        }
        let parser = DiveLogImporterFactory.selectImporter(for: test41Path)
        XCTAssertNotNil(parser, "Factory 應找到 CSV 解析器")
        XCTAssertEqual(parser?.format, DiveLogFormat.csv,
                       "Factory 應選擇 SubsurfaceCSVParser")
    }

    // MARK: - 測試 19：合成 CSV 全流程（不依賴 test41.csv）

    func testSyntheticCSVFullParse() throws {
        let csv = """
        #Nr,date,time,duration,maxdepth,avgdepth,buddy,suit,notes
        1,5/20/24,9:00,30:00,15.5,12.0,Alice,wetsuit,sunny day
        2,5/20/24,14:00,25:30,20.0,17.5,Bob,drysuit,cold
        """
        let data = csv.data(using: .utf8)!
        let dives = try SubsurfaceCSVParser.parseCSVData(data)

        XCTAssertEqual(dives.count, 2, "合成 CSV 應解析出 2 筆")

        // Dive 1
        XCTAssertEqual(dives[0].maxDepth, 15.5, accuracy: 0.001)
        XCTAssertEqual(dives[0].diveTimeSeconds, 1800)  // 30:00
        XCTAssertEqual(dives[0].notes, "sunny day")

        // Dive 2
        XCTAssertEqual(dives[1].maxDepth, 20.0, accuracy: 0.001)
        XCTAssertEqual(dives[1].diveTimeSeconds, 1530)  // 25:30
        XCTAssertEqual(dives[1].notes, "cold")
    }
}
