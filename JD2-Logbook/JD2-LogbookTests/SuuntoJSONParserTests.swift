// SuuntoJSONParserTests.swift — JD2-LogbookTests
// Week 6：SuuntoJSONParser 單元測試
//
// 測試樣本：TestFiles/Suunto/（來自 Subsurface 開源專案）
//   - suunto_eon_core_nitrox.json   (Nitrox 32%, Duration=3970s, MaxDepth=22.65m, Temp=29.10°C)
//   - suunto_nautic_sidemount.json  (Air, Duration=2011s, MaxDepth=21.24m, Temp=9.19°C, Notes)
//   - suunto_ocean_air.json         (Air, Duration=3312s, MaxDepth=23.4m, Temp=28.96°C, Notes)
//
// 測試覆蓋：
//   - 格式偵測（canHandle / validateContent）
//   - 三個真實檔案完整解析（深度 / 時間 / 氣體 / 溫度 / 備註）
//   - ISO 8601 日期含毫秒及時區偏移解析
//   - Duration 浮點數四捨五入
//   - 氣體：Nitrox vs Air（有 Gases / 無 Gases）
//   - 水溫：Kelvin → Celsius（samples 最低溫）
//   - sourceFormat = "suunto-json"
//   - 錯誤處理（空資料、缺少結構、缺少必填欄位）
//   - 工廠自動偵測、DiveLogFormat.suunto 副檔名
// AI-generated (Claude)

import XCTest
@testable import JoyDive_

final class SuuntoJSONParserTests: XCTestCase {

    // MARK: - 測試資源路徑

