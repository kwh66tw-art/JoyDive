// SuuntoSDEParser.swift — JD2Core/Importers/
// v1.1 格式擴充：Suunto SDE（DM3/DM4 桌面軟體匯出的 ZIP 包裝格式）。
//
// ⚠️ 與 file_format_research 原始研究文件的猜測不同：實際解壓真實樣本
// （TestFiles/Suunto/SDE/TestDiveDM3.SDE）驗證後，內含的 0.xml **不是**
// DM5 的 WCF XML（Suunto.Diving.Dal 命名空間），而是更早期的 DM3 專有格式
// （根節點 <SUUNTO><HEADER>...<MSG>...<SAMPLE>...）。此為又一次「研究文件
// 假設與真實檔案不符，需以實際樣本內容為準」的案例。
//
// 已驗證欄位（皆為歐式逗號小數，如 "24,69"，解析前需轉換為句點）：
//   MSG.DATE           DD.MM.YYYY
//   MSG.TIME           HH:MM:SS
//   MSG.MAXDEPTH       公尺（逗號小數）
//   MSG.MEANDEPTH      公尺（逗號小數）→ avgDepth
//   MSG.DIVETIMESEC    秒（整數，不需從樣本推算）
//   MSG.O2PCT/HEPCT_0  百分比整數
//   MSG.LOCATION/SITE  地點
//   MSG.LOGNOTES       備註
//   MSG.SAMPLE.SAMPLETIME/DEPTH/TEMPERATURE  秒 / 公尺（逗號小數）/ 攝氏

import Foundation

struct SuuntoSDEParser: DiveLogImporter {

    let format = DiveLogFormat.suuntoSDE

    func canHandle(filePath: String) -> Bool {
        let ext = (filePath as NSString).pathExtension.lowercased()
        guard ext == "sde" else { return false }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath),
                                   options: .mappedIfSafe) else { return false }
        return validateContent(data)
    }

    func validateContent(_ data: Data) -> Bool {
        data.prefix(4).elementsEqual([0x50, 0x4B, 0x03, 0x04])   // ZIP magic
    }

    func parse(from filePath: String) throws -> [DiveLog] {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw DiveLogImportError.fileNotFound(filePath)
        }
        guard let zipData = try? Data(contentsOf: URL(fileURLWithPath: filePath),
                                      options: .mappedIfSafe) else {
            throw DiveLogImportError.corruptedData("無法讀取: \(filePath)")
        }
        guard !zipData.isEmpty else { throw DiveLogImportError.emptyFile }

        let xmlData: Data
        do {
            xmlData = try MinimalZipReader.extractFirstEntry(from: zipData) {
                $0.lowercased().hasSuffix(".xml")
            }
        } catch {
            throw DiveLogImportError.parsingFailed("SDE ZIP 解壓失敗", underlyingError: error)
        }
        return try Self.parseDM3XMLData(xmlData)
    }

    // MARK: - 靜態輔助（供單元測試直接呼叫）

    static func parseDM3XMLData(_ data: Data) throws -> [DiveLog] {
        // DM3 XML 常見 ISO-8859-15 編碼宣告；先試 UTF-8，失敗則退回 ISO Latin1
        let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        guard let xmlText = text else {
            throw DiveLogImportError.invalidFormat("無法解碼 SDE 內部 XML 編碼")
        }
        let delegate = SuuntoDM3Delegate()
        let xmlParser = XMLParser(data: Data(xmlText.utf8))
        xmlParser.delegate = delegate
        guard xmlParser.parse() else {
            let msg = xmlParser.parserError?.localizedDescription ?? "未知 XML 錯誤"
            throw DiveLogImportError.parsingFailed("Suunto SDE (DM3) 解析失敗: \(msg)")
        }
        if let err = delegate.fatalError { throw DiveLogImportError.parsingFailed(err) }
        let dives = delegate.buildDiveLogs()
        guard !dives.isEmpty else {
            throw DiveLogImportError.parsingFailed("找不到有效的潛水紀錄（缺少 MSG 區塊）")
        }
        return dives
    }
}

// MARK: - DM3 XML 委託解析器

private struct SDEParsedDive {
    var dateStr: String?
    var timeStr: String?
    var maxDepth: Double?
    var meanDepth: Double?
    var diveTimeSec: Int?
    var o2Pct: Double?
    var hePct: Double?
    var location: String?
    var site: String?
    var notes: String?
    var waterTempAtMaxDepth: Double?
    var samples: [DiveProfileSample] = []
}

private final class SuuntoDM3Delegate: NSObject, XMLParserDelegate {
    private(set) var fatalError: String?

    private var currentText = ""
    private var currentDive: SDEParsedDive?
    private var parsedDives: [SDEParsedDive] = []

