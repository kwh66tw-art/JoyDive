// DiveLogImporter.swift — JD2Core/Importers/DiveLogImporter.swift
// v1.2 Week 8：SeabearCSVParser 新增；GarminDescentParser 水溫 + GPS 強化；tech debt 修復
//
// 潛水日誌匯入器協議 (Protocol)
// 定義所有格式解析器的統一介面
// 支援: UDDF, SHEARWATER, Peregrine, Subsurface CSV, Seabear CSV, Garmin, Suunto JSON, Oceanic
//
// ──────────────────────────────────────────────────────────────────
// 設計原則：Importer 只負責單位換算，不做值的正確性判斷
//
//   - 有資料就照實匯入，值的合理性由使用者自行確認
//   - 不同來源格式的同一欄位可能使用不同單位（Pa vs bar、
//     Kelvin vs Celsius、m³ vs L 等），importer 統一換算成
//     JD2 的標準單位後存入模型
//   - 閾值判斷（如 < 100、> 1000、< 1）是「偵測廠商使用哪種單位」
//     的格式啟發式規則，不是「這個值合不合理」的驗證邏輯
//   - 結構合法性檢查（duration > 0、maxDepth >= 0 等）僅用於
//     判斷「能否建出有效的 DiveLog 物件」，不是資料品質過濾
// ──────────────────────────────────────────────────────────────────
//
// SPM 依賴（PM 請透過 Xcode GUI 加入）：
//   roznet/FitFileParser  https://github.com/roznet/FitFileParser
//   （取代 FitDataProtocol —— 後者無 DiveSummaryMessage / DiveGasMessage）

import Foundation
import FitFileParser   // roznet/FitFileParser — 封裝 Garmin 官方 C SDK FitSDK 21.115
import DiveKit

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

/// v1.1 #6/#7：將匯入時無對應欄位的原始資料（buddy/裝置序號/韌體/tags 等）
/// 編碼為 importExtrasJSON，取代舊有「dump 進 notes 文字」作法
func buildImportExtrasJSON(_ pairs: [(String, String)]) -> String {
    guard !pairs.isEmpty else { return "{}" }
    let dict = Dictionary(uniqueKeysWithValues: pairs)
    guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
          let str  = String(data: data, encoding: .utf8) else { return "{}" }
    return str
}

/// 匯入格式列舉
enum DiveLogFormat: String, CaseIterable {
    case uddf       = "UDDF"
    case subsurface = "Subsurface"   // Subsurface XML (.ssrf / .xml)
    case shearwater = "SHEARWATER"
    case peregrine  = "Peregrine"
    case csv        = "CSV"           // Subsurface 手動 CSV 格式（#Nr header）
    case seabear    = "Seabear"       // Seabear Diving Technology CSV 格式
    case garmin     = "Garmin"
    case suunto     = "Suunto"
    case oceanic    = "Oceanic"
    // v1.1 格式擴充（file_format_research 18 格式盤點）
    case suuntoDM5  = "Suunto DM5"      // DM4/DM5 桌面軟體 / D4i 等錶款直接匯出的 WCF XML
    case suuntoSML  = "Suunto SML"      // Moveslink/Moveslink2 快取的 XML
    case suuntoSDE  = "Suunto SDE"      // DM5 加密備份包（zip 內含 DM3 XML）
    case danDL7     = "DAN DL7"         // Divers Alert Network 管線分隔文字格式
    case divesoft   = "Divesoft DLF"    // Freedom/Liberty 專有二進位格式
    case scubapro   = "Scubapro"        // LogTRAK SQLite / TravelTRAK .asd
    case mares      = "Mares"           // Dive Organizer SQL Server Compact (.sdf)
    case ostc       = "HW OSTC"         // Heinrichs Weikamp OSTC 記憶體 dump
    case sensus     = "Reefnet Sensus"  // Sensus CSV 採樣格式
    case divingLog  = "Diving Log"      // Diving Log 6.0 SQL 匯出
    case cressi     = "Cressi"          // Cressi PC Interface 純文字/HTML 匯出

    /// 支援的檔案副檔名
    var supportedExtensions: [String] {
        switch self {
        case .uddf:       return ["uddf", "zip"]
        case .subsurface: return ["ssrf", "xml"]   // .ssrf 原生，.xml 為 Subsurface 匯出
        case .shearwater: return ["xml"]
        case .peregrine:  return ["xml"]
        case .csv:        return ["csv"]
        case .seabear:    return ["csv"]            // .csv（canHandle 以內容區分）
        case .garmin:     return ["fit", "json"]   // v1.1 #12：json = Garmin Connect 匯出（canHandle 內容區分）
        case .suunto:     return ["json"]
        case .oceanic:    return ["ocf", "xml"]
        case .suuntoDM5:  return ["xml"]
        case .suuntoSML:  return ["sml", "xml"]
        case .suuntoSDE:  return ["sde", "zip"]
        case .danDL7:     return ["dl7", "zxu", "zxl", "txt"]
        case .divesoft:   return ["dlf"]
        case .scubapro:   return ["db", "asd", "slg"]
        case .mares:      return ["sdf"]
        case .ostc:       return ["bin", "log"]
        case .sensus:     return ["dat", "csv"]
        case .divingLog:  return ["sql", "sqlite", "db"]   // 實際為 SQLite 資料庫，非文字 SQL/XML
        case .cressi:     return ["txt", "html", "htm"]
        }
    }

