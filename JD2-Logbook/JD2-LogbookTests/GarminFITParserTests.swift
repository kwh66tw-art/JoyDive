// GarminFITParserTests.swift — JD2-LogbookTests
// Week 7：GarminDescentParser（FIT 二進位格式）單元測試
// AI-generated (Claude)
//
// 測試樣本：TestFiles/Garmin/（Garmin Descent MK1 實際錄製，UTC+2 時區）
//   - 2018-08-11-09-56-30.fit → maxDepth=27.022m, diveTime=3514s, start=2018-08-11T07:56:30Z
//   - 2018-08-11-14-11-36.fit → maxDepth=20.628m, diveTime=3929s, start=2018-08-11T12:11:36Z
//   - 2018-08-13-13-48-26.fit → maxDepth=15.230m, diveTime=4145s, start=2018-08-13T11:48:26Z
//
// FIT 欄位 mapping（純 Swift 實作）：
//   session (GMN 18) field 2  → start_time（FIT epoch seconds）
//   session (GMN 18) field 7  → total_elapsed_time（raw / 1000 = seconds）
//   dive_summary (GMN 268) field 3 → max_depth（raw mm / 1000 = metres）
//
// 測試覆蓋：
//   - canHandle：副檔名 + magic bytes 驗證
//   - 三個真實 FIT 檔案完整解析
//   - 時間戳（FIT epoch → UTC）
//   - 深度（mm → m）
//   - diveTimeSeconds（scale=1000 integer division）
//   - sourceFormat / location / gasMix / temperature
//   - 工廠自動偵測
//   - 錯誤處理（fileNotFound / corruptedData / invalidFormat / parsingFailed）

import XCTest
@testable import JoyDive_

final class GarminFITParserTests: XCTestCase {

    // MARK: - 真實 Suunto FIT 匯出（2026-07-19 使用者提供）——必須被拒絕，不能誤解析
    //
    // 發現過程：這兩個 .fit 檔案通過了 canHandle 的 magic bytes 檢查（FIT 是通用容器
    // 格式），修復前 GarminDescentParser 會「成功」解析出深度/時長（session GMN 18
    // 是通用欄位，Suunto 也有寫），但因為缺少 Garmin 專屬的 dive_gas（GMN 269）訊息，
    // gasMixJSON 靜默退回預設值 "air"——實際兩筆都是 Nitrox 30%（見
    // SuuntoJSONParserTests／SuuntoDM5XMLParserTests 對照同一批潛水的斷言）。
    // 不會拋錯、深度/時長還是對的，是最危險的一種靜默資料錯誤。
    // file_id.manufacturer 欄位證實是 "suunto"（探測用 XCTFail 訊息核實過）。

