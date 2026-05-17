// DiveLogImporter.swift — JD2Core/Importers/DiveLogImporter.swift
// v1.0 INITIAL
//
// 潛水日誌匯入器協議 (Protocol)
// 定義所有格式解析器的統一介面
// 支援: UDDF, SHEARWATER, Peregrine, Cressi/Mares, Garmin, Suunto, Oceanic

import Foundation

/// 匯入錯誤類型定義
enum DiveLogImportError: Error, LocalizedError {
    case fileNotFound(String)
    case invalidFormat(String)
    case parsingFailed(String, underlyingError: Error? = nil)
    case unsupportedFormat(String)
    case corruptedData(String)
    case emptyFile

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "找不到檔案: \(path)"
        case .invalidFormat(let format):
            return "無效的檔案格式: \(format)"
        case .parsingFailed(let detail, let error):
            return "解析失敗: \(detail)" + (error != nil ? " (\(error!))" : "")
        case .unsupportedFormat(let format):
            return "不支援的格式: \(format)"
        case .corruptedData(let detail):
            return "檔案已損壞: \(detail)"
        case .emptyFile:
            return "空檔案"
        }
    }
}

/// 匯入格式列舉
enum DiveLogFormat: String, CaseIterable {
    case uddf = "UDDF"
    case shearwater = "SHEARWATER"
    case peregrine = "Peregrine"
    case cresiMares = "Cressi/Mares"
    case garmin = "Garmin"
    case suunto = "Suunto"
    case oceanic = "Oceanic"

    /// 支援的檔案副檔名
    var supportedExtensions: [String] {
        switch self {
        case .uddf:
            return ["uddf", "zip"]
        case .shearwater:
            return ["xml"]
        case .peregrine:
            return ["xml"]
        case .cresiMares:
            return ["csv"]
        case .garmin:
            return ["fit"]
        case .suunto:
            return ["xml", "sde", "sdp"]
        case .oceanic:
            return ["ocf", "xml"]
        }
    }

    /// 格式顯示名稱
    var displayName: String {
        self.rawValue
    }

    /// 優先順序（用於格式自動偵測）
    var priority: Int {
        switch self {
        case .uddf:       return 1   // 最常見
        case .shearwater: return 2
        case .garmin:     return 3
        case .suunto:     return 4
        case .oceanic:    return 5
        case .peregrine:  return 6
        case .cresiMares: return 7   // 最不常見
        }
    }
}

/// 潛水日誌匯入器協議
/// 所有格式的解析器必須實現此協議
protocol DiveLogImporter {

    /// 解析器名稱（用於日誌記錄與調試）
    var name: String { get }

    /// 支援的格式
    var format: DiveLogFormat { get }

    /// 從檔案路徑解析潛水日誌
    /// - Parameter filePath: 檔案的絕對路徑
    /// - Returns: 解析得到的潛水日誌陣列
    /// - Throws: DiveLogImportError
    func parse(from filePath: String) throws -> [DiveLog]

    /// 驗證檔案是否為此格式
    /// - Parameter filePath: 檔案的絕對路徑
    /// - Returns: 是否符合格式
    func canHandle(filePath: String) -> Bool

    /// 驗證檔案內容（可選）
    /// - Parameter data: 檔案的原始數據
    /// - Returns: 是否有效
    func validateContent(_ data: Data) -> Bool
}

// MARK: - 預設實現

extension DiveLogImporter {

    var name: String {
        format.displayName
    }

    /// 預設驗證：檢查檔案副檔名
    func canHandle(filePath: String) -> Bool {
        let ext = (filePath as NSString).pathExtension.lowercased()
        return format.supportedExtensions.contains(ext)
    }

    /// 預設驗證：無特殊檢查
    func validateContent(_ data: Data) -> Bool {
        return !data.isEmpty
    }
}

// MARK: - 解析器工廠

/// 解析器工廠，根據檔案選擇適當的解析器
struct DiveLogImporterFactory {

    /// 所有可用的解析器
    static let availableParsers: [DiveLogImporter] = [
        UDDFParser(),
        SHEARWATERParser(),
        PeregrineParser(),
        CresiMaresParser(),
        GarminDescentParser(),
        SuuntoParser(),
        OceanicParser()
    ]

    /// 根據檔案路徑自動選擇解析器
    /// - Parameter filePath: 檔案路徑
    /// - Returns: 適合的解析器，若無則為 nil
    static func selectImporter(for filePath: String) -> DiveLogImporter? {
        // 優先順序排序
        let sortedParsers = availableParsers.sorted { $0.format.priority < $1.format.priority }
        return sortedParsers.first { $0.canHandle(filePath: filePath) }
    }

    /// 列出所有支援的格式
    static func supportedFormats() -> [DiveLogFormat] {
        DiveLogFormat.allCases
    }

    /// 檢查格式是否支援
    static func isFormatSupported(_ format: DiveLogFormat) -> Bool {
        availableParsers.contains { $0.format == format }
    }
}

// MARK: - 臨時解析器框架（Week 3-8 實現）

/// UDDF 解析器 (ISO 12639:2015 XML in ZIP)
struct UDDFParser: DiveLogImporter {
    let format = DiveLogFormat.uddf

    func parse(from filePath: String) throws -> [DiveLog] {
        throw DiveLogImportError.unsupportedFormat("UDDF 解析器待實現 (Week 3)")
    }
}

/// SHEARWATER 解析器 (XML format)
struct SHEARWATERParser: DiveLogImporter {
    let format = DiveLogFormat.shearwater

    func parse(from filePath: String) throws -> [DiveLog] {
        throw DiveLogImportError.unsupportedFormat("SHEARWATER 解析器待實現 (Week 4)")
    }
}

/// Peregrine 解析器 (新 Shearwater with ppO2)
struct PeregrineParser: DiveLogImporter {
    let format = DiveLogFormat.peregrine

    func parse(from filePath: String) throws -> [DiveLog] {
        throw DiveLogImportError.unsupportedFormat("Peregrine 解析器待實現 (Week 4)")
    }
}

/// Cressi/Mares 解析器 (CSV format)
struct CresiMaresParser: DiveLogImporter {
    let format = DiveLogFormat.cresiMares

    func parse(from filePath: String) throws -> [DiveLog] {
        throw DiveLogImportError.unsupportedFormat("Cressi/Mares 解析器待實現 (Week 5)")
    }
}

/// Garmin Descent 解析器 (複雜多命名空間 XML)
struct GarminDescentParser: DiveLogImporter {
    let format = DiveLogFormat.garmin

    func parse(from filePath: String) throws -> [DiveLog] {
        throw DiveLogImportError.unsupportedFormat("Garmin Descent 解析器待實現 (Week 7)")
    }
}

/// Suunto 解析器 (SDE binary + XML + SDP)
struct SuuntoParser: DiveLogImporter {
    let format = DiveLogFormat.suunto

    func parse(from filePath: String) throws -> [DiveLog] {
        throw DiveLogImportError.unsupportedFormat("Suunto 解析器待實現 (Week 7)")
    }
}

/// Oceanic 解析器 (OCF binary + XML + compression)
struct OceanicParser: DiveLogImporter {
    let format = DiveLogFormat.oceanic

    func parse(from filePath: String) throws -> [DiveLog] {
        throw DiveLogImportError.unsupportedFormat("Oceanic 解析器待實現 (Week 8)")
    }
}
