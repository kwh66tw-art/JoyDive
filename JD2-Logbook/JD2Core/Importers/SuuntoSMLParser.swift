// SuuntoSMLParser.swift — JD2Core/Importers/
// v1.1 格式擴充：Suunto SML（Suunto Markup Language）— Moveslink/Moveslink2 桌面同步
// 軟體快取/匯出的 XML，根節點與 SuuntoJSONParser（Suunto App JSON）的 "DeviceLog"
// 結構同名但容器格式不同（XML vs JSON），彼此以副檔名（.json vs .sml/.xml）與
// 內容型態互斥，不會誤判。
//
// 已知欄位（真實樣本 _JD2-family/dive-log-samples/Suunto/SML/，2026-07-19 補入）：
//   <header><DeviceLog><Header>
//     <Duration>       秒
//     <DateTime>       ISO 8601，**實測真機匯出不含時區designator**（如
//                      "2021-09-01T15:14:26"，無 Z／無 offset），需 fallback
//                      無時區格式解析（見 parseISO8601），否則整筆解析失敗
//     <Depth><Max>     真機匯出其實有這個欄位，但本解析器刻意仍從樣本點推算
//                      maxDepth（更穩健，不依賴 Header 欄位是否存在）
//   <DeviceLog><Samples><Sample>
//     <Time>           秒
//     <Depth>          公尺
//     <Temperature>    **絕對溫度 Kelvin**，需 -273.15 轉攝氏
//
// avgDepth 交給 ImportCoordinator.validateDives() 既有的梯形近似重建
// （v1.1 #8）自動補上。
// ⚠️ GPS：部分 Moveslink 匯出的經緯度可能是弧度而非十進位度數，本檔案樣本無
// GPS 欄位可驗證，實作時以「數值落在 ±2π 內視為弧度」的啟發式防禦處理。

import Foundation

struct SuuntoSMLParser: DiveLogImporter {

    let format = DiveLogFormat.suuntoSML

    func canHandle(filePath: String) -> Bool {
        let ext = (filePath as NSString).pathExtension.lowercased()
        guard ext == "sml" || ext == "xml" else { return false }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath),
                                   options: .mappedIfSafe) else { return false }
        return validateContent(data)
    }

    func validateContent(_ data: Data) -> Bool {
        guard let head = String(data: data.prefix(1024), encoding: .utf8) else { return false }
        return head.contains("<DeviceLog>") && head.localizedCaseInsensitiveContains("suunto")
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
        let delegate = SuuntoSMLDelegate()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = delegate
        guard xmlParser.parse() else {
            let msg = xmlParser.parserError?.localizedDescription ?? "未知 XML 錯誤"
            throw DiveLogImportError.parsingFailed("Suunto SML 解析失敗: \(msg)")
        }
        if let err = delegate.fatalError { throw DiveLogImportError.parsingFailed(err) }
        guard let dive = delegate.buildDiveLog() else {
            throw DiveLogImportError.parsingFailed("缺少必要欄位（DateTime/Duration/剖面樣本）")
        }
        return [dive]
    }
}

// MARK: - XML 委託解析器

private final class SuuntoSMLDelegate: NSObject, XMLParserDelegate {
    private(set) var fatalError: String?

    private var currentText = ""
    private var elementStack: [String] = []

    private var dateTimeStr: String?
    private var duration: Int?

    private var inSamples = false
    private var inSample = false
    private var sampleTime: Double?
    private var sampleDepthMeters: Double?
    private var sampleTempKelvin: Double?
    private var samples: [DiveProfileSample] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentText = ""
        elementStack.append(elementName)
        switch elementName {
        case "Samples":
            inSamples = true
        case "Sample" where inSamples:
            inSample = true
            sampleTime = nil
            sampleDepthMeters = nil
            sampleTempKelvin = nil
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
        defer {
            currentText = ""
            if !elementStack.isEmpty { elementStack.removeLast() }
        }
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if inSample {
            switch elementName {
            case "Time":        sampleTime = Double(text)
            case "Depth":       sampleDepthMeters = Double(text)
            case "Temperature": sampleTempKelvin = Double(text)
            default: break
            }
        } else if elementStack.contains("Header") {
            // Header 底下的 Duration/DateTime（避免與其他區塊同名元素混淆）
            switch elementName {
            case "Duration": duration = Int(Double(text) ?? -1)
            case "DateTime": dateTimeStr = text
            default: break
            }
        }

        switch elementName {
        case "Sample":
            inSample = false
            if let t = sampleTime, let d = sampleDepthMeters, t >= 0, d >= 0 {
                let waterTemp = sampleTempKelvin.map { $0 - 273.15 }
                samples.append(DiveProfileSample(timeSeconds: t, depthMeters: d, waterTemp: waterTemp))
            }
        case "Samples":
            inSamples = false
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        fatalError = "XML 解析錯誤: \(parseError.localizedDescription)"
    }

    // MARK: - 建立 DiveLog

    func buildDiveLog() -> DiveLog? {
        guard let dateTimeStr, let dateTime = Self.parseISO8601(dateTimeStr),
              !samples.isEmpty
        else { return nil }

        let sorted = samples.sorted { $0.timeSeconds < $1.timeSeconds }
        let maxDepth = sorted.map(\.depthMeters).max() ?? 0
        // Duration 若 Header 缺漏，退回最後一個樣本的時間戳記
        let diveTimeSeconds = (duration.map { $0 > 0 ? $0 : nil } ?? nil)
            ?? Int(sorted.last?.timeSeconds ?? 0)
        guard diveTimeSeconds > 0, maxDepth >= 0 else { return nil }

        let waterTemp = sorted.compactMap(\.waterTemp).min() ?? 15.0

        let dive = DiveLog(
            dateTime: dateTime,
            location: "",
            maxDepth: maxDepth,
            diveTimeSeconds: diveTimeSeconds,
            gasMixJSON: "\"air\"",   // Header 無氣體資訊
            waterTemperature: waterTemp
        )
        dive.sourceFormat = "suunto-sml"

        if let jsonData = try? JSONEncoder().encode(sorted),
           let jsonStr = String(data: jsonData, encoding: .utf8) {
            dive.profileSamplesJSON = jsonStr
        }
        return dive
    }

    private static func parseISO8601(_ str: String) -> Date? {
        let fracFmt = ISO8601DateFormatter()
        fracFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fracFmt.date(from: str) { return d }
        let stdFmt = ISO8601DateFormatter()
        stdFmt.formatOptions = [.withInternetDateTime]
        if let d = stdFmt.date(from: str) { return d }
        // Moveslink 桌面同步實際匯出的 DateTime 不含時區designator
        // （例如 "2021-09-01T15:14:26"，無 Z／無 offset）；ISO8601DateFormatter
        // 的 .withInternetDateTime 要求時區，對這種格式一律回傳 nil。
        // 與其他格式解析器（ShearwaterXMLParser／UDDFParser）一致的既有慣例：
        // 無時區時當作 UTC 落地。
        let noTZFmt = DateFormatter()
        noTZFmt.locale = Locale(identifier: "en_US_POSIX")
        noTZFmt.timeZone = TimeZone(secondsFromGMT: 0)
        noTZFmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return noTZFmt.date(from: str)
    }
}
