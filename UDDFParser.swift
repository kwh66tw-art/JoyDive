import Foundation
import ZipFoundation

/// UDDF (Universal Dive Data Format) 解析器
/// 支援 UDDF 3.x 格式，ISO 12639:2015
///
/// UDDF 是 XML 格式的潛水記錄標準，通常儲存在 ZIP 容器內。
/// 此解析器提取 uddf.xml 中的 <dive> 元素，映射到 DiveLog 模型。
class UDDFParser: DiveLogImporter {

    // MARK: - Private Constants

    private let uddfFileName = "uddf.xml"
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // MARK: - DiveLogImporter Protocol

    /// 解析 UDDF 檔案並返回潛水記錄陣列
    /// - Parameter fileURL: UDDF 檔案位置 (ZIP 檔案)
    /// - Returns: [DiveLog] 陣列
    /// - Throws: ImportError (檔案不存在、格式無效、解析失敗)
    func parse(fileURL: URL) throws -> [DiveLog] {
        // 驗證檔案存在
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ImportError.fileNotFound
        }

        // 開啟 ZIP 檔案
        guard let archive = Archive(url: fileURL, accessMode: .read) else {
            throw ImportError.invalidFormat(reason: "Invalid ZIP file format")
        }

        // 找出 uddf.xml
        guard let uddfEntry = archive[uddfFileName] else {
            throw ImportError.invalidFormat(reason: "uddf.xml not found in ZIP")
        }

        // 提取 XML 內容
        var xmlData = Data()
        _ = try archive.extract(uddfEntry) { data in
            xmlData.append(data)
        }

        guard !xmlData.isEmpty else {
            throw ImportError.parsingFailed(reason: "Empty uddf.xml file")
        }

        // 解析 XML 並提取 <dive> 元素
        let parser = XMLParser(data: xmlData)
        let delegate = UDDFXMLParserDelegate()
        parser.delegate = delegate

        guard parser.parse() else {
            throw ImportError.parsingFailed(reason: "XML parsing failed: \(parser.parserError?.localizedDescription ?? "Unknown error")")
        }

        // 轉換為 DiveLog 陣列
        return delegate.dives.compactMap { xmlDive in
            convertToDiveLog(from: xmlDive)
        }
    }

    /// 驗證潛水記錄的完整性
    func validate(logs: [DiveLog]) -> ImportValidation {
        var warnings: [String] = []
        var errors: [String] = []

        for (index, log) in logs.enumerated() {
            // 檢查必填欄位
            if log.diveDate == Date(timeIntervalSince1970: 0) {
                errors.append("Dive #\(index): Missing or invalid dive date")
            }

            // 檢查邏輯錯誤
            if log.maxDepth < 0 {
                errors.append("Dive #\(index): Negative depth value")
            }

            if log.diveTime < 0 {
                errors.append("Dive #\(index): Negative dive duration")
            }

            // 警告：缺失選擇欄位
            if log.location?.isEmpty ?? true {
                warnings.append("Dive #\(index): Missing location information")
            }

            if log.waterTemp == nil {
                warnings.append("Dive #\(index): Missing water temperature")
            }
        }

        return ImportValidation(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings,
            successCount: logs.count,
            failureCount: 0
        )
    }

    // MARK: - Private Methods

    /// 將 XML 潛水記錄轉換為 DiveLog 模型
    private func convertToDiveLog(from xmlDive: UDDFXMLDive) -> DiveLog? {
        // 驗證必填欄位
        guard let dateString = xmlDive.dateTime,
              let date = dateFormatter.date(from: dateString) else {
            return nil // 缺失或無效的日期，跳過此潛水記錄
        }

        guard let depthString = xmlDive.maxDepth,
              let depth = Double(depthString) else {
            return nil // 缺失最大深度
        }

        guard let durationString = xmlDive.duration else {
            return nil // 缺失潛水時長
        }

        let timeInterval = parseDurationString(durationString)
        guard timeInterval > 0 else {
            return nil // 無效的時長
        }

        let diveLog = DiveLog(
            id: UUID(),
            diveNumber: Int(xmlDive.diveNumber ?? "0") ?? 0,
            diveDate: date,
            location: xmlDive.location?.trimmingCharacters(in: .whitespaces) ?? "Unknown Location",
            maxDepth: depth,
            diveTime: timeInterval,
            waterTemp: xmlDive.surfaceTemp.flatMap { Double($0) },
            notes: nil,
            isManualEntry: false,
            importSource: "UDDF",
            lastModified: Date()
        )

        return diveLog
    }

    /// 解析潛水時長字符串 (HH:MM:SS 格式)
    /// - Parameter durationString: 格式如 "01:23:45" 或 "1:23:45"
    /// - Returns: 秒數 (TimeInterval)
    private func parseDurationString(_ durationString: String) -> TimeInterval {
        let components = durationString.split(separator: ":").compactMap { Int($0) }

        guard components.count >= 2 else { return 0 }

        let hours = components.count > 2 ? components[0] : 0
        let minutes = components.count > 2 ? components[1] : components[0]
        let seconds = components.count > 2 ? components[2] : components[1]

        return TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }
}

