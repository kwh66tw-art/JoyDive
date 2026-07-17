// SuuntoDM5XMLParser.swift — JD2Core/Importers/
// v1.1 格式擴充：Suunto DM4/DM5 桌面軟體（含 D4i 等錶款直傳）匯出的 WCF XML 序列化格式。
// 與 SuuntoJSONParser（Suunto App JSON，DeviceLog 結構）完全不同格式，
// 命名空間 Suunto.Diving.Dal 為判別特徵，不會誤吞其他格式。
//
// 已知欄位（依真實 D4i 匯出樣本驗證，file_format_research/Suunto-DM5_XML/）：
//   StartTime            本地時間，無時區（"2026-06-03T08:21:21"）
//   Duration             秒
//   MaxDepth / AvgDepth  公尺
//   BottomTemperature    攝氏（整數）
//   DiveMixture.Oxygen/Helium  百分比整數（30 = 30%），取第一組
//   DiveSamples/Dive.Sample.Time/Depth/Temperature  秒 / 公尺 / 攝氏
//   （節點名稱含點號 "Dive.Sample"，XMLParser 視為完整 element name，逐字比對即可）

import Foundation

struct SuuntoDM5XMLParser: DiveLogImporter {

    let format = DiveLogFormat.suuntoDM5

    func canHandle(filePath: String) -> Bool {
        let ext = (filePath as NSString).pathExtension.lowercased()
        guard ext == "xml" else { return false }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath),
                                   options: .mappedIfSafe) else { return false }
        return validateContent(data)
    }

    func validateContent(_ data: Data) -> Bool {
        guard let head = String(data: data.prefix(512), encoding: .utf8) else { return false }
        return head.contains("Suunto.Diving.Dal")
    }

    func parse(from filePath: String) throws -> [DiveLog] {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw DiveLogImportError.fileNotFound(filePath)
        }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath),
                                   options: .mappedIfSafe) else {
            throw DiveLogImportError.corruptedData("無法讀取: \(filePath)")
        }
        guard !data.isEmpty else { throw DiveLogImportError.emptyFile }
        return try Self.parseXMLData(data)
    }

    // MARK: - 靜態輔助（供單元測試直接呼叫）

    static func parseXMLData(_ data: Data) throws -> [DiveLog] {
        let delegate = SuuntoDM5XMLDelegate()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = delegate
        guard xmlParser.parse() else {
            let msg = xmlParser.parserError?.localizedDescription ?? "未知 XML 錯誤"
            throw DiveLogImportError.parsingFailed("Suunto DM5 XML 解析失敗: \(msg)")
        }
        if let err = delegate.fatalError { throw DiveLogImportError.parsingFailed(err) }
        guard let dive = delegate.buildDiveLog() else {
            throw DiveLogImportError.parsingFailed("缺少必要欄位（StartTime/Duration/MaxDepth）")
        }
        return [dive]
    }
}

// MARK: - XML 委託解析器

private final class SuuntoDM5XMLDelegate: NSObject, XMLParserDelegate {
    private(set) var fatalError: String?

    private var currentText = ""

    private var startTimeStr: String?
    private var duration: Int?
    private var maxDepth: Double?
    private var avgDepth: Double?
    private var bottomTemperature: Double?

    // 氣體：只取第一組 DiveMixture（開路氣瓶配置；CCR 的 setpoint 切換暫不處理）
    private var firstMixtureOxygen: Double?
    private var firstMixtureHelium: Double?
    private var inDiveMixtures = false
    private var inDiveMixture = false
    private var mixtureCaptured = false

    // 剖面樣本
    private var inDiveSamples = false
    private var inSample = false
    private var sampleTime: Double?
    private var sampleDepth: Double?
    private var sampleTemp: Double?
    private var samples: [DiveProfileSample] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentText = ""
        switch elementName {
        case "DiveMixtures":
            inDiveMixtures = true
        case "DiveMixture" where inDiveMixtures && !mixtureCaptured:
            inDiveMixture = true
        case "DiveSamples":
            inDiveSamples = true
        case "Dive.Sample" where inDiveSamples:
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
            case "Time":        sampleTime  = Double(text)
            case "Depth":       sampleDepth = Double(text)
            case "Temperature": sampleTemp  = Double(text)
            default: break
            }
        } else if inDiveMixture {
            switch elementName {
            case "Oxygen": firstMixtureOxygen = Double(text)
            case "Helium": firstMixtureHelium = Double(text)
            default: break
            }
        } else {
            switch elementName {
            case "StartTime":         startTimeStr = text
            case "Duration":          duration = Int(text)
            case "MaxDepth":          maxDepth = Double(text)
            case "AvgDepth":          avgDepth = Double(text)
            case "BottomTemperature": bottomTemperature = Double(text)
            default: break
            }
        }

        switch elementName {
        case "Dive.Sample":
            inSample = false
            if let t = sampleTime, let d = sampleDepth, t >= 0, d >= 0 {
                samples.append(DiveProfileSample(timeSeconds: t, depthMeters: d, waterTemp: sampleTemp))
            }
        case "DiveMixture":
            inDiveMixture = false
            mixtureCaptured = true
        case "DiveMixtures":
            inDiveMixtures = false
        case "DiveSamples":
            inDiveSamples = false
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        fatalError = "XML 解析錯誤: \(parseError.localizedDescription)"
    }

    // MARK: - 建立 DiveLog

    func buildDiveLog() -> DiveLog? {
        guard let startTimeStr, let dateTime = Self.parseLocalDateTime(startTimeStr),
              let duration, duration > 0,
              let maxDepth, maxDepth >= 0
        else { return nil }

        let gasMixJSON: String
        if let o2 = firstMixtureOxygen {
            let fO2 = o2 / 100.0
            let fHe = (firstMixtureHelium ?? 0) / 100.0
            if fHe > 0.001 {
                gasMixJSON = "{\"trimix\":{\"fO2\":\(String(format: "%.2f", fO2))," +
                             "\"fHe\":\(String(format: "%.2f", fHe))}}"
            } else if abs(fO2 - 0.21) < 0.005 {
                gasMixJSON = "\"air\""
            } else {
                gasMixJSON = "{\"nitrox\":{\"fO2\":\(String(format: "%.2f", fO2))}}"
            }
        } else {
            gasMixJSON = "\"air\""
        }

        let waterTemp = bottomTemperature ?? samples.compactMap(\.waterTemp).min() ?? 15.0

        let dive = DiveLog(
            dateTime: dateTime,
            location: "",
            maxDepth: maxDepth,
            diveTimeSeconds: duration,
            gasMixJSON: gasMixJSON,
            waterTemperature: waterTemp
        )
        dive.sourceFormat = "suunto-dm5"
        if let avgDepth { dive.avgDepth = avgDepth }

        if !samples.isEmpty {
            let sorted = samples.sorted { $0.timeSeconds < $1.timeSeconds }
            if let jsonData = try? JSONEncoder().encode(sorted),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                dive.profileSamplesJSON = jsonStr
            }
        }

        return dive
    }

    /// "2026-06-03T08:21:21" 無時區偏移，視為裝置本地時間，以 UTC 曆法元件直接建構
    /// （沿用專案既有慣例：Subsurface CSV/UDDF 等無時區來源皆同法處理，避免裝置時區未知時的不可控位移）
    private static func parseLocalDateTime(_ str: String) -> Date? {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return fmt.date(from: str)
    }
}
