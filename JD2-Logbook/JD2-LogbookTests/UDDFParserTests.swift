// UDDFParserTests.swift — JD2-LogbookTests/UDDFParserTests.swift
// Week 3 Day 1 — UDDF 解析器單元測試
//
// 測試架構：XCTest
// 覆蓋範圍：
//   1. 格式偵測（canHandle、validateContent）
//   2. 合成 XML 解析（基本、多潛水、邊界值）
//   3. 實際檔案解析（test42.uddf、test-apd-inspiration.uddf）
//   4. 錯誤處理（檔案不存在、無效 XML、空內容）
//
// 預期值說明：
//   test42.uddf:
//     - 日期：2014-04-02T10:00:00Z（UTC）
//     - 地點：Lake Coleridge，GPS: -43.342295 / 171.545936
//     - 深度：38.99m，時間：4674s
//     - 溫度：277.45K min waypoint = 4.30°C（紐西蘭高山湖）
//     - 氣體：TMx 16/45 → {"trimix":{"fO2":0.16,"fHe":0.45}}
//
//   test-apd-inspiration.uddf：
//     - 2 個 <dive>，previous_dive 無有效資料 → 跳過 → 共 1 筆
//     - 日期：2022-04-24T10:30:58Z
//     - 地點：Northern Arch，GPS: -35.4485 / 174.732
//     - 深度：60.4m，時間：6240s
//     - 溫度：lowesttemperature 292.6K = 19.45°C（CCR APD Inspiration）
//     - 氣體：switchmix diluent_04 = 16/48 → {"trimix":{"fO2":0.16,"fHe":0.48}}

import XCTest
import Foundation
@testable import JoyDive_

final class UDDFParserTests: XCTestCase {

    // MARK: - 測試輔助

    private var parser: UDDFParser!