    private var inSample = false
    private var sampleTime: Double?
    private var sampleDepth: Double?
    private var sampleTemp: Double?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentText = ""
        switch elementName {
        case "MSG":
            currentDive = SDEParsedDive()
        case "SAMPLE" where currentDive != nil:
            inSample = true
            sampleTime = nil
            sampleDepth = nil
            sampleTemp = nil
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        defer { currentText = "" }
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if inSample {
            switch elementName {
            case "SAMPLETIME": sampleTime  = Double(text)
            case "DEPTH":       sampleDepth = Self.parseCommaDouble(text)
            case "TEMPERATURE": sampleTemp  = Double(text)
            default: break
            }
        } else if currentDive != nil {
            switch elementName {
            case "DATE":               currentDive?.dateStr = text
            case "TIME":               currentDive?.timeStr = text
            case "MAXDEPTH":           currentDive?.maxDepth = Self.parseCommaDouble(text)
            case "MEANDEPTH":          currentDive?.meanDepth = Self.parseCommaDouble(text)
            case "DIVETIMESEC":        currentDive?.diveTimeSec = Int(text)
            case "O2PCT":              currentDive?.o2Pct = Double(text)
            case "HEPCT_0":            currentDive?.hePct = Double(text)
            case "LOCATION":           currentDive?.location = text
            case "SITE":               currentDive?.site = text
            case "LOGNOTES":           currentDive?.notes = text
            case "WATERTEMPMAXDEPTH":  currentDive?.waterTempAtMaxDepth = Double(text)
            default: break
            }
        }

        switch elementName {
        case "SAMPLE":
            inSample = false
            if let t = sampleTime, let d = sampleDepth, t >= 0, d >= 0 {
                currentDive?.samples.append(
                    DiveProfileSample(timeSeconds: t, depthMeters: d, waterTemp: sampleTemp)
                )
            }
        case "MSG":
            if let dive = currentDive { parsedDives.append(dive) }
            currentDive = nil
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        fatalError = "XML 解析錯誤: \(parseError.localizedDescription)"
    }

    // MARK: - 建立 DiveLog

    func buildDiveLogs() -> [DiveLog] {
        parsedDives.compactMap { dive -> DiveLog? in
            guard let dateStr = dive.dateStr, let timeStr = dive.timeStr,
                  let dateTime = Self.parseDMYDateTime(date: dateStr, time: timeStr),
                  let maxDepth = dive.maxDepth, maxDepth >= 0
            else { return nil }

            let diveTimeSeconds = dive.diveTimeSec ?? Int(dive.samples.map(\.timeSeconds).max() ?? 0)
            guard diveTimeSeconds > 0 else { return nil }

            let gasMixJSON = Self.buildGasMixJSON(o2Pct: dive.o2Pct, hePct: dive.hePct)
            let waterTemp = dive.samples.compactMap(\.waterTemp).min()
                ?? dive.waterTempAtMaxDepth ?? 15.0

            let log = DiveLog(
                dateTime: dateTime,
                location: [dive.site, dive.location].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", "),
                maxDepth: maxDepth,
                diveTimeSeconds: diveTimeSeconds,
                gasMixJSON: gasMixJSON,
                waterTemperature: waterTemp
            )
            log.sourceFormat = "suunto-sde"
            if let mean = dive.meanDepth { log.avgDepth = mean }
            if let notes = dive.notes, !notes.isEmpty { log.notes = notes }

            if !dive.samples.isEmpty {
                let sorted = dive.samples.sorted { $0.timeSeconds < $1.timeSeconds }
                if let jsonData = try? JSONEncoder().encode(sorted),
                   let jsonStr = String(data: jsonData, encoding: .utf8) {
                    log.profileSamplesJSON = jsonStr
                }
            }
            return log
        }
    }

    // MARK: - 私有輔助

    /// 歐式逗號小數："24,69" → 24.69
    private static func parseCommaDouble(_ str: String) -> Double? {
        Double(str.replacingOccurrences(of: ",", with: "."))
    }

    /// "17.05.2011" + "11:01:00" → Date（無時區資訊，視為 UTC）
    private static func parseDMYDateTime(date: String, time: String) -> Date? {
        let dp = date.split(separator: ".").map(String.init)
        guard dp.count == 3, let day = Int(dp[0]), let month = Int(dp[1]), let year = Int(dp[2])
        else { return nil }
        let tp = time.split(separator: ":").map(String.init)
        let hour = tp.count >= 1 ? (Int(tp[0]) ?? 0) : 0
        let minute = tp.count >= 2 ? (Int(tp[1]) ?? 0) : 0
        let second = tp.count >= 3 ? (Int(tp[2]) ?? 0) : 0

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute; comps.second = second
        return cal.date(from: comps)
    }

    private static func buildGasMixJSON(o2Pct: Double?, hePct: Double?) -> String {
        guard let o2 = o2Pct, o2 > 0 else { return "\"air\"" }
        let fO2 = o2 / 100.0
        let fHe = (hePct ?? 0) / 100.0
        if fHe > 0.001 {
            return "{\"trimix\":{\"fO2\":\(String(format: "%.2f", fO2))," +
                   "\"fHe\":\(String(format: "%.2f", fHe))}}"
        } else if abs(fO2 - 0.21) < 0.005 {
            return "\"air\""
        } else {
            return "{\"nitrox\":{\"fO2\":\(String(format: "%.2f", fO2))}}"
        }
    }
}