// MARK: - XML Parser Delegate

/// 解析 UDDF XML 結構的委託類別
private class UDDFXMLParserDelegate: NSObject, XMLParserDelegate {

    var dives: [UDDFXMLDive] = []
    private var currentDive: UDDFXMLDive?
    private var currentElement: String?
    private var currentValue: String = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        currentElement = elementName
        currentValue = ""

        switch elementName {
        case "dive":
            // 開始新的潛水記錄
            currentDive = UDDFXMLDive()
            // datetime 可能存在於屬性中
            if let dateTime = attributeDict["datetime"] {
                currentDive?.dateTime = dateTime
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        // 累積字符（可能分次發送）
        currentValue += string.trimmingCharacters(in: .whitespaces)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard let dive = currentDive else { return }

        // 根據元素名稱映射值
        switch elementName {
        case "dive":
            // 潛水記錄結束
            if !currentValue.isEmpty {
                dives.append(dive)
            }
            currentDive = nil

        case "datetime":
            dive.dateTime = currentValue
        case "divenumber":
            dive.diveNumber = currentValue
        case "location":
            dive.location = currentValue
        case "greatestdepth":
            dive.maxDepth = currentValue
        case "diveduration":
            dive.duration = currentValue
        case "surfacetemperature":
            dive.surfaceTemp = currentValue
        case "bottomtemperature":
            dive.bottomTemp = currentValue
        default:
            break
        }

        currentElement = nil
        currentValue = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("XML Parse Error: \(parseError.localizedDescription)")
    }
}

// MARK: - Helper Structures

/// 表示 UDDF XML 中的單筆潛水記錄
private struct UDDFXMLDive {
    var dateTime: String?
    var diveNumber: String?
    var location: String?
    var maxDepth: String?
    var duration: String?
    var surfaceTemp: String?
    var bottomTemp: String?
}

/// 匯入驗證結果
struct ImportValidation {
    let isValid: Bool
    let errors: [String]
    let warnings: [String]
    let successCount: Int
    let failureCount: Int
}

// MARK: - Error Definitions

enum ImportError: LocalizedError {
    case fileNotFound
    case invalidFormat(reason: String)
    case parsingFailed(reason: String)
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Dive log file not found"
        case .invalidFormat(let reason):
            return "Invalid file format: \(reason)"
        case .parsingFailed(let reason):
            return "Failed to parse file: \(reason)"
        case .unsupportedFormat:
            return "Unsupported file format"
        }
    }
}

// MARK: - DiveLogImporter Protocol Definition

protocol DiveLogImporter {
    func parse(fileURL: URL) throws -> [DiveLog]
    func validate(logs: [DiveLog]) -> ImportValidation
}

// MARK: - DiveLog Placeholder

/// 簡化版 DiveLog 結構（完整版應來自 JoyDiveCore）
struct DiveLog {
    let id: UUID
    let diveNumber: Int
    let diveDate: Date
    let location: String?
    let maxDepth: Double
    let diveTime: TimeInterval
    let waterTemp: Double?
    let notes: String?
    let isManualEntry: Bool
    let importSource: String?
    let lastModified: Date
}