    private var suuntoDir: String {
        // TestFiles/Suunto/ 在專案 repo 根目錄下
        let here        = (#filePath as NSString).deletingLastPathComponent  // …/JD2-LogbookTests
        let moduleRoot  = (here as NSString).deletingLastPathComponent       // …/JD2-Logbook
        let repoRoot    = (moduleRoot as NSString).deletingLastPathComponent // …/JD2-Logbook (repo)
        return (repoRoot as NSString).appendingPathComponent("../_JD2-family/dive-log-samples/Suunto")
    }

    private func suuntoPath(_ filename: String) -> String {
        (suuntoDir as NSString).appendingPathComponent(filename)
    }

    private var nitroxPath:  String { suuntoPath("suunto_eon_core_nitrox.json") }
    private var nauticPath:  String { suuntoPath("suunto_nautic_sidemount.json") }
    private var oceanPath:   String { suuntoPath("suunto_ocean_air.json") }

    /// 測試檔案不存在時優雅跳過（TestFiles 不在 repo 中時避免 CI 失敗）
    private func skipIfMissing(_ path: String) throws {
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: path),
            "測試檔案不存在，略過：\((path as NSString).lastPathComponent)"
        )
    }

    // MARK: - 測試 1：格式偵測 — 副檔名過濾

    func testRejectNonJSONExtension() {
        let parser = SuuntoJSONParser()
        XCTAssertFalse(parser.canHandle(filePath: "/path/to/file.xml"),  ".xml 應被拒絕")
        XCTAssertFalse(parser.canHandle(filePath: "/path/to/file.ssrf"), ".ssrf 應被拒絕")
        XCTAssertFalse(parser.canHandle(filePath: "/path/to/file.csv"),  ".csv 應被拒絕")
        XCTAssertFalse(parser.canHandle(filePath: "/path/to/file.uddf"), ".uddf 應被拒絕")
        XCTAssertFalse(parser.canHandle(filePath: "/path/to/file.fit"),  ".fit 應被拒絕")
    }

    // MARK: - 測試 2：validateContent — DeviceLog 關鍵字

    func testValidateContentWithDeviceLog() {
        let parser = SuuntoJSONParser()
        let data = "{\"DeviceLog\":{\"Header\":{}}}".data(using: .utf8)!
        XCTAssertTrue(parser.validateContent(data), "含 DeviceLog 應通過驗證")
    }

    func testValidateContentWithoutDeviceLog() {
        let parser = SuuntoJSONParser()
        let data = "{\"SomeOtherKey\":{}}".data(using: .utf8)!
        XCTAssertFalse(parser.validateContent(data), "不含 DeviceLog 應拒絕")
    }

    func testValidateContentEmptyData() {
        let parser = SuuntoJSONParser()
        XCTAssertFalse(parser.validateContent(Data()), "空資料應拒絕")
    }

    // MARK: - 測試 3：canHandle — 真實檔案

    func testCanHandleRealNitroxFile() throws {
        try skipIfMissing(nitroxPath)
        let parser = SuuntoJSONParser()
        XCTAssertTrue(parser.canHandle(filePath: nitroxPath),
                      "suunto_eon_core_nitrox.json 應被接受")
    }

    // MARK: - 測試 4：完整解析 — suunto_eon_core_nitrox.json

    func testParseNitroxFile() throws {
        try skipIfMissing(nitroxPath)
        let data = try Data(contentsOf: URL(fileURLWithPath: nitroxPath))
        let dives = try SuuntoJSONParser.parseJSONData(data)

        XCTAssertEqual(dives.count, 1, "應解析出 1 筆潛水")
        let dive = try XCTUnwrap(dives.first)

        // Duration: 3970 秒
        XCTAssertEqual(dive.diveTimeSeconds, 3970, "Duration 應為 3970s")

        // MaxDepth: 22.65m
        XCTAssertEqual(dive.maxDepth, 22.65, accuracy: 0.01, "MaxDepth 應為 22.65m")

        // 氣體：Nitrox O2=0.32
        XCTAssertEqual(dive.gasMixJSON, "{\"nitrox\":{\"fO2\":0.32}}", "應為 Nitrox 32%")

        // 水溫：min(K)=302.25 → 29.10°C
        XCTAssertEqual(dive.waterTemperature, 29.10, accuracy: 0.05, "水溫應約 29.10°C")

        // 無備註
        XCTAssertTrue(dive.notes.isEmpty, "eon_core_nitrox 不含備註")

        // sourceFormat
        XCTAssertEqual(dive.sourceFormat, "suunto-json")
    }

    // MARK: - 測試 5：完整解析 — suunto_nautic_sidemount.json

    func testParseNauticSidemountFile() throws {
        try skipIfMissing(nauticPath)
        let data = try Data(contentsOf: URL(fileURLWithPath: nauticPath))
        let dives = try SuuntoJSONParser.parseJSONData(data)

        XCTAssertEqual(dives.count, 1)
        let dive = try XCTUnwrap(dives.first)

        // Duration: 2010.962 → 四捨五入 = 2011
        XCTAssertEqual(dive.diveTimeSeconds, 2011, "Duration 2010.962 應四捨五入為 2011s")

        // MaxDepth: 21.24m
        XCTAssertEqual(dive.maxDepth, 21.24, accuracy: 0.01)

        // 氣體：無 Gases → Air
        XCTAssertEqual(dive.gasMixJSON, "\"air\"", "無 Gases 應預設 Air")

        // 水溫：min(K)=282.34 → 9.19°C
        XCTAssertEqual(dive.waterTemperature, 9.19, accuracy: 0.05)

        // 備註
        XCTAssertFalse(dive.notes.isEmpty, "nautic_sidemount 應有備註")
        XCTAssertTrue(dive.notes.contains("Suunto Nautic"), "備註應含 'Suunto Nautic'")
    }

    // MARK: - 測試 6：完整解析 — suunto_ocean_air.json

    func testParseOceanAirFile() throws {
        try skipIfMissing(oceanPath)
        let data = try Data(contentsOf: URL(fileURLWithPath: oceanPath))
        let dives = try SuuntoJSONParser.parseJSONData(data)

        XCTAssertEqual(dives.count, 1)
        let dive = try XCTUnwrap(dives.first)

        // Duration: 3312.104 → 3312
        XCTAssertEqual(dive.diveTimeSeconds, 3312, "Duration 3312.104 應四捨五入為 3312s")

        // MaxDepth: 23.4m
        XCTAssertEqual(dive.maxDepth, 23.4, accuracy: 0.01)

        // 氣體：無 Gases → Air
        XCTAssertEqual(dive.gasMixJSON, "\"air\"")

        // 水溫：min(K)=302.11 → 28.96°C
        XCTAssertEqual(dive.waterTemperature, 28.96, accuracy: 0.05)

        // 備註
        XCTAssertFalse(dive.notes.isEmpty)
        XCTAssertTrue(dive.notes.contains("Suunto Ocean"))
    }

    // MARK: - 測試 7：DateTime — ISO 8601 含毫秒及時區偏移

    func testParseISO8601WithFractionalSecondsAndOffset() {
        // 2024-10-06T02:33:51.530+02:00 → UTC: 2024-10-06T00:33:51Z
        let date = SuuntoJSONParser.parseISO8601("2024-10-06T02:33:51.530+02:00")
        XCTAssertNotNil(date, "含毫秒 + 時區偏移應可解析")

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date!)
        XCTAssertEqual(comps.year,   2024)
        XCTAssertEqual(comps.month,  10)
        XCTAssertEqual(comps.day,    6)
        XCTAssertEqual(comps.hour,   0,  "UTC hour 應為 0（本地 02:33 - 2h）")
        XCTAssertEqual(comps.minute, 33)
    }

    func testParseISO8601WithoutFractionalSeconds() {
        // 無毫秒格式也應可解析
        let date = SuuntoJSONParser.parseISO8601("2024-10-06T02:33:51+02:00")
        XCTAssertNotNil(date, "無毫秒的 ISO 8601 應可解析")
    }

    func testParseISO8601InvalidReturnsNil() {
        XCTAssertNil(SuuntoJSONParser.parseISO8601("not-a-date"))
        XCTAssertNil(SuuntoJSONParser.parseISO8601(""))
    }

    // MARK: - 測試 8：DateTime 正確映射至 DiveLog

    func testNitroxFileDateTimeUTC() throws {
        try skipIfMissing(nitroxPath)
        let data = try Data(contentsOf: URL(fileURLWithPath: nitroxPath))
        let dive = try SuuntoJSONParser.parseJSONData(data).first!

        // 2024-10-06T02:33:51.530+02:00 → UTC 00:33:51
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: dive.dateTime)
        XCTAssertEqual(comps.year,  2024)
        XCTAssertEqual(comps.month, 10)
        XCTAssertEqual(comps.day,   6)
        XCTAssertEqual(comps.hour,  0)
        XCTAssertEqual(comps.minute, 33)
    }

    // MARK: - 測試 9：氣體 — Nitrox JSON 格式

    func testGasMixNitroxJSON() throws {
        try skipIfMissing(nitroxPath)
        let data = try Data(contentsOf: URL(fileURLWithPath: nitroxPath))
        let dive = try SuuntoJSONParser.parseJSONData(data).first!
        // 確認 gasMixJSON 可被 JSONSerialization 解析並含正確 fO2
        let jsonData = dive.gasMixJSON.data(using: .utf8)!
        let parsed   = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        XCTAssertNotNil(parsed, "nitrox gasMixJSON 應為有效 JSON 物件")
        let nitrox   = parsed?["nitrox"] as? [String: Any]
        XCTAssertNotNil(nitrox)
        let fO2 = try XCTUnwrap((nitrox?["fO2"] as? NSNumber)?.doubleValue)
        XCTAssertEqual(fO2, 0.32, accuracy: 0.001, "nitrox fO2 應為 0.32")
    }

    // MARK: - 測試 10：氣體 — 無 Gases 欄位預設 Air

    func testGasMixAirWhenGasesMissing() throws {
        let json = """
        {"DeviceLog":{"Header":{"DateTime":"2024-01-01T10:00:00+00:00","Duration":1800,
         "Depth":{"Max":20.0}},"Samples":[]}}
        """
        let data = json.data(using: .utf8)!
        let dives = try SuuntoJSONParser.parseJSONData(data)
        XCTAssertEqual(dives.first?.gasMixJSON, "\"air\"", "無 Gases 應預設 air")
    }

    // MARK: - 測試 11：水溫 — 無 Samples 時使用預設值

    func testWaterTemperatureDefaultWhenNoSamples() throws {
        let json = """
        {"DeviceLog":{"Header":{"DateTime":"2024-01-01T10:00:00+00:00","Duration":1800,
         "Depth":{"Max":20.0}},"Samples":[]}}
        """
        let data = json.data(using: .utf8)!
        let dives = try SuuntoJSONParser.parseJSONData(data)
        let tempDive = try XCTUnwrap(dives.first)
        XCTAssertEqual(tempDive.waterTemperature, 20.0, accuracy: 0.01,
                       "無 Samples 應使用預設水溫 20°C")
    }

    // MARK: - 測試 12：sourceFormat

    func testSourceFormatIsSuuntoJSON() throws {
        try skipIfMissing(nitroxPath)
        let data = try Data(contentsOf: URL(fileURLWithPath: nitroxPath))
        let dive = try SuuntoJSONParser.parseJSONData(data).first!
        XCTAssertEqual(dive.sourceFormat, "suunto-json")
    }

    // MARK: - 測試 13：parse(from:) — 真實檔案路徑

    func testParseFromFilePathNitrox() throws {
        try skipIfMissing(nitroxPath)
        let parser = SuuntoJSONParser()
        let dives = try parser.parse(from: nitroxPath)
        XCTAssertEqual(dives.count, 1)
    }

    // MARK: - 測試 14：錯誤處理 — 空資料

    func testParseEmptyDataThrows() {
        XCTAssertThrowsError(try SuuntoJSONParser.parseJSONData(Data())) { error in
            XCTAssertTrue(error is DiveLogImportError, "應拋出 DiveLogImportError")
        }
    }

    // MARK: - 測試 15：錯誤處理 — 缺少 DeviceLog 結構

    func testParseMissingDeviceLogThrows() {
        let data = "{\"NotDeviceLog\":{}}".data(using: .utf8)!
        XCTAssertThrowsError(try SuuntoJSONParser.parseJSONData(data)) { error in
            guard case DiveLogImportError.invalidFormat = error else {
                XCTFail("應為 invalidFormat，得到 \(error)")
                return
            }
        }
    }

    // MARK: - 測試 16：錯誤處理 — 缺少 Duration

    func testParseMissingDurationThrows() {
        let json = """
        {"DeviceLog":{"Header":{"DateTime":"2024-01-01T10:00:00+00:00",
         "Depth":{"Max":20.0}},"Samples":[]}}
        """
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try SuuntoJSONParser.parseJSONData(data)) { error in
            guard case DiveLogImportError.parsingFailed = error else {
                XCTFail("應為 parsingFailed，得到 \(error)")
                return
            }
        }
    }

    // MARK: - 測試 17：錯誤處理 — 缺少 Depth.Max

    func testParseMissingDepthMaxThrows() {
        let json = """
        {"DeviceLog":{"Header":{"DateTime":"2024-01-01T10:00:00+00:00","Duration":1800},
         "Samples":[]}}
        """
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try SuuntoJSONParser.parseJSONData(data)) { error in
            guard case DiveLogImportError.parsingFailed = error else {
                XCTFail("應為 parsingFailed，得到 \(error)")
                return
            }
        }
    }

    // MARK: - 測試 18：錯誤處理 — 檔案不存在

    func testParseFileNotFoundThrows() {
        let parser = SuuntoJSONParser()
        XCTAssertThrowsError(try parser.parse(from: "/nonexistent/file.json")) { error in
            guard case DiveLogImportError.fileNotFound = error else {
                XCTFail("應為 fileNotFound，得到 \(error)")
                return
            }
        }
    }

    // MARK: - 測試 19：DiveLogFormat.suunto 副檔名

    func testDiveLogFormatSuuntoExtension() {
        XCTAssertEqual(DiveLogFormat.suunto.supportedExtensions, ["json"],
                       "suunto 格式應只支援 .json")
    }

    // MARK: - 測試 20：工廠自動偵測

    func testFactorySelectsSuuntoJSONParser() throws {
        try skipIfMissing(nitroxPath)
        let parser = DiveLogImporterFactory.selectImporter(for: nitroxPath)
        XCTAssertNotNil(parser, "Factory 應能識別 .json Suunto 檔案")
        XCTAssertEqual(parser?.format, .suunto, "應選擇 suunto 解析器")
    }

    // MARK: - 測試 21：Duration 浮點四捨五入

    func testDurationFloatRounding() throws {
        try skipIfMissing(nauticPath)
        try skipIfMissing(oceanPath)
        // 2010.962 → 2011（nautic sidemount）
        let nautData = try Data(contentsOf: URL(fileURLWithPath: nauticPath))
        let nautDive = try SuuntoJSONParser.parseJSONData(nautData).first!
        XCTAssertEqual(nautDive.diveTimeSeconds, 2011)

        // 3312.104 → 3312（ocean air）
        let oceanData = try Data(contentsOf: URL(fileURLWithPath: oceanPath))
        let oceanDive = try SuuntoJSONParser.parseJSONData(oceanData).first!
        XCTAssertEqual(oceanDive.diveTimeSeconds, 3312)
    }

    // MARK: - 測試 22：合成 JSON — 最小必要欄位

    func testSyntheticMinimalJSONParsed() throws {
        let json = """
        {"DeviceLog":{"Header":{
          "DateTime":"2025-06-15T08:30:00.000+08:00",
          "Duration":2700,
          "Depth":{"Max":18.5},
          "Diving":{"Gases":[{"Oxygen":0.32}]},
          "Notes":"合成測試備註"
        },"Samples":[
          {"Temperature":299.15},
          {"Temperature":298.15},
          {"Temperature":297.15}
        ]}}
        """
        let data = json.data(using: .utf8)!
        let dives = try SuuntoJSONParser.parseJSONData(data)

        XCTAssertEqual(dives.count, 1)
        let dive = try XCTUnwrap(dives.first)

        XCTAssertEqual(dive.diveTimeSeconds, 2700)
        XCTAssertEqual(dive.maxDepth, 18.5, accuracy: 0.001)
        XCTAssertEqual(dive.gasMixJSON, "{\"nitrox\":{\"fO2\":0.32}}")
        // min(K): 297.15 → 24.00°C
        XCTAssertEqual(dive.waterTemperature, 24.0, accuracy: 0.05)
        XCTAssertEqual(dive.notes, "合成測試備註")
        XCTAssertEqual(dive.sourceFormat, "suunto-json")

        // DateTime: 2025-06-15T08:30+08:00 → UTC 00:30
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: dive.dateTime)
        XCTAssertEqual(comps.year,   2025)
        XCTAssertEqual(comps.month,  6)
        XCTAssertEqual(comps.day,    15)
        XCTAssertEqual(comps.hour,   0)
        XCTAssertEqual(comps.minute, 30)
    }

    // MARK: - 真實 Suunto App 匯出（2026-07-19 使用者提供，首次有真實資料驗證此格式）
    //
    // 這個格式先前是全家族驗證狀態最差者：解析器與上面的測試都聲稱驗證用了
    // suunto_eon_core_nitrox.json 等 3 個檔案，但那些檔案從未存在過（見
    // _JD2-family/F-07-IMPORT_FORMAT_COVERAGE.md），上面 3 個 testParse*File
    // 測試從建立以來全數靜默跳過。這兩筆才是第一次有真實資料跑過這條路徑。
    //
    // 驗證時發現真實 bug：真機樣本點只有 TimeISO8601（絕對時間戳），從未出現
    // 相對秒數的 "Time" 欄位——解析器原本只認 "Time"，導致 profileSamples 永遠是
    // 空陣列（dive 匯入成功但深度剖面圖是空的，不會報錯，是靜默資料遺失）。
    // 已修復：改用 TimeISO8601 與 Header.DateTime 的差反推相對秒數。

    private var realDir: String {
        let here       = (#filePath as NSString).deletingLastPathComponent
        let moduleRoot = (here as NSString).deletingLastPathComponent
        let repoRoot   = (moduleRoot as NSString).deletingLastPathComponent
        return (repoRoot as NSString).appendingPathComponent("../_JD2-family/dive-log-samples/Suunto")
    }

    func testParseRealSample_0948() throws {
        let path = (realDir as NSString).appendingPathComponent("6a5ccfc7393493432c953691.json")
        try skipIfMissing(path)
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let dives = try SuuntoJSONParser.parseJSONData(data)
        XCTAssertEqual(dives.count, 1)
        let dive = try XCTUnwrap(dives.first)

        XCTAssertEqual(dive.diveTimeSeconds, 2119)
        XCTAssertEqual(dive.maxDepth, 29.59, accuracy: 0.001)
        XCTAssertEqual(dive.gasMixJSON, "{\"nitrox\":{\"fO2\":0.3}}")
        XCTAssertEqual(dive.waterTemperature, 28.0, accuracy: 0.01)
        XCTAssertEqual(dive.sourceFormat, "suunto-json")

        // 迴歸驗證：TimeISO8601 fallback 必須真的產出剖面樣本，不能是空陣列
        XCTAssertFalse(dive.profileSamples.isEmpty, "應從 TimeISO8601 反推出剖面樣本")
        XCTAssertEqual(dive.profileSamples.first?.timeSeconds ?? -1, 0, accuracy: 0.5)
    }

    func testParseRealSample_0821() throws {
        let path = (realDir as NSString).appendingPathComponent("6a5ccfc7baa3dc6d2f4fd9cf.json")
        try skipIfMissing(path)
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let dives = try SuuntoJSONParser.parseJSONData(data)
        XCTAssertEqual(dives.count, 1)
        let dive = try XCTUnwrap(dives.first)

        XCTAssertEqual(dive.diveTimeSeconds, 2269)
        XCTAssertEqual(dive.maxDepth, 23.88, accuracy: 0.001)
        XCTAssertEqual(dive.gasMixJSON, "{\"nitrox\":{\"fO2\":0.3}}")
        XCTAssertEqual(dive.waterTemperature, 28.0, accuracy: 0.01)
        XCTAssertFalse(dive.profileSamples.isEmpty)
    }

    func testTimeISO8601FallbackWhenTimeFieldAbsent() throws {
        // 迴歸測試：合成資料重現真機的樣本結構（只有 TimeISO8601，無 Time）
        let json = """
        {"DeviceLog":{"Header":{
          "DateTime":"2026-01-01T10:00:00.000+08:00",
          "Duration":60,
          "Depth":{"Max":5.0},
          "Diving":{"Gases":[{"Oxygen":0.21}]}
        },"Samples":[
          {"Depth":1.0,"Temperature":300.0,"TimeISO8601":"2026-01-01T10:00:00.000+08:00"},
          {"Depth":2.0,"Temperature":300.0,"TimeISO8601":"2026-01-01T10:00:10.000+08:00"},
          {"Depth":3.0,"Temperature":300.0,"TimeISO8601":"2026-01-01T10:00:20.000+08:00"}
        ]}}
        """
        let dives = try SuuntoJSONParser.parseJSONData(json.data(using: .utf8)!)
        let dive = try XCTUnwrap(dives.first)
        XCTAssertEqual(dive.profileSamples.count, 3)
        XCTAssertEqual(dive.profileSamples.map(\.timeSeconds), [0, 10, 20])
        XCTAssertEqual(dive.profileSamples.map(\.depthMeters), [1.0, 2.0, 3.0])
    }
}
