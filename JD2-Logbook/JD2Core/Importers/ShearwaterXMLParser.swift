// ShearwaterXMLParser.swift — JD2Core/Importers/
// v1.1 格式擴充：Shearwater Cloud/Desktop 專有 XML 匯出格式（Perdix/Teric/Peregrine/NERD2 共用）。
// 取代舊有的 SHEARWATERParser 空 stub（原本連 canHandle 都用預設的純副檔名比對，
// 會誤攔截所有 .xml 檔案——這正是使用者最初回報 D4i XML 匯入失敗的根因之一）。
//
// 已知欄位（file_format_research/Shearwater_XML/shearwater_dive.xml）：
//   <logbook><dive>
//     <start_time>          ISO 8601
//     <duration>             秒
//     <max_depth>            公尺
//     <mean_depth>           公尺 → avgDepth
//     <water_temp>           攝氏
//     <computer_model>       型號字串（用於 canHandle 內容特徵）
//     <gases><gas><oxygen>/<helium>   數值同時可能是百分比整數或分率，需啟發式判定
//     <samples><sample><time>/<depth>/<temp>/<pressure>

import Foundation

struct SHEARWATERParser: DiveLogImporter {

    let format = DiveLogFormat.shearwater

    func canHandle(filePath: String) -> Bool {
        let ext = (filePath as NSString).pathExtension.lowercased()
        guard ext == "xml" else { return false }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath),
                                   options: .mappedIfSafe) else { return false }
        return validateContent(data)
    }

    func validateContent(_ data: Data) -> Bool {
        guard let head = String(data: data.prefix(1024), encoding: .utf8) else { return false }
        return head.contains("<logbook>") && head.contains("<computer_model>")
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
        let delegate = ShearwaterXMLDelegate()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = delegate
        guard xmlParser.parse() else {
            let msg = xmlParser.parserError?.localizedDescription ?? "未知 XML 錯誤"
            throw DiveLogImportError.parsingFailed("Shearwater XML 解析失敗: \(msg)")
        }
        if let err = delegate.fatalError { throw DiveLogImportError.parsingFailed(err) }
        let dives = delegate.buildDiveLogs()
        guard !dives.isEmpty else {
            throw DiveLogImportError.parsingFailed("找不到有效的潛水紀錄")
        }
        return dives
    }
}

// MARK: - XML 委託解析器

private struct ShearwaterParsedDive {
    var startTimeStr: String?
    var duration: Int?
    var maxDepth: Double?
    var meanDepth: Double?
    var waterTemp: Double?
    var oxygen: Double?
    var helium: Double?
    var gasCaptured = false
    var samples: [DiveProfileSample] = []
}

private final class ShearwaterXMLDelegate: NSObject, XMLParserDelegate {
    private(set) var fatalError: String?

    private var currentText = ""
    private var currentDive: ShearwaterParsedDive?
    private var parsedDives: [ShearwaterParsedDive] = []

    private var inGases = false
    private var inGas = false
    private var inSamples = false
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
        case "dive":
            currentDive = ShearwaterParsedDive()
        case "gases":
            inGases = true
        case "gas" where inGases && currentDive?.gasCaptured != true:
            inGas = true
        case "samples":
            inSamples = true
        case "sample" where inSamples:
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
            case "time":  sampleTime  = Double(text)
            case "depth": sampleDepth = Double(text)
            case "temp":  sampleTemp  = Double(text)
            default: break
            }
        } else if inGas {
            switch elementName {
            case "oxygen": currentDive?.oxygen = Double(text)
            case "helium": currentDive?.helium = Double(text)
            default: break
            }
        } else if currentDive != nil {
            switch elementName {
            case "start_time":     currentDive?.startTimeStr = text
            case "duration":       currentDive?.duration = Int(text)
            case "max_depth":      currentDive?.maxDepth = Double(text)
            case "mean_depth":     currentDive?.meanDepth = Double(text)
            case "water_temp":     currentDive?.waterTemp = Double(text)
            default: break
            }
        }

        switch elementName {
        case "sample":
            inSample = false
            if let t = sampleTime, let d = sampleDepth, t >= 0, d >= 0 {
                currentDive?.samples.append(
                    DiveProfileSample(timeSeconds: t, depthMeters: d, waterTemp: sampleTemp)
                )
            }
        case "samples":
            inSamples = false
        case "gas":
            inGas = false
            currentDive?.gasCaptured = true
        case "gases":
            inGases = false
        case "dive":
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
            guard let startTimeStr = dive.startTimeStr,
                  let dateTime = Self.parseISO8601(startTimeStr),
                  let duration = dive.duration, duration > 0,
                  let maxDepth = dive.maxDepth, maxDepth >= 0
            else { return nil }

            let gasMixJSON = Self.buildGasMixJSON(oxygen: dive.oxygen, helium: dive.helium)
            let waterTemp = dive.waterTemp ?? dive.samples.compactMap(\.waterTemp).min() ?? 15.0

            let log = DiveLog(
                dateTime: dateTime,
                location: "",
                maxDepth: maxDepth,
                diveTimeSeconds: duration,
                gasMixJSON: gasMixJSON,
                waterTemperature: waterTemp
            )
            log.sourceFormat = "shearwater"
            if let mean = dive.meanDepth { log.avgDepth = mean }

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

    /// Shearwater 匯出版本不一，<oxygen> 可能是百分比整數（21）或分率（0.21）
    private static func buildGasMixJSON(oxygen: Double?, helium: Double?) -> String {
        guard let rawO2 = oxygen else { return "\"air\"" }
        let fO2 = rawO2 > 1.0 ? rawO2 / 100.0 : rawO2
        let rawHe = helium ?? 0
        let fHe = rawHe > 1.0 ? rawHe / 100.0 : rawHe

        if fHe > 0.001 {
            return "{\"trimix\":{\"fO2\":\(String(format: "%.2f", fO2))," +
                   "\"fHe\":\(String(format: "%.2f", fHe))}}"
        } else if abs(fO2 - 0.21) < 0.005 {
            return "\"air\""
        } else {
            return "{\"nitrox\":{\"fO2\":\(String(format: "%.2f", fO2))}}"
        }
    }

    private static func parseISO8601(_ str: String) -> Date? {
        let fracFmt = ISO8601DateFormatter()
        fracFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fracFmt.date(from: str) { return d }
        let stdFmt = ISO8601DateFormatter()
        stdFmt.formatOptions = [.withInternetDateTime]
        if let d = stdFmt.date(from: str) { return d }
        // 無時區格式："2023-08-17T08:51:59"
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return fmt.date(from: str)
    }
}