    /// 格式顯示名稱
    var displayName: String {
        self.rawValue
    }

    /// 優先順序（用於格式自動偵測）
    /// Subsurface 優先級最高：canHandle 含內容驗證，不會誤判其他 .xml
    /// Seabear 優先於 CSV：canHandle 讀取前 512 bytes 確認含 "SEABEAR" 特徵
    var priority: Int {
        switch self {
        case .subsurface: return 0   // 最優先，內容驗證確保正確性
        case .uddf:       return 1
        case .shearwater: return 2
        case .garmin:     return 3
        case .suunto:     return 4
        case .oceanic:    return 5
        case .seabear:    return 6   // 優先於通用 CSV（以內容簽名區分）
        case .peregrine:  return 7
        // v1.1 格式擴充：皆以內容簽名區分，彼此互斥，數字大小僅為排序穩定性
        case .suuntoDM5:  return 9
        case .suuntoSML:  return 10
        case .suuntoSDE:  return 11
        case .danDL7:     return 12
        case .divesoft:   return 13
        case .scubapro:   return 14
        case .mares:      return 15
        case .ostc:       return 16
        case .sensus:     return 17
        case .divingLog:  return 18
        case .cressi:     return 19   // 純文字啟發式偵測最弱，優先權最低（在 csv 之後）
        case .csv:        return 8
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
        SubsurfaceXMLParser(),
        UDDFParser(),
        SHEARWATERParser(),
        PeregrineParser(),
        SeabearCSVParser(),      // 優先於通用 SubsurfaceCSVParser（內容簽名區分）
        SubsurfaceCSVParser(),
        GarminDescentParser(),
        GarminConnectJSONParser(),   // v1.1 #12：FIT 的替代路線，內容簽名與 SuuntoJSONParser 互斥
        SuuntoJSONParser(),
        OceanicParser(),
        // v1.1 格式擴充（file_format_research 18 格式盤點）
        SuuntoDM5XMLParser(),
        SuuntoSMLParser(),
        DANDL7Parser(),
        DivesoftDLFParser(),
        SuuntoSDEParser(),
        ReefnetSensusParser(),
        DivingLogSQLiteParser()
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

// MARK: - 解析器實現（Week 3-8）

/// UDDF 解析器
// F6：實作已搬遷至 DiveImportKit，薄包裝見 DiveImportKitAdapter.swift

/// SHEARWATER 解析器 (XML format)
// F6：實作已搬遷至 DiveImportKit，薄包裝見 DiveImportKitAdapter.swift

/// Peregrine 解析器 (新 Shearwater with ppO2)
struct PeregrineParser: DiveLogImporter {
    let format = DiveLogFormat.peregrine

    /// Peregrine 與 Perdix/Teric/NERD2 共用同一套 Shearwater Cloud XML 匯出格式，
    /// 已由 SHEARWATERParser 完整涵蓋。此處必須明確覆寫為 false——
    /// 若沿用預設實作（僅比對副檔名 .xml），會攔截「所有」.xml 檔案，
    /// 誤判 Suunto DM5/SML 等其他 XML 格式（即最初 D4i XML 匯入失敗的根因）。
    func canHandle(filePath: String) -> Bool { false }

    func parse(from filePath: String) throws -> [DiveLog] {
        throw DiveLogImportError.unsupportedFormat("Peregrine 匯出格式已由 SHEARWATERParser 涵蓋")
    }
}

/// Subsurface CSV 解析器
// F6：實作已搬遷至 DiveImportKit，薄包裝見 DiveImportKitAdapter.swift

/// Garmin Descent 解析器（ANT+ FIT）／Garmin Connect JSON／Suunto JSON 解析器
// 2026-07-19 家族層 import 共用第二階段：實作已搬遷至 DiveImportKit，薄包裝見 DiveImportKitAdapter.swift


/// Oceanic 解析器 (OCF binary + XML + compression)
struct OceanicParser: DiveLogImporter {
    let format = DiveLogFormat.oceanic

    /// 尚未實作解析邏輯：明確覆寫為 false，避免沿用預設實作（副檔名 .ocf/.xml
    /// 皆比對為真）誤攔截其他真正支援的 .xml 格式（同 PeregrineParser 修法）。
    func canHandle(filePath: String) -> Bool { false }

    func parse(from filePath: String) throws -> [DiveLog] {
        throw DiveLogImportError.unsupportedFormat("Oceanic 解析器待實現")
    }
}

// MARK: - SeabearCSVParser
// F6：實作已搬遷至 DiveImportKit，薄包裝見 DiveImportKitAdapter.swift

// ============================================================
// MARK: - Double 精確度輔助

private extension Double {
    /// 四捨五入到指定小數位數
    func rounded(toDecimalPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
