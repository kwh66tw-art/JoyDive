// SubsurfaceXMLParserTests.swift — JD2-LogbookTests
// Week 4: Subsurface XML 解析器測試
//
// 測試覆蓋：
//   1. 格式偵測（canHandle / validateContent）
//   2. 合成 XML 解析（單筆、Nitrox、多筆、地點、溫度優先順序）
//   3. 真實檔案驗證（三個 Suunto 測試檔）
//   4. 錯誤處理（檔案不存在、無效 XML、空檔、無潛水）
//   5. 邊界值（深度、時間格式、氣體判斷）
//
// 測試檔位置：JD2-Logbook/TestFiles/Subsurface/
//   → 因測試檔實際存放於 TestFiles/Suunto/，路徑設定指向該目錄

import XCTest
import Foundation
@testable import JoyDive_

final class SubsurfaceXMLParserTests: XCTestCase {

    // MARK: - 測試輔助

    private var parser: SubsurfaceXMLParser!

    /// 測試檔目錄：JD2-Logbook/TestFiles/Suunto/
    private var testFilesDir: URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // JD2-LogbookTests/
            .deletingLastPathComponent()   // JD2-Logbook/
            .deletingLastPathComponent()   // project root
            .appendingPathComponent("../_JD2-family/dive-log-samples/Suunto")
    }

    private var eonCoreURL:  URL { testFilesDir.appendingPathComponent("suunto_eon_core_nitrox.xml") }
    private var nauticURL:   URL { testFilesDir.appendingPathComponent("suunto_nautic_sidemount.xml") }
    private var oceanURL:    URL { testFilesDir.appendingPathComponent("suunto_ocean_air.xml") }

    override func setUp() {
        super.setUp()
        parser = SubsurfaceXMLParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    // MARK: ═══════════════════════════════════════════════
    // MARK: 1. 格式偵測
    // MARK: ═══════════════════════════════════════════════

    func testCanHandleSSRFExtension() {
        XCTAssertTrue(parser.canHandle(filePath: "/path/to/log.ssrf"))
    }

    func testCanHandleXMLExtensionWithSubsurfaceContent() {
        // 真實檔案：suunto_eon_core_nitrox.xml 包含 program='subsurface'
        guard FileManager.default.fileExists(atPath: eonCoreURL.path) else {
            XCTFail("測試檔不存在"); return
        }
        XCTAssertTrue(parser.canHandle(filePath: eonCoreURL.path))
    }

    func testCannotHandleUDDFExtension() {
        XCTAssertFalse(parser.canHandle(filePath: "/path/to/log.uddf"))
    }

    func testCannotHandleCSVExtension() {
        XCTAssertFalse(parser.canHandle(filePath: "/path/to/log.csv"))
    }

    func testValidateContentSubsurfaceSingleQuote() {
        let xml = "<divelog program='subsurface' version='3'>"
        XCTAssertTrue(parser.validateContent(xml.data(using: .utf8)!))
    }

    func testValidateContentSubsurfaceDoubleQuote() {
        let xml = "<divelog program=\"subsurface\" version=\"3\">"
        XCTAssertTrue(parser.validateContent(xml.data(using: .utf8)!))
    }

    func testValidateContentRejectsUDDF() {
        let xml = "<?xml version='1.0'?><uddf version='3.2.0'>"
        XCTAssertFalse(parser.validateContent(xml.data(using: .utf8)!))
    }

    func testValidateContentRejectsEmpty() {
        XCTAssertFalse(parser.validateContent(Data()))
    }

    // MARK: ═══════════════════════════════════════════════
    // MARK: 2. 合成 XML 解析
    // MARK: ═══════════════════════════════════════════════

    // 輔助：產生最小合法 Subsurface XML
    private func minimalXML(
        date: String = "2024-06-15",
        time: String = "09:00:00",
        duration: String = "45:00 min",
        maxDepth: String = "20.0 m",
        waterTemp: String = "25.0 C",
        o2: String? = nil,
        diveSiteId: String? = nil,
        sites: String = "",
        notes: String = ""
    ) -> String {
        let cylAttr = o2.map { " o2='\($0)'" } ?? ""
        let siteAttr = diveSiteId.map { " divesiteid='\($0)'" } ?? ""
        let notesEl = notes.isEmpty ? "" : "<notes>\(notes)</notes>"
        return """
        <divelog program='subsurface' version='3'>
        <settings></settings>
        <divesites>\(sites)</divesites>
        <dives>
        <dive date='\(date)' time='\(time)' duration='\(duration)'\(siteAttr)>
          \(notesEl)
          <cylinder\(cylAttr) />
          <divecomputer model='Test DC' deviceid='00000001'>
          <depth max='\(maxDepth)' mean='12.0 m' />
          <temperature water='\(waterTemp)' />
          </divecomputer>
        </dive>
        </dives>
        </divelog>
        """
    }

    func testParseSyntheticSingleDive() throws {
        let xml = minimalXML()
        let logs = try SubsurfaceXMLParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(logs.count, 1)
    }

    func testParseSyntheticDate() throws {
        let logs = try SubsurfaceXMLParser.parseXMLData(
            minimalXML(date: "2024-06-15", time: "09:00:00").data(using: .utf8)!)
        let cal = Calendar(identifier: .gregorian)
        let utc = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents(in: utc, from: logs[0].dateTime)
        XCTAssertEqual(comps.year,   2024)
        XCTAssertEqual(comps.month,  6)
        XCTAssertEqual(comps.day,    15)
        XCTAssertEqual(comps.hour,   9)
        XCTAssertEqual(comps.minute, 0)
    }

    func testParseDuration45Min() throws {
        let logs = try SubsurfaceXMLParser.parseXMLData(
            minimalXML(duration: "45:00 min").data(using: .utf8)!)
        XCTAssertEqual(logs[0].diveTimeSeconds, 45 * 60)
    }

    func testParseDurationWithSeconds() throws {
        // "66:10 min" = 66*60+10 = 3970
        let logs = try SubsurfaceXMLParser.parseXMLData(
            minimalXML(duration: "66:10 min").data(using: .utf8)!)
        XCTAssertEqual(logs[0].diveTimeSeconds, 3970)
    }

    func testParseMaxDepth() throws {
        let logs = try SubsurfaceXMLParser.parseXMLData(
            minimalXML(maxDepth: "22.65 m").data(using: .utf8)!)
        XCTAssertEqual(logs[0].maxDepth, 22.65, accuracy: 0.001)
    }

    func testParseTemperatureFromDiveComputer() throws {
        let logs = try SubsurfaceXMLParser.parseXMLData(
            minimalXML(waterTemp: "18.5 C").data(using: .utf8)!)
        XCTAssertEqual(logs[0].waterTemperature, 18.5, accuracy: 0.01)
    }

    func testParseDiveTemperaturePriorityOverComputer() throws {
        // <divetemperature> 應優先於 <divecomputer>/<temperature>
        let xml = """
        <divelog program='subsurface' version='3'>
        <settings></settings><divesites></divesites>
        <dives>
        <dive date='2025-01-01' time='10:00:00' duration='30:00 min'>
          <cylinder />
          <divetemperature water='9.15 C'/>
          <divecomputer model='Test' deviceid='abc'>
          <depth max='21.0 m' mean='10.0 m' />
          <temperature water='9.2 C' />
          </divecomputer>
        </dive>
        </dives>
        </divelog>
        """
        let logs = try SubsurfaceXMLParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(logs[0].waterTemperature, 9.15, accuracy: 0.01,
                       "divetemperature 應優先於 computer temperature")
    }

    func testParseAirGas_NoCylinder() throws {
        // 無 cylinder 元素 → 預設 Air
        let xml = """
        <divelog program='subsurface' version='3'>
        <settings></settings><divesites></divesites>
        <dives>
        <dive date='2025-01-01' time='10:00:00' duration='30:00 min'>
          <divecomputer model='Test' deviceid='abc'>
          <depth max='18.0 m' mean='9.0 m' />
          <temperature water='25.0 C' />
          </divecomputer>
        </dive>
        </dives>
        </divelog>
        """
        let logs = try SubsurfaceXMLParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(logs[0].gasMixJSON, "\"air\"", "無 cylinder → Air")
    }

    func testParseAirGas_CylinderWithoutO2() throws {
        // <cylinder /> 無 o2 屬性 → Air
        let logs = try SubsurfaceXMLParser.parseXMLData(
            minimalXML(o2: nil).data(using: .utf8)!)
        XCTAssertEqual(logs[0].gasMixJSON, "\"air\"")
    }

    func testParseNitrox32() throws {
        let logs = try SubsurfaceXMLParser.parseXMLData(
            minimalXML(o2: "32.0%").data(using: .utf8)!)
        XCTAssertTrue(logs[0].gasMixJSON.contains("nitrox"), "應識別為 Nitrox")
        XCTAssertTrue(logs[0].gasMixJSON.contains("0.32"),   "fO2 應為 0.32")
    }

    func testParseNitrox36() throws {
        let logs = try SubsurfaceXMLParser.parseXMLData(
            minimalXML(o2: "36.0%").data(using: .utf8)!)
        XCTAssertTrue(logs[0].gasMixJSON.contains("nitrox"))
        XCTAssertTrue(logs[0].gasMixJSON.contains("0.36"))
    }

    func testParseAir21Percent() throws {
        // o2='21.0%' 應被識別為 Air
        let logs = try SubsurfaceXMLParser.parseXMLData(
            minimalXML(o2: "21.0%").data(using: .utf8)!)
        XCTAssertEqual(logs[0].gasMixJSON, "\"air\"")
    }

    func testParseNotes() throws {
        let logs = try SubsurfaceXMLParser.parseXMLData(
            minimalXML(notes: "Saw a manta ray").data(using: .utf8)!)
        XCTAssertEqual(logs[0].notes, "Saw a manta ray")
    }

    func testParseNoNotes_DefaultEmpty() throws {
        let logs = try SubsurfaceXMLParser.parseXMLData(
            minimalXML(notes: "").data(using: .utf8)!)
        XCTAssertEqual(logs[0].notes, "")
    }

    func testParseDiveSiteWithGPS() throws {
        let sites = "<site uuid='abc123' name='Green Island' gps='22.6573 121.4965'></site>"
        let logs = try SubsurfaceXMLParser.parseXMLData(
            minimalXML(diveSiteId: "abc123", sites: sites).data(using: .utf8)!)
        XCTAssertEqual(logs[0].location, "Green Island")
        XCTAssertNotNil(logs[0].latitude)
        XCTAssertNotNil(logs[0].longitude)
        XCTAssertEqual(logs[0].latitude!,  22.6573,  accuracy: 0.0001)
        XCTAssertEqual(logs[0].longitude!, 121.4965, accuracy: 0.0001)
    }

    func testParseNoDiveSite_UsesUnknown() throws {
        // 無 divesiteid → 空字串（View 層顯示本地化「未知地點」）
        let logs = try SubsurfaceXMLParser.parseXMLData(
            minimalXML().data(using: .utf8)!)
        XCTAssertEqual(logs[0].location, "")  // importer 輸出空字串，View 層負責顯示本地化「未知地點」
        XCTAssertNil(logs[0].latitude)
        XCTAssertNil(logs[0].longitude)
    }

    func testParseSourceFormat() throws {
        let logs = try SubsurfaceXMLParser.parseXMLData(
            minimalXML().data(using: .utf8)!)
        XCTAssertEqual(logs[0].sourceFormat, "Subsurface")
    }

    func testParseMultipleDives() throws {
        let xml = """
        <divelog program='subsurface' version='3'>
        <settings></settings><divesites></divesites>
        <dives>
        <dive date='2024-01-01' time='08:00:00' duration='40:00 min'>
          <cylinder /><divecomputer model='A' deviceid='1'>
          <depth max='18.0 m' mean='9.0 m' /><temperature water='26.0 C' />
          </divecomputer>
        </dive>
        <dive date='2024-01-01' time='13:00:00' duration='50:00 min'>
          <cylinder /><divecomputer model='A' deviceid='1'>
          <depth max='24.5 m' mean='12.0 m' /><temperature water='25.5 C' />
          </divecomputer>
        </dive>
        </dives>
        </divelog>
        """
        let logs = try SubsurfaceXMLParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(logs.count, 2)
        XCTAssertEqual(logs[0].maxDepth, 18.0, accuracy: 0.01)
        XCTAssertEqual(logs[1].maxDepth, 24.5, accuracy: 0.01)
        XCTAssertEqual(logs[0].diveTimeSeconds, 2400)
        XCTAssertEqual(logs[1].diveTimeSeconds, 3000)
    }

    func testParseOnlyFirstCylinder() throws {
        // Sidemount：兩個 cylinder，第一個無 o2，第二個也無 → Air
        let xml = """
        <divelog program='subsurface' version='3'>
        <settings></settings><divesites></divesites>
        <dives>
        <dive date='2025-12-27' time='14:56:17' duration='31:00 min'>
          <cylinder />
          <cylinder />
          <divecomputer model='Suunto Nautic' deviceid='abc'>
          <depth max='21.24 m' mean='12.26 m' />
          <temperature water='9.2 C' />
          </divecomputer>
        </dive>
        </dives>
        </divelog>
        """
        let logs = try SubsurfaceXMLParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(logs[0].gasMixJSON, "\"air\"", "Sidemount 兩個空 cylinder → Air")
    }

    func testParseSkipsInvalidDive_NoDatetime() throws {
        // 無 date/time 的 dive 應被跳過
        let xml = """
        <divelog program='subsurface' version='3'>
        <settings></settings><divesites></divesites>
        <dives>
        <dive duration='30:00 min'>
          <cylinder /><divecomputer model='X' deviceid='1'>
          <depth max='20.0 m' mean='10.0 m' />
          <temperature water='25.0 C' />
          </divecomputer>
        </dive>
        </dives>
        </divelog>
        """
        let logs = try SubsurfaceXMLParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(logs.count, 0, "缺少 date/time 的 dive 應被跳過")
    }

    func testParseAllowsZeroDepthDive() throws {
        // maxDepth = 0 代表 snorkeling 或海面訓練，不應被解析器濾除
        // 與 ImportCoordinator.validateDives (maxDepth >= 0) 行為一致
        let xml = minimalXML(maxDepth: "0.0 m")
        let logs = try SubsurfaceXMLParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(logs.count, 1, "深度 0 的 dive（snorkeling）應被保留")
        XCTAssertEqual(logs.first?.maxDepth, 0.0)
    }

    func testDefaultTemperature_WhenNoneProvided() throws {
        // 無溫度資訊 → 預設 20.0°C
        let xml = """
        <divelog program='subsurface' version='3'>
        <settings></settings><divesites></divesites>
        <dives>
        <dive date='2024-01-01' time='09:00:00' duration='30:00 min'>
          <cylinder />
          <divecomputer model='X' deviceid='1'>
          <depth max='15.0 m' mean='8.0 m' />
          </divecomputer>
        </dive>
        </dives>
        </divelog>
        """
        let logs = try SubsurfaceXMLParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(logs[0].waterTemperature, 20.0, accuracy: 0.01,
                       "無溫度資訊時應預設 20.0°C")
    }

    // MARK: ═══════════════════════════════════════════════
    // MARK: 3. 真實檔案驗證
    // MARK: ═══════════════════════════════════════════════

    func testParseEonCore_NitroxRealFile() throws {
        guard FileManager.default.fileExists(atPath: eonCoreURL.path) else {
            XCTFail("測試檔不存在: \(eonCoreURL.path)"); return
        }
        let logs = try parser.parse(from: eonCoreURL.path)

        // ── 基本結構 ──
        XCTAssertEqual(logs.count, 1, "EON Core 應有 1 筆潛水")
        let log = logs[0]

        // ── 時間 ──  date='2024-10-06' time='00:33:51'
        let cal   = Calendar(identifier: .gregorian)
        let utc   = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents(in: utc, from: log.dateTime)
        XCTAssertEqual(comps.year,   2024, "年份應為 2024")
        XCTAssertEqual(comps.month,  10,   "月份應為 10")
        XCTAssertEqual(comps.day,    6,    "日期應為 6")
        XCTAssertEqual(comps.hour,   0,    "小時應為 0")
        XCTAssertEqual(comps.minute, 33,   "分鐘應為 33")

        // ── 潛水時間  duration='66:10 min' = 3970s ──
        XCTAssertEqual(log.diveTimeSeconds, 3970, "66:10 min = 3970 秒")

        // ── 深度  max='22.65 m' ──
        XCTAssertEqual(log.maxDepth, 22.65, accuracy: 0.01)

        // ── 溫度  <temperature water='29.1 C'> ──
        XCTAssertEqual(log.waterTemperature, 29.1, accuracy: 0.1)

        // ── 地點（無 divesites）──
        XCTAssertEqual(log.location, "")  // importer 輸出空字串，View 層負責顯示本地化「未知地點」
        XCTAssertNil(log.latitude)
        XCTAssertNil(log.longitude)

        // ── 氣體  cylinder o2='32.0%' → Nitrox 0.32 ──
        XCTAssertTrue(log.gasMixJSON.contains("nitrox"), "應為 Nitrox")
        XCTAssertTrue(log.gasMixJSON.contains("0.32"),   "fO2 應為 0.32")

        // ── 格式標記 ──
        XCTAssertEqual(log.sourceFormat, "Subsurface")
    }

    func testParseNautic_SidemountRealFile() throws {
        guard FileManager.default.fileExists(atPath: nauticURL.path) else {
            XCTFail("測試檔不存在: \(nauticURL.path)"); return
        }
        let logs = try parser.parse(from: nauticURL.path)

        XCTAssertEqual(logs.count, 1, "Nautic 應有 1 筆潛水")
        let log = logs[0]

        // ── 時間  date='2025-12-27' time='14:56:17' ──
        let cal   = Calendar(identifier: .gregorian)
        let utc   = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents(in: utc, from: log.dateTime)
        XCTAssertEqual(comps.year,   2025)
        XCTAssertEqual(comps.month,  12)
        XCTAssertEqual(comps.day,    27)
        XCTAssertEqual(comps.hour,   14)
        XCTAssertEqual(comps.minute, 56)

        // ── 潛水時間  duration='31:00 min' = 1860s ──
        XCTAssertEqual(log.diveTimeSeconds, 1860)

        // ── 深度  max='21.24 m' ──
        XCTAssertEqual(log.maxDepth, 21.24, accuracy: 0.01)

        // ── 溫度  <divetemperature water='9.15 C'> 優先 ──
        XCTAssertEqual(log.waterTemperature, 9.15, accuracy: 0.05)

        // ── 地點與 GPS ──
        XCTAssertEqual(log.location, "Suunto Nautic dive")
        XCTAssertNotNil(log.latitude)
        XCTAssertNotNil(log.longitude)
        XCTAssertEqual(log.latitude!,  48.332115, accuracy: 0.0001)
        XCTAssertEqual(log.longitude!,  7.777142, accuracy: 0.0001)

        // ── 氣體  cylinder 無 o2 → Air ──
        XCTAssertEqual(log.gasMixJSON, "\"air\"", "Sidemount 無 o2 → Air")

        // ── 備註 ──
        XCTAssertEqual(log.notes, "This is a test note for Suunto Nautic")
    }

    func testParseOcean_AirRealFile() throws {
        guard FileManager.default.fileExists(atPath: oceanURL.path) else {
            XCTFail("測試檔不存在: \(oceanURL.path)"); return
        }
        let logs = try parser.parse(from: oceanURL.path)

        XCTAssertEqual(logs.count, 1, "Ocean 應有 1 筆潛水")
        let log = logs[0]

        // ── 時間  date='2026-01-13' time='06:05:31' ──
        let cal   = Calendar(identifier: .gregorian)
        let utc   = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents(in: utc, from: log.dateTime)
        XCTAssertEqual(comps.year,   2026)
        XCTAssertEqual(comps.month,  1)
        XCTAssertEqual(comps.day,    13)
        XCTAssertEqual(comps.hour,   6)
        XCTAssertEqual(comps.minute, 5)

        // ── 潛水時間  duration='50:20 min' = 3020s ──
        XCTAssertEqual(log.diveTimeSeconds, 3020)

        // ── 深度  max='23.4 m' ──
        XCTAssertEqual(log.maxDepth, 23.4, accuracy: 0.01)

        // ── 溫度  <divetemperature water='28.95 C'> 優先 ──
        XCTAssertEqual(log.waterTemperature, 28.95, accuracy: 0.05)

        // ── 地點（無 divesites）──
        XCTAssertEqual(log.location, "")  // importer 輸出空字串，View 層負責顯示本地化「未知地點」

        // ── 氣體  cylinder 無 o2 → Air ──
        XCTAssertEqual(log.gasMixJSON, "\"air\"")

        // ── 備註 ──
        XCTAssertEqual(log.notes, "This is a test note for Suunto Ocean")
    }

    // MARK: ═══════════════════════════════════════════════
    // MARK: 4. 錯誤處理
    // MARK: ═══════════════════════════════════════════════

    func testParseFileNotFound_ThrowsError() {
        XCTAssertThrowsError(try parser.parse(from: "/nonexistent/path/log.ssrf")) { error in
            guard case DiveLogImportError.fileNotFound = error else {
                XCTFail("應拋出 fileNotFound，實際得到: \(error)"); return
            }
        }
    }

    func testParseInvalidXML_ThrowsParsingFailed() {
        XCTAssertThrowsError(
            try SubsurfaceXMLParser.parseXMLData("not xml at all <<>>".data(using: .utf8)!)
        ) { error in
            guard case DiveLogImportError.parsingFailed = error else {
                XCTFail("應拋出 parsingFailed"); return
            }
        }
    }

    func testParseEmptyFile_ThrowsParsingFailed() {
        // 空 Data 傳入時，XMLParser 無法解析，拋出 parsingFailed
        // emptyFile 錯誤由 ImportCoordinator.importFile 層負責，不是 parseXMLData 層
        XCTAssertThrowsError(
            try SubsurfaceXMLParser.parseXMLData(Data())
        ) { error in
            guard case DiveLogImportError.parsingFailed = error else {
                XCTFail("應拋出 parsingFailed，實際得到 \(error)"); return
            }
        }
    }

    func testParseValidXMLNoDives_ReturnsEmpty() throws {
        let xml = "<divelog program='subsurface' version='3'><settings/><divesites/><dives/></divelog>"
        let logs = try SubsurfaceXMLParser.parseXMLData(xml.data(using: .utf8)!)
        XCTAssertEqual(logs.count, 0)
    }

    // MARK: ═══════════════════════════════════════════════
    // MARK: 5. 邊界值
    // MARK: ═══════════════════════════════════════════════

    func testParseDuration_1Minute() throws {
        let logs = try SubsurfaceXMLParser.parseXMLData(
            minimalXML(duration: "1:00 min").data(using: .utf8)!)
        XCTAssertEqual(logs[0].diveTimeSeconds, 60)
    }

    func testParseDuration_WithOddSeconds() throws {
        // "31:47 min" = 31*60+47 = 1907
        let logs = try SubsurfaceXMLParser.parseXMLData(
            minimalXML(duration: "31:47 min").data(using: .utf8)!)
        XCTAssertEqual(logs[0].diveTimeSeconds, 1907)
    }

    func testParseDeepDive_Over40m() throws {
        // 超過 40m 仍合法解析（ImportCoordinator 層才警告）
        let logs = try SubsurfaceXMLParser.parseXMLData(
            minimalXML(maxDepth: "55.3 m").data(using: .utf8)!)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].maxDepth, 55.3, accuracy: 0.01)
    }

    func testParseNitroxBoundary_21Percent() throws {
        // 21% → Air（邊界值）
        let logs = try SubsurfaceXMLParser.parseXMLData(
            minimalXML(o2: "21.0%").data(using: .utf8)!)
        XCTAssertEqual(logs[0].gasMixJSON, "\"air\"")
    }

    func testParseNitroxBoundary_22Percent() throws {
        // 22% → Nitrox（剛過邊界）
        let logs = try SubsurfaceXMLParser.parseXMLData(
            minimalXML(o2: "22.0%").data(using: .utf8)!)
        XCTAssertTrue(logs[0].gasMixJSON.contains("nitrox"))
    }
}
