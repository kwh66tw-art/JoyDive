// SeabearCSVParserTests.swift — JD2-LogbookTests
// Week 8：SeabearCSVParser（Seabear Diving Technology CSV 格式）單元測試
// AI-generated (Claude)
//
// 測試樣本：TestFiles/Seabear/
//   - TestDiveSeabearHUDC.csv (HUDC 硬體，2014-07-10 08:46:10Z，maxDepth=40.0m，diveTime=452s)
//
// 格式解析驗證：
//   - // 開頭 metadata 行（日期時間、氣體設定）
//   - 分號分隔資料行（Time;Depth;NDT;TTS;Ceiling;Temperature;TankPressure）
//   - 標題後跳過 2 行（單位行 + 索引行）
//   - maxDepth 從資料行計算；diveTimeSeconds 為最後一筆時間戳
//   - waterTemperature 取第一筆 Temperature 欄位值

import XCTest
@testable import JoyDive_

final class SeabearCSVParserTests: XCTestCase {

    // MARK: - 路徑輔助

    private var seabearDir: String {
        let here       = (#filePath as NSString).deletingLastPathComponent   // …/JD2-LogbookTests
        let moduleRoot = (here as NSString).deletingLastPathComponent        // …/JD2-Logbook
        let repoRoot   = (moduleRoot as NSString).deletingLastPathComponent  // …/JD2-Logbook (repo)
        return (repoRoot as NSString).appendingPathComponent("../_JD2-family/dive-log-samples/Seabear")
    }

    private func seabearPath(_ filename: String) -> String {
        (seabearDir as NSString).appendingPathComponent(filename)
    }

    private var hudcCSV: String { seabearPath("TestDiveSeabearHUDC.csv") }

    private let parser = SeabearCSVParser()

    // MARK: - 期望值（從 TestDiveSeabearHUDC.csv 手動驗證）

    // //2014.07.10 08:46:10 → UTC unix timestamp
    // 2014-07-10 08:46:10 UTC
    // 驗算：1970→2014 共 16071 天 + 190 天（至 7/10）+ 31570s（08:46:10）= 1,404,981,970
    // 原值 1_405_082_770 多出 100,800 秒（28 小時），為計算錯誤
    private let expectedUnixTime: TimeInterval = 1_404_981_970

    private let expectedMaxDepth:    Double = 40.0    // 資料行最大 Depth 欄位值
    private let expectedDiveTime:    Int    = 452      // 最後一筆 Time 欄位值
    private let expectedTemperature: Double = 25.0    // 第一筆 Temperature 欄位值
    // O2: 21% → Air
    private let expectedGasMixJSON: String  = "\"air\""

    // MARK: - canHandle 測試

    func testCanHandle_SeabearHUDC_ReturnsTrue() {
        XCTAssertTrue(parser.canHandle(filePath: hudcCSV),
                      "SeabearCSVParser 應能識別 TestDiveSeabearHUDC.csv")
    }

    func testCanHandle_NonCSVExtension_ReturnsFalse() {
        XCTAssertFalse(parser.canHandle(filePath: "/tmp/dive.xml"))
        XCTAssertFalse(parser.canHandle(filePath: "/tmp/dive.json"))
        XCTAssertFalse(parser.canHandle(filePath: "/tmp/dive.fit"))
        XCTAssertFalse(parser.canHandle(filePath: "/tmp/dive.uddf"))
    }

    func testCanHandle_NonexistentCSV_ReturnsFalse() {
        XCTAssertFalse(parser.canHandle(filePath: "/tmp/no_such_file.csv"))
    }

    func testCanHandle_SubsurfaceCSV_ReturnsFalse() throws {
        // Subsurface CSV 不含 "SEABEAR"，應回傳 false
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("subsurface_test.csv")
        let subsurfaceHeader = "Dive #,Date,Time,Duration,Max Depth\n1,01/01/2024,10:00,30:00,20.0"
        try subsurfaceHeader.write(to: tmpURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        XCTAssertFalse(parser.canHandle(filePath: tmpURL.path),
                       "非 Seabear CSV 不應被識別")
    }

    // MARK: - 解析基本結果

    func testParse_DiveCount_IsOne() throws {
        let dives = try parser.parse(from: hudcCSV)
        XCTAssertEqual(dives.count, 1, "應解析出 1 筆潛水記錄")
    }

    func testParse_MaxDepth() throws {
        let dive = try parser.parse(from: hudcCSV).first!
        XCTAssertEqual(dive.maxDepth, expectedMaxDepth, accuracy: 0.01,
                       "maxDepth 應為 40.0m")
    }

    func testParse_DiveTimeSeconds() throws {
        let dive = try parser.parse(from: hudcCSV).first!
        XCTAssertEqual(dive.diveTimeSeconds, expectedDiveTime,
                       "diveTimeSeconds 應為 452s（最後一筆 Time 值）")
    }

    func testParse_WaterTemperature() throws {
        let dive = try parser.parse(from: hudcCSV).first!
        XCTAssertEqual(dive.waterTemperature, expectedTemperature, accuracy: 0.1,
                       "waterTemperature 應為 25.0°C（第一筆資料行溫度）")
    }

    func testParse_DateTime() throws {
        let dive = try parser.parse(from: hudcCSV).first!
        XCTAssertEqual(dive.dateTime.timeIntervalSince1970, expectedUnixTime,
                       accuracy: 1.0,
                       "日期時間應解析為 2014-07-10 08:46:10 UTC")
    }

    func testParse_GasMixJSON_IsAir() throws {
        let dive = try parser.parse(from: hudcCSV).first!
        XCTAssertEqual(dive.gasMixJSON, expectedGasMixJSON,
                       "O2=21% 應解析為 Air")
    }

    func testParse_Location_IsEmpty() throws {
        let dive = try parser.parse(from: hudcCSV).first!
        XCTAssertEqual(dive.location, "",
                       "Seabear CSV 無地點欄位，應為空字串")
    }

    func testParse_SourceFormat() throws {
        let dive = try parser.parse(from: hudcCSV).first!
        XCTAssertEqual(dive.sourceFormat, "seabear")
    }

    // MARK: - Nitrox 氣體解析（合成測試資料）

    func testParse_Nitrox32_ParsedCorrectly() throws {
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("seabear_nitrox.csv")
        let nitroxContent = """
        //SEABEAR DIVING TECHNOLOGY
        //DIVE NR: 1
        //2023.06.15 09:00:00
        //Setting: 0 GF: 30/80 O2: 32%

        Time;Depth;NDT;TTS;Ceiling;Temperature;Tank pressure
        1;1;1;1;1;1;1
        0;1;2;3;4;5;6

        30;5.0;200;0;0;28;180
        60;10.0;100;0;0;27;170
        90;5.0;200;0;0;27;160
        120;0.0;200;0;0;27;150
        """
        try nitroxContent.write(to: tmpURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let dives = try parser.parse(from: tmpURL.path)
        XCTAssertEqual(dives.count, 1)
        let dive = dives.first!
        XCTAssertTrue(dive.gasMixJSON.contains("nitrox"),
                      "O2=32% 應解析為 nitrox: \(dive.gasMixJSON)")
        XCTAssertTrue(dive.gasMixJSON.contains("0.32"),
                      "nitrox fO2 應為 0.32: \(dive.gasMixJSON)")
    }

    // MARK: - 錯誤處理

    func testParse_FileNotFound_ThrowsFileNotFound() {
        XCTAssertThrowsError(try parser.parse(from: "/nonexistent/path/dive.csv")) { error in
            if case DiveLogImportError.fileNotFound = error { return }
            XCTFail("應拋出 fileNotFound，實際: \(error)")
        }
    }

    func testParse_EmptyFile_ThrowsEmptyFile() throws {
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("empty_seabear.csv")
        try "".write(to: tmpURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        XCTAssertThrowsError(try parser.parse(from: tmpURL.path)) { error in
            if case DiveLogImportError.emptyFile = error { return }
            XCTFail("應拋出 emptyFile，實際: \(error)")
        }
    }

    func testParse_NonSeabearCSV_ThrowsInvalidFormat() throws {
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("fake_seabear.csv")
        try "Dive #,Date\n1,2024-01-01".write(to: tmpURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        XCTAssertThrowsError(try parser.parse(from: tmpURL.path)) { error in
            if case DiveLogImportError.invalidFormat = error { return }
            XCTFail("應拋出 invalidFormat，實際: \(error)")
        }
    }

    func testParse_MissingDateTime_ThrowsParsingFailed() throws {
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("no_datetime_seabear.csv")
        // 含 SEABEAR 標識但無日期時間行
        let content = """
        //SEABEAR DIVING TECHNOLOGY
        //DIVE NR: 1

        Time;Depth;NDT;TTS;Ceiling;Temperature;Tank pressure
        1;1;1;1;1;1;1
        0;1;2;3;4;5;6

        30;5.0;200;0;0;28;180
        """
        try content.write(to: tmpURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        XCTAssertThrowsError(try parser.parse(from: tmpURL.path)) { error in
            if case DiveLogImportError.parsingFailed = error { return }
            XCTFail("應拋出 parsingFailed，實際: \(error)")
        }
    }

    // MARK: - 工廠自動偵測

    func testFactory_SelectsSeabearParser_ForSeabearCSV() {
        let selected = DiveLogImporterFactory.selectImporter(for: hudcCSV)
        XCTAssertNotNil(selected, "工廠應能識別 Seabear CSV 檔案")
        XCTAssertEqual(selected?.format, DiveLogFormat.seabear,
                       "應選擇 SeabearCSVParser 而非 SubsurfaceCSVParser")
    }

    func testDiveLogFormat_Seabear_SupportCSVExtension() {
        XCTAssertTrue(DiveLogFormat.seabear.supportedExtensions.contains("csv"))
    }
}