    private var suuntoFITDir: String {
        let here       = (#filePath as NSString).deletingLastPathComponent
        let moduleRoot = (here as NSString).deletingLastPathComponent
        let repoRoot   = (moduleRoot as NSString).deletingLastPathComponent
        return (repoRoot as NSString).appendingPathComponent("../_JD2-family/dive-log-samples/Suunto/FIT")
    }

    private func skipIfMissing(_ path: String) throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: path),
                          "測試檔案不存在，略過：\((path as NSString).lastPathComponent)")
    }

    func testCanHandleRejectsSuuntoFIT() throws {
        let path = (suuntoFITDir as NSString).appendingPathComponent("6a5ccfc7393493432c953691.fit")
        try skipIfMissing(path)
        let parser = GarminDescentParser()
        XCTAssertFalse(parser.canHandle(filePath: path),
                       "Suunto FIT 應被拒絕，避免 factory 選中 GarminDescentParser 誤解析")
    }

    func testParseSuuntoFITThrowsUnsupportedFormat() throws {
        let path = (suuntoFITDir as NSString).appendingPathComponent("6a5ccfc7baa3dc6d2f4fd9cf.fit")
        try skipIfMissing(path)
        let parser = GarminDescentParser()
        XCTAssertThrowsError(try parser.parse(from: path)) { error in
            guard case DiveLogImportError.unsupportedFormat(let msg) = error else {
                XCTFail("應為 unsupportedFormat，實際: \(error)")
                return
            }
            XCTAssertTrue(msg.contains("suunto"), "錯誤訊息應指出實際廠牌: \(msg)")
        }
    }

    // MARK: - 路徑輔助

    private var garminDir: String {
        let here       = (#filePath as NSString).deletingLastPathComponent   // …/JD2-LogbookTests
        let moduleRoot = (here as NSString).deletingLastPathComponent        // …/JD2-Logbook
        let repoRoot   = (moduleRoot as NSString).deletingLastPathComponent  // …/JD2-Logbook (repo)
        return (repoRoot as NSString).appendingPathComponent("../_JD2-family/dive-log-samples/Garmin")
    }

    private func garminPath(_ filename: String) -> String {
        (garminDir as NSString).appendingPathComponent(filename)
    }

    private var fit1: String { garminPath("2018-08-11-09-56-30.fit") }  // maxDepth=27.022m
    private var fit2: String { garminPath("2018-08-11-14-11-36.fit") }  // maxDepth=20.628m
    private var fit3: String { garminPath("2018-08-13-13-48-26.fit") }  // maxDepth=15.230m

    private let parser = GarminDescentParser()

    // MARK: - 期望值（Python 驗證）

    // start_time = session.field2 + FIT epoch (631065600)
    private let startUnix1: TimeInterval = 1_533_974_190  // 2018-08-11 07:56:30 UTC
    private let startUnix2: TimeInterval = 1_533_989_496  // 2018-08-11 12:11:36 UTC
    private let startUnix3: TimeInterval = 1_534_160_906  // 2018-08-13 11:48:26 UTC

    // max_depth = dive_summary.field3 / 1000
    private let maxDepth1 = 27.022
    private let maxDepth2 = 20.628
    private let maxDepth3 = 15.230

    // diveTimeSeconds = session.field7 / 1000  (integer division)
    private let diveTime1 = 3514
    private let diveTime2 = 3929
    private let diveTime3 = 4145

    // MARK: - canHandle 測試

    func testCanHandle_ValidFITFile1_ReturnsTrue() {
        XCTAssertTrue(parser.canHandle(filePath: fit1))
    }

    func testCanHandle_ValidFITFile2_ReturnsTrue() {
        XCTAssertTrue(parser.canHandle(filePath: fit2))
    }

    func testCanHandle_ValidFITFile3_ReturnsTrue() {
        XCTAssertTrue(parser.canHandle(filePath: fit3))
    }

    func testCanHandle_WrongExtension_ReturnsFalse() {
        XCTAssertFalse(parser.canHandle(filePath: "/tmp/dive.xml"))
        XCTAssertFalse(parser.canHandle(filePath: "/tmp/dive.json"))
        XCTAssertFalse(parser.canHandle(filePath: "/tmp/dive.csv"))
        XCTAssertFalse(parser.canHandle(filePath: "/tmp/dive"))
    }

    func testCanHandle_NonexistentFITPath_ReturnsFalse() {
        XCTAssertFalse(parser.canHandle(filePath: "/tmp/nonexistent_file.fit"))
    }

    func testCanHandle_InvalidMagicBytes_ReturnsFalse() throws {
        // 建立有 .fit 副檔名但 magic bytes 錯誤的暫存檔案
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fake.fit")
        var fakeData = Data(count: 14)
        fakeData[8] = 0x58   // 'X'（非 '.FIT'）
        fakeData[9] = 0x58
        fakeData[10] = 0x58
        fakeData[11] = 0x58
        try fakeData.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        XCTAssertFalse(parser.canHandle(filePath: tmpURL.path))
    }

    // MARK: - 基本解析（每個檔案回傳一筆潛水）

    func testParseFile1_ReturnsOneDive() throws {
        let dives = try parser.parse(from: fit1)
        XCTAssertEqual(dives.count, 1)
    }

    func testParseFile2_ReturnsOneDive() throws {
        let dives = try parser.parse(from: fit2)
        XCTAssertEqual(dives.count, 1)
    }

    func testParseFile3_ReturnsOneDive() throws {
        let dives = try parser.parse(from: fit3)
        XCTAssertEqual(dives.count, 1)
    }

    // MARK: - 最大深度

    func testParseFile1_MaxDepth() throws {
        let dive = try parser.parse(from: fit1).first!
        XCTAssertEqual(dive.maxDepth, maxDepth1, accuracy: 0.001, "maxDepth 應為 27.022m")
    }

    func testParseFile2_MaxDepth() throws {
        let dive = try parser.parse(from: fit2).first!
        XCTAssertEqual(dive.maxDepth, maxDepth2, accuracy: 0.001, "maxDepth 應為 20.628m")
    }

    func testParseFile3_MaxDepth() throws {
        let dive = try parser.parse(from: fit3).first!
        XCTAssertEqual(dive.maxDepth, maxDepth3, accuracy: 0.001, "maxDepth 應為 15.230m")
    }

    // MARK: - 潛水時間

    func testParseFile1_DiveTime() throws {
        let dive = try parser.parse(from: fit1).first!
        XCTAssertEqual(dive.diveTimeSeconds, diveTime1, "diveTime 應為 3514s")
    }

    func testParseFile2_DiveTime() throws {
        let dive = try parser.parse(from: fit2).first!
        XCTAssertEqual(dive.diveTimeSeconds, diveTime2, "diveTime 應為 3929s")
    }

    func testParseFile3_DiveTime() throws {
        let dive = try parser.parse(from: fit3).first!
        XCTAssertEqual(dive.diveTimeSeconds, diveTime3, "diveTime 應為 4145s")
    }

    // MARK: - 開始時間（FIT epoch → Unix → Date）

    func testParseFile1_StartTime() throws {
        let dive = try parser.parse(from: fit1).first!
        XCTAssertEqual(
            dive.dateTime.timeIntervalSince1970,
            startUnix1,
            accuracy: 1.0,
            "start 應為 2018-08-11 07:56:30 UTC"
        )
    }

    func testParseFile2_StartTime() throws {
        let dive = try parser.parse(from: fit2).first!
        XCTAssertEqual(
            dive.dateTime.timeIntervalSince1970,
            startUnix2,
            accuracy: 1.0,
            "start 應為 2018-08-11 12:11:36 UTC"
        )
    }

    func testParseFile3_StartTime() throws {
        let dive = try parser.parse(from: fit3).first!
        XCTAssertEqual(
            dive.dateTime.timeIntervalSince1970,
            startUnix3,
            accuracy: 1.0,
            "start 應為 2018-08-13 11:48:26 UTC"
        )
    }

    // MARK: - Metadata

    func testParseFile1_SourceFormat() throws {
        let dive = try parser.parse(from: fit1).first!
        XCTAssertEqual(dive.sourceFormat, "garmin")
    }

    func testParseFile1_GasMix_IsAir() throws {
        let dive = try parser.parse(from: fit1).first!
        XCTAssertEqual(dive.gasMixJSON, "\"air\"")
    }

    func testParseFile1_Location_IsEmpty() throws {
        let dive = try parser.parse(from: fit1).first!
        XCTAssertEqual(dive.location, "", "FIT 格式無地點欄位，應為空字串")
    }

    func testParseFile1_WaterTemperature_FromSession() throws {
        // Week 8 強化：從 session avg_temperature 取得水溫（HANDOFF debug 確認 29.0°C）
        let dive = try parser.parse(from: fit1).first!
        XCTAssertEqual(dive.waterTemperature, 29.0, accuracy: 0.5,
                       "應從 session avg_temperature 取得水溫（29.0°C）")
    }

    func testParseFile1_GPS_LatLonWithinValidRange() throws {
        // Week 8 強化：從 session start_position 取得 GPS 座標
        // 2018 地中海潛水，預期有有效 GPS 座標
        let dive = try parser.parse(from: fit1).first!
        if let lat = dive.latitude, let lon = dive.longitude {
            XCTAssertTrue(abs(lat) <= 90,  "緯度應在 [-90, 90] 範圍內，實際: \(lat)")
            XCTAssertTrue(abs(lon) <= 180, "經度應在 [-180, 180] 範圍內，實際: \(lon)")
            // 地中海大致範圍
            XCTAssertTrue(lat > 30 && lat < 48,  "地中海緯度預期在 30–48°N，實際: \(lat)")
            XCTAssertTrue(lon > -6 && lon < 42,  "地中海經度預期在 -6–42°E，實際: \(lon)")
        }
        // GPS 欄位可能不存在（某些 FIT 檔案無 start_position）；若為 nil 則不強制失敗
    }

    // MARK: - 三個檔案整批解析（smoke test）

    func testParseAllThreeFiles_NoThrow() {
        XCTAssertNoThrow(try parser.parse(from: fit1))
        XCTAssertNoThrow(try parser.parse(from: fit2))
        XCTAssertNoThrow(try parser.parse(from: fit3))
    }

    func testParseAllThreeFiles_DepthsDistinct() throws {
        let d1 = try parser.parse(from: fit1).first!.maxDepth
        let d2 = try parser.parse(from: fit2).first!.maxDepth
        let d3 = try parser.parse(from: fit3).first!.maxDepth
        XCTAssertGreaterThan(d1, d2, "第一次潛水比第二次深")
        XCTAssertGreaterThan(d2, d3, "第二次潛水比第三次深")
    }

    // MARK: - 錯誤處理

    func testParse_FileNotFound_ThrowsFileNotFound() {
        XCTAssertThrowsError(try parser.parse(from: "/nonexistent/path/dive.fit")) { error in
            if case DiveLogImportError.fileNotFound = error { return }
            XCTFail("應拋出 fileNotFound，實際: \(error)")
        }
    }

    func testParse_TruncatedFile_ThrowsCorruptedData() throws {
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tiny.fit")
        try Data([0x0E, 0x10, 0x00]).write(to: tmpURL)  // 只有 3 bytes
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        XCTAssertThrowsError(try parser.parse(from: tmpURL.path)) { error in
            if case DiveLogImportError.corruptedData = error { return }
            XCTFail("應拋出 corruptedData，實際: \(error)")
        }
    }

    func testParse_InvalidMagicBytes_ThrowsInvalidFormat() throws {
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bad.fit")
        var fakeData = Data(count: 20)
        fakeData[0] = 0x0E  // header size
        // offset 8-11 留 0x00（不是 ".FIT"）
        try fakeData.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        XCTAssertThrowsError(try parser.parse(from: tmpURL.path)) { error in
            if case DiveLogImportError.invalidFormat = error { return }
            XCTFail("應拋出 invalidFormat，實際: \(error)")
        }
    }

    // MARK: - 工廠自動偵測

    func testFactory_SelectsGarminParser_ForFITFile() {
        let selected = DiveLogImporterFactory.selectImporter(for: fit1)
        XCTAssertNotNil(selected, "工廠應能識別 .fit 檔案")
        XCTAssertEqual(selected?.format, DiveLogFormat.garmin)
    }

    func testDiveLogFormat_Garmin_SupportsFITExtension() {
        XCTAssertTrue(DiveLogFormat.garmin.supportedExtensions.contains("fit"))
    }

    // MARK: - validateContent

    func testValidateContent_ValidFITData_ReturnsTrue() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: fit1), options: .mappedIfSafe)
        XCTAssertTrue(parser.validateContent(data))
    }

    func testValidateContent_EmptyData_ReturnsFalse() {
        XCTAssertFalse(parser.validateContent(Data()))
    }
}