    /// 測試檔案目錄：JD2-Logbook/TestFiles/UDDF/
    private var testFilesDir: URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // JD2-LogbookTests/
            .deletingLastPathComponent()   // JD2-Logbook/
            .deletingLastPathComponent()   // JD2-Logbook/ (project root)
            .appendingPathComponent("TestFiles/UDDF")
    }

    private var test42URL: URL { testFilesDir.appendingPathComponent("test42.uddf") }
    private var testAPDURL: URL { testFilesDir.appendingPathComponent("test-apd-inspiration.uddf") }

    override func setUp() {
        super.setUp()
        parser = UDDFParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    // MARK: ══════════════════════════════════════════════════
    // MARK: 1. 格式偵測
    // MARK: ══════════════════════════════════════════════════

    func testCanHandleUDDFExtension() {
        XCTAssertTrue(parser.canHandle(filePath: "/path/to/dive.uddf"))
        XCTAssertTrue(parser.canHandle(filePath: "test42.UDDF"))    // 大寫
        XCTAssertFalse(parser.canHandle(filePath: "dive.xml"))
        XCTAssertFalse(parser.canHandle(filePath: "dive.zip"))
        XCTAssertFalse(parser.canHandle(filePath: "dive.fit"))
    }

    func testValidateContentXML() {
        let xml = "<?xml version=\"1.0\"?><uddf></uddf>"
        let data = xml.data(using: .utf8)!
        XCTAssertTrue(parser.validateContent(data))
    }

    func testValidateContentUDDFRootTag() {
        let xml = "<uddf version=\"3.2.0\"></uddf>"
        let data = xml.data(using: .utf8)!
        XCTAssertTrue(parser.validateContent(data))
    }

    func testValidateContentZIPMagicBytes() {
        // ZIP 魔術位元組 PK\x03\x04
        let bytes: [UInt8] = [0x50, 0x4B, 0x03, 0x04, 0x00, 0x00]
        let data = Data(bytes)
        XCTAssertTrue(parser.validateContent(data))
    }

    func testValidateContentEmpty() {
        XCTAssertFalse(parser.validateContent(Data()))
    }

    func testValidateContentInvalidData() {
        let data = "This is not UDDF".data(using: .utf8)!
        XCTAssertFalse(parser.validateContent(data))
    }

    // MARK: ══════════════════════════════════════════════════
    // MARK: 2. 合成 XML 解析（基本功能）
    // MARK: ══════════════════════════════════════════════════

    func testParseSyntheticSingleDive() throws {
        let xml = makeSyntheticUDDF(dives: [
            SyntheticDive(
                diveId:       "dive1",
                siteId:       "site1",
                siteName:     "Kenting, Taiwan",
                lat:          "21.9500",
                lon:          "120.7500",
                datetime:     "2023-06-15T14:30:00",
                diveNumber:   "42",
                duration:     "2730",         // 45m30s
                maxDepth:     "25.5",
                lowestTemp:   "301.15",       // 28°C in Kelvin
                gasMixId:     "mix1",
                gasMixName:   "EANx32",
                gasO2:        "0.32",
                gasHe:        "0.0"
            )
        ])

        let data = xml.data(using: .utf8)!
        let logs = try UDDFParser.parseXMLData(data)

        XCTAssertEqual(logs.count, 1, "應解析出 1 筆潛水記錄")

        let log = logs[0]
        XCTAssertEqual(log.location, "Kenting, Taiwan")
        XCTAssertEqual(log.maxDepth, 25.5, accuracy: 0.001)
        XCTAssertEqual(log.diveTimeSeconds, 2730)
        XCTAssertEqual(log.waterTemperature, 28.0, accuracy: 0.01)
        XCTAssertEqual(log.sourceFormat, "UDDF")
        XCTAssertEqual(log.latitude!,  21.95,   accuracy: 0.0001)
        XCTAssertEqual(log.longitude!, 120.75,  accuracy: 0.0001)
        // Nitrox 32%
        XCTAssertTrue(log.gasMixJSON.contains("nitrox"), "應識別為 Nitrox")
        XCTAssertTrue(log.gasMixJSON.contains("0.32"),   "fO2 應為 0.32")
    }

    func testParseSyntheticAirDive() throws {
        let xml = makeSyntheticUDDF(dives: [
            SyntheticDive(
                diveId:     "d1",
                siteId:     "s1",
                siteName:   "Green Island",
                lat:        "33.0",
                lon:        "121.5",
                datetime:   "2023-06-15T09:00:00",
                diveNumber: "1",
                duration:   "1800",
                maxDepth:   "18.0",
                lowestTemp: "300.15",   // ~27°C
                gasMixId:   "air_mix",
                gasMixName: "air",
                gasO2:      "0.21",
                gasHe:      "0.0"
            )
        ])

        let data = xml.data(using: .utf8)!
        let logs = try UDDFParser.parseXMLData(data)

        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].gasMixJSON, "\"air\"", "21% O2 應識別為 Air")
    }

    func testParseSyntheticTrimixDive() throws {
        let xml = makeSyntheticUDDF(dives: [
            SyntheticDive(
                diveId:     "d1",
                siteId:     "s1",
                siteName:   "Deep Site",
                lat:        "0.0",
                lon:        "0.0",
                datetime:   "2023-01-01T08:00:00",
                diveNumber: "99",
                duration:   "3600",
                maxDepth:   "80.0",
                lowestTemp: "280.15",
                gasMixId:   "tmx_18_45",
                gasMixName: "TMx 18/45",
                gasO2:      "0.18",
                gasHe:      "0.45"
            )
        ])

        let data = xml.data(using: .utf8)!
        let logs = try UDDFParser.parseXMLData(data)

        XCTAssertEqual(logs.count, 1)
        XCTAssertTrue(logs[0].gasMixJSON.contains("trimix"), "應識別為 Trimix")
        XCTAssertTrue(logs[0].gasMixJSON.contains("0.18"),   "fO2 應為 0.18")
        XCTAssertTrue(logs[0].gasMixJSON.contains("0.45"),   "fHe 應為 0.45")
    }

    func testParseSyntheticMultipleDives() throws {
        let xml = makeSyntheticUDDF(dives: [
            SyntheticDive(diveId: "d1", siteId: "s1", siteName: "Site A",
                          lat: "25.0", lon: "121.0",
                          datetime: "2023-06-15T09:00:00", diveNumber: "40",
                          duration: "3000", maxDepth: "18.5",
                          lowestTemp: "300.15",
                          gasMixId: "air", gasMixName: "air", gasO2: "0.21", gasHe: "0.0"),
            SyntheticDive(diveId: "d2", siteId: "s1", siteName: "Site A",
                          lat: "25.0", lon: "121.0",
                          datetime: "2023-06-15T14:30:00", diveNumber: "41",
                          duration: "2730", maxDepth: "25.5",
                          lowestTemp: "297.15",
                          gasMixId: "air", gasMixName: "air", gasO2: "0.21", gasHe: "0.0")
        ])

        let data = xml.data(using: .utf8)!
        let logs = try UDDFParser.parseXMLData(data)

        XCTAssertEqual(logs.count, 2, "應解析出 2 筆記錄")
        // 按解析順序排列
        XCTAssertEqual(logs[0].maxDepth, 18.5, accuracy: 0.001)
        XCTAssertEqual(logs[1].maxDepth, 25.5, accuracy: 0.001)
        XCTAssertEqual(logs[0].diveTimeSeconds, 3000)
        XCTAssertEqual(logs[1].diveTimeSeconds, 2730)
    }

    // MARK: ══════════════════════════════════════════════════
    // MARK: 3. 邊界值
    // MARK: ══════════════════════════════════════════════════

    func testParseMissingLocation_UsesUnknown() throws {
        // 有 <dive> 但 <site> 無 <name>，且 informationbeforedive 無 link ref
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <uddf version="3.2.0">
          <gasdefinitions>
            <mix id="air"><o2>0.21</o2><he>0.0</he></mix>
          </gasdefinitions>
          <profiledata>
            <repetitiongroup id="rg1">
              <dive id="d1">
                <informationbeforedive>
                  <divenumber>1</divenumber>
                  <datetime>2023-01-01T10:00:00</datetime>
                </informationbeforedive>
                <tankdata><link ref="air"/></tankdata>
                <informationafterdive>
                  <greatestdepth>20.0</greatestdepth>
                  <diveduration>1800</diveduration>
                  <lowesttemperature>293.15</lowesttemperature>
                </informationafterdive>
              </dive>
            </repetitiongroup>
          </profiledata>
        </uddf>
        """
        let logs = try UDDFParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].location, "")  // importer 輸出空字串，View 層負責顯示本地化「未知地點」
    }

    func testParseSingleSiteNoLinkRef_UsesOnlySite() throws {
        // 有一個 site 但 informationbeforedive 無 link ref → 自動使用唯一的 site
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <uddf version="3.2.0">
          <divesite>
            <site id="only_site">
              <name>Auto Site</name>
              <geography><latitude>10.0</latitude><longitude>110.0</longitude></geography>
            </site>
          </divesite>
          <gasdefinitions>
            <mix id="air"><o2>0.21</o2><he>0.0</he></mix>
          </gasdefinitions>
          <profiledata>
            <repetitiongroup id="rg1">
              <dive id="d1">
                <informationbeforedive>
                  <datetime>2023-01-01T10:00:00</datetime>
                </informationbeforedive>
                <tankdata><link ref="air"/></tankdata>
                <informationafterdive>
                  <greatestdepth>15.0</greatestdepth>
                  <diveduration>1200</diveduration>
                </informationafterdive>
              </dive>
            </repetitiongroup>
          </profiledata>
        </uddf>
        """
        let logs = try UDDFParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].location, "Auto Site")
        XCTAssertEqual(logs[0].latitude!,  10.0,  accuracy: 0.0001)
        XCTAssertEqual(logs[0].longitude!, 110.0, accuracy: 0.0001)
    }

    func testParseMissingTemperature_UsesDefault() throws {
        // 無 lowesttemperature、無 airtemperature、無 waypoint temperature → 預設 20°C
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <uddf version="3.2.0">
          <gasdefinitions><mix id="air"><o2>0.21</o2><he>0.0</he></mix></gasdefinitions>
          <profiledata>
            <repetitiongroup id="rg1">
              <dive id="d1">
                <informationbeforedive>
                  <datetime>2023-01-01T10:00:00</datetime>
                </informationbeforedive>
                <informationafterdive>
                  <greatestdepth>12.0</greatestdepth>
                  <diveduration>900</diveduration>
                </informationafterdive>
              </dive>
            </repetitiongroup>
          </profiledata>
        </uddf>
        """
        let logs = try UDDFParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].waterTemperature, 20.0, accuracy: 0.001)
    }

    func testParseAirTemperatureAsWaterTempFallback() throws {
        // 無 lowesttemperature 但有 airtemperature → 用 airtemperature 作為後備
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <uddf version="3.2.0">
          <gasdefinitions><mix id="air"><o2>0.21</o2><he>0.0</he></mix></gasdefinitions>
          <profiledata>
            <repetitiongroup id="rg1">
              <dive id="d1">
                <informationbeforedive>
                  <datetime>2023-01-01T10:00:00</datetime>
                  <airtemperature>295.15</airtemperature>
                </informationbeforedive>
                <informationafterdive>
                  <greatestdepth>10.0</greatestdepth>
                  <diveduration>600</diveduration>
                </informationafterdive>
              </dive>
            </repetitiongroup>
          </profiledata>
        </uddf>
        """
        let logs = try UDDFParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(logs.count, 1)
        // 295.15K = 22.0°C
        XCTAssertEqual(logs[0].waterTemperature, 22.0, accuracy: 0.01)
    }

    func testParseSkipsIncompleteDive_NoDateTime() throws {
        // previous_dive 模式：有 <dive> 但無有效 datetime/depth/duration
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <uddf version="3.2.0">
          <profiledata>
            <repetitiongroup id="rg1">
              <dive id="prev">
                <informationbeforedive>
                  <surfaceintervalbeforedive><passedtime>PT1H</passedtime></surfaceintervalbeforedive>
                </informationbeforedive>
              </dive>
              <dive id="real">
                <informationbeforedive>
                  <datetime>2023-01-01T10:00:00</datetime>
                </informationbeforedive>
                <informationafterdive>
                  <greatestdepth>25.0</greatestdepth>
                  <diveduration>1800</diveduration>
                </informationafterdive>
              </dive>
            </repetitiongroup>
          </profiledata>
        </uddf>
        """
        let logs = try UDDFParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(logs.count, 1, "無效的 previous_dive 應被跳過")
        XCTAssertEqual(logs[0].maxDepth, 25.0, accuracy: 0.001)
    }

    func testParseUDDFWithNamespace() throws {
        // UDDF 3.2 帶命名空間（如 test42.uddf）
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.0">
          <divesite>
            <site id="ns_site">
              <name>Namespace Site</name>
              <geography><latitude>35.0</latitude><longitude>139.0</longitude></geography>
            </site>
          </divesite>
          <gasdefinitions>
            <mix id="air"><name>air</name><o2>0.21</o2><he>0.00</he></mix>
          </gasdefinitions>
          <profiledata>
            <repetitiongroup id="rg1">
              <dive id="d1">
                <informationbeforedive>
                  <link ref="ns_site"/>
                  <datetime>2023-06-01T08:00:00</datetime>
                </informationbeforedive>
                <tankdata><link ref="air"/></tankdata>
                <informationafterdive>
                  <greatestdepth>30.0</greatestdepth>
                  <diveduration>2700</diveduration>
                  <lowesttemperature>295.15</lowesttemperature>
                </informationafterdive>
              </dive>
            </repetitiongroup>
          </profiledata>
        </uddf>
        """
        let logs = try UDDFParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(logs.count, 1, "命名空間不應影響解析")
        XCTAssertEqual(logs[0].location, "Namespace Site")
        XCTAssertEqual(logs[0].maxDepth, 30.0, accuracy: 0.001)
        // 295.15K = 22.0°C
        XCTAssertEqual(logs[0].waterTemperature, 22.0, accuracy: 0.01)
    }

    func testParseTemperatureKelvinConversion() throws {
        // 驗證 Kelvin → Celsius 轉換：0°C = 273.15K
        let xml = makeSyntheticUDDF(dives: [
            SyntheticDive(
                diveId: "d1", siteId: "s1", siteName: "Cold Site",
                lat: "0.0", lon: "0.0",
                datetime: "2023-01-01T10:00:00", diveNumber: "1",
                duration: "1800", maxDepth: "10.0",
                lowestTemp: "273.15",     // 0°C
                gasMixId: "air", gasMixName: "air", gasO2: "0.21", gasHe: "0.0"
            )
        ])
        let logs = try UDDFParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(logs[0].waterTemperature, 0.0, accuracy: 0.01)
    }

    func testParseNotesFromPara() throws {
        let xml = makeSyntheticUDDF(dives: [
            SyntheticDive(
                diveId: "d1", siteId: "s1", siteName: "Note Site",
                lat: "0.0", lon: "0.0",
                datetime: "2023-01-01T10:00:00", diveNumber: "1",
                duration: "1800", maxDepth: "10.0",
                lowestTemp: "293.15",
                gasMixId: "air", gasMixName: "air", gasO2: "0.21", gasHe: "0.0",
                notes: "Saw a manta ray"
            )
        ])
        let logs = try UDDFParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].notes, "Saw a manta ray")
    }

    // MARK: ══════════════════════════════════════════════════
    // MARK: 4. 實際檔案驗證
    // MARK: ══════════════════════════════════════════════════

    func testParseTest42_RealFile() throws {
        guard FileManager.default.fileExists(atPath: test42URL.path) else {
            XCTFail("測試檔案不存在: \(test42URL.path)")
            return
        }

        let logs = try parser.parse(from: test42URL.path)

        // ── 基本結構 ──
        XCTAssertEqual(logs.count, 1, "test42.uddf 應有 1 筆潛水記錄")

        guard let log = logs.first else { return }

        // ── 地點 ──
        XCTAssertEqual(log.location, "Lake Coleridge", "地點應為 Lake Coleridge")
        XCTAssertNotNil(log.latitude)
        XCTAssertNotNil(log.longitude)
        XCTAssertEqual(log.latitude!,   -43.342295, accuracy: 0.0001)
        XCTAssertEqual(log.longitude!,  171.545936, accuracy: 0.0001)

        // ── 日期 ──（UDDF 無時區 → 解析為 UTC）
        let calendar = Calendar(identifier: .gregorian)
        let utcTZ    = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents(in: utcTZ, from: log.dateTime)
        XCTAssertEqual(components.year,   2014)
        XCTAssertEqual(components.month,  4)
        XCTAssertEqual(components.day,    2)
        XCTAssertEqual(components.hour,   10)
        XCTAssertEqual(components.minute, 0)

        // ── 潛水參數 ──
        XCTAssertEqual(log.maxDepth, 38.99, accuracy: 0.01,
                       "最大深度應為 38.99m（在 40m 警告線以下，但仍有效）")
        XCTAssertEqual(log.diveTimeSeconds, 4674,
                       "潛水時間應為 4674 秒")

        // ── 水溫（Kelvin 轉換驗證）──
        // 最低取樣點溫度：277.45K = 4.30°C（紐西蘭高山湖）
        XCTAssertEqual(log.waterTemperature, 4.30, accuracy: 0.05,
                       "水溫應約 4.3°C（277.45K 轉換）")

        // ── 氣體（TMx 16/45）──
        XCTAssertTrue(log.gasMixJSON.contains("trimix"),
                      "氣體應識別為 Trimix (TMx 16/45)")
        XCTAssertTrue(log.gasMixJSON.contains("0.16"), "fO2 應為 0.16")
        XCTAssertTrue(log.gasMixJSON.contains("0.45"), "fHe 應為 0.45")

        // ── 來源格式 ──
        XCTAssertEqual(log.sourceFormat, "UDDF")

        // ── 備註（包含 CCR dive）──
        XCTAssertTrue(log.notes.contains("CCR"),
                      "備註應包含 'CCR' 關鍵字")
    }

    func testParseTestAPDInspiration_RealFile() throws {
        guard FileManager.default.fileExists(atPath: testAPDURL.path) else {
            XCTFail("測試檔案不存在: \(testAPDURL.path)")
            return
        }

        let logs = try parser.parse(from: testAPDURL.path)

        // ── 基本結構 ──
        // 檔案有 2 個 <dive>：previous_dive（無有效資料）+ dive（有效）
        XCTAssertEqual(logs.count, 1,
                       "previous_dive 無有效資料，應跳過，僅保留 1 筆")

        guard let log = logs.first else { return }

        // ── 地點 ──
        XCTAssertEqual(log.location, "Northern Arch",
                       "地點應為 Northern Arch（site1 的 name）")
        XCTAssertNotNil(log.latitude)
        XCTAssertNotNil(log.longitude)
        XCTAssertEqual(log.latitude!,  -35.4485, accuracy: 0.001)
        XCTAssertEqual(log.longitude!, 174.732,  accuracy: 0.001)

        // ── 日期 ──
        let utcTZ = TimeZone(secondsFromGMT: 0)!
        let components = Calendar(identifier: .gregorian).dateComponents(in: utcTZ, from: log.dateTime)
        XCTAssertEqual(components.year,   2022)
        XCTAssertEqual(components.month,  4)
        XCTAssertEqual(components.day,    24)
        XCTAssertEqual(components.hour,   10)
        XCTAssertEqual(components.minute, 30)

        // ── 潛水參數 ──
        XCTAssertEqual(log.maxDepth, 60.4, accuracy: 0.01,
                       "最大深度應為 60.4m（技術潛水，超過 40m 警告線但允許）")
        XCTAssertEqual(log.diveTimeSeconds, 6240,
                       "潛水時間應為 6240 秒（104 分鐘）")

        // ── 水溫 ──
        // lowesttemperature = 292.6K = 19.45°C（APD Inspiration 電腦報告值）
        XCTAssertEqual(log.waterTemperature, 19.45, accuracy: 0.05)

        // ── 氣體（CCR diluent_04 = 16/48 Trimix）──
        XCTAssertTrue(log.gasMixJSON.contains("trimix"),
                      "氣體應識別為 Trimix（CCR 稀釋氣 diluent_04）")
        XCTAssertTrue(log.gasMixJSON.contains("0.16"), "fO2 應為 0.16")
        XCTAssertTrue(log.gasMixJSON.contains("0.48"), "fHe 應為 0.48")

        // ── 來源格式 ──
        XCTAssertEqual(log.sourceFormat, "UDDF")
    }

    // MARK: ══════════════════════════════════════════════════
    // MARK: 5. 錯誤處理
    // MARK: ══════════════════════════════════════════════════

    func testParseFileNotFound_ThrowsError() {
        let fakePath = "/nonexistent/path/fake.uddf"
        XCTAssertThrowsError(try parser.parse(from: fakePath)) { error in
            guard let importErr = error as? DiveLogImportError else {
                XCTFail("應拋出 DiveLogImportError，實際: \(error)"); return
            }
            if case .fileNotFound = importErr {
                // ✓
            } else {
                XCTFail("應為 .fileNotFound，實際: \(importErr)")
            }
        }
    }

    func testParseInvalidXML_ThrowsError() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("invalid_\(UUID().uuidString).uddf")
        let garbage = "<<<NOT XML AT ALL>>>".data(using: .utf8)!
        try garbage.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        XCTAssertThrowsError(try parser.parse(from: tempURL.path)) { error in
            guard let importErr = error as? DiveLogImportError else {
                XCTFail("應拋出 DiveLogImportError"); return
            }
            // 無效 XML → parsingFailed 或 corruptedData
            switch importErr {
            case .parsingFailed, .corruptedData:
                break  // ✓
            default:
                XCTFail("應為 .parsingFailed 或 .corruptedData，實際: \(importErr)")
            }
        }
    }

    func testParseEmptyFile_ThrowsEmptyFileError() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("empty_\(UUID().uuidString).uddf")
        try Data().write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        XCTAssertThrowsError(try parser.parse(from: tempURL.path)) { error in
            guard let importErr = error as? DiveLogImportError else {
                XCTFail("應拋出 DiveLogImportError"); return
            }
            if case .emptyFile = importErr {
                // ✓
            } else {
                XCTFail("應為 .emptyFile，實際: \(importErr)")
            }
        }
    }

    func testParseValidXMLNoDives_ReturnsEmpty() throws {
        // 結構正確但沒有任何 <dive>
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <uddf version="3.2.0">
          <generator><name>Test</name></generator>
        </uddf>
        """
        let data = xml.data(using: .utf8)!
        let logs = try UDDFParser.parseXMLData(data)
        XCTAssertEqual(logs.count, 0, "無 <dive> 元素應回傳空陣列")
    }

    // MARK: ══════════════════════════════════════════════════
    // MARK: 6. 邊界值驗證（深度、時間）
    // MARK: ══════════════════════════════════════════════════

    func testParseDeepDive_DepthAbove40m_AllowedWithWarning() throws {
        // 60.4m 超過 40m 警告線，但解析器本身不拒絕
        let xml = makeSyntheticUDDF(dives: [
            SyntheticDive(
                diveId: "d1", siteId: "s1", siteName: "Deep Site",
                lat: "0.0", lon: "0.0",
                datetime: "2023-01-01T10:00:00", diveNumber: "1",
                duration: "3600", maxDepth: "60.4",
                lowestTemp: "293.15",
                gasMixId: "tmx", gasMixName: "TMx", gasO2: "0.16", gasHe: "0.48"
            )
        ])
        let logs = try UDDFParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(logs.count, 1, "60.4m 深度在解析層應允許（驗證由 ImportCoordinator 處理）")
        XCTAssertEqual(logs[0].maxDepth, 60.4, accuracy: 0.01)
    }

    func testParseLongDive_Within4Hours() throws {
        // 14400s = 4小時，邊界值
        let xml = makeSyntheticUDDF(dives: [
            SyntheticDive(
                diveId: "d1", siteId: "s1", siteName: "Long Dive",
                lat: "0.0", lon: "0.0",
                datetime: "2023-01-01T06:00:00", diveNumber: "1",
                duration: "14400", maxDepth: "6.0",
                lowestTemp: "296.15",
                gasMixId: "air", gasMixName: "air", gasO2: "0.21", gasHe: "0.0"
            )
        ])
        let logs = try UDDFParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].diveTimeSeconds, 14400)
    }

    func testParseZeroDuration_Skipped() throws {
        // diveduration = 0 的潛水記錄應被跳過
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <uddf version="3.2.0">
          <profiledata>
            <repetitiongroup id="rg1">
              <dive id="d1">
                <informationbeforedive>
                  <datetime>2023-01-01T10:00:00</datetime>
                </informationbeforedive>
                <informationafterdive>
                  <greatestdepth>10.0</greatestdepth>
                  <diveduration>0</diveduration>
                </informationafterdive>
              </dive>
            </repetitiongroup>
          </profiledata>
        </uddf>
        """
        let logs = try UDDFParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(logs.count, 0, "時間為 0 的記錄應被跳過")
    }

    // MARK: ══════════════════════════════════════════════════
    // MARK: 輔助方法：合成 UDDF XML 生成
    // MARK: ══════════════════════════════════════════════════

    private struct SyntheticDive {
        let diveId:     String
        let siteId:     String
        let siteName:   String
        let lat:        String
        let lon:        String
        let datetime:   String
        let diveNumber: String
        let duration:   String
        let maxDepth:   String
        let lowestTemp: String
        let gasMixId:   String
        let gasMixName: String
        let gasO2:      String
        let gasHe:      String
        var notes:      String? = nil
    }

    /// 生成包含多次潛水的合成 UDDF XML（每個潛水使用相同的 siteId 和 gasMixId 定義）
    private func makeSyntheticUDDF(dives: [SyntheticDive]) -> String {
        // 收集唯一的 site 和 gas mix 定義
        var siteDefsSet = [String: SyntheticDive]()
        var gasDefsSet  = [String: SyntheticDive]()
        for d in dives {
            siteDefsSet[d.siteId]   = d
            gasDefsSet[d.gasMixId]  = d
        }

        var siteDefs = ""
        for (_, d) in siteDefsSet {
            siteDefs += """
            <site id="\(d.siteId)">
              <name>\(d.siteName)</name>
              <geography>
                <latitude>\(d.lat)</latitude>
                <longitude>\(d.lon)</longitude>
              </geography>
            </site>
            """
        }

        var gasDefs = ""
        for (id, d) in gasDefsSet {
            gasDefs += """
            <mix id="\(id)">
              <name>\(d.gasMixName)</name>
              <o2>\(d.gasO2)</o2>
              <he>\(d.gasHe)</he>
            </mix>
            """
        }

        var diveElements = ""
        for d in dives {
            let notesXML = d.notes.map { "<notes><para>\($0)</para></notes>" } ?? ""
            diveElements += """
            <dive id="\(d.diveId)">
              <informationbeforedive>
                <link ref="\(d.siteId)"/>
                <divenumber>\(d.diveNumber)</divenumber>
                <datetime>\(d.datetime)</datetime>
              </informationbeforedive>
              <tankdata><link ref="\(d.gasMixId)"/></tankdata>
              <informationafterdive>
                <greatestdepth>\(d.maxDepth)</greatestdepth>
                <diveduration>\(d.duration)</diveduration>
                <lowesttemperature>\(d.lowestTemp)</lowesttemperature>
                \(notesXML)
              </informationafterdive>
            </dive>
            """
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <uddf version="3.2.0">
          <divesite>\(siteDefs)</divesite>
          <gasdefinitions>\(gasDefs)</gasdefinitions>
          <profiledata>
            <repetitiongroup id="rg1">
              \(diveElements)
            </repetitiongroup>
          </profiledata>
        </uddf>
        """
    }
}
