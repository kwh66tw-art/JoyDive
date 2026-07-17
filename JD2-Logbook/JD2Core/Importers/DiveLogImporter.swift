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
    case deepblu    = "Deepblu"         // Deepblu COSMIQ+ 雲端 API JSON（格式假設，待真實樣本驗證）

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
        case .deepblu:    return ["json"]
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
        case .deepblu:    return 20
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
        DivingLogSQLiteParser(),
        DeepbluCOSMIQParser()
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

/// UDDF 解析器 — ISO 12639:2015
///
/// 支援格式：
///   - 純 XML：.uddf 直接為 XML（最常見）
///   - ZIP 包裝：.uddf 為 ZIP，內含 uddf.xml（macOS 才支援）
///
/// 測試驗證：
///   - test42.uddf        (UDDF 3.2 + xmlns 命名空間, CCR 湖潛, 1 dive)
///   - test-apd-inspiration.uddf (UDDF 3.3, CCR 海潛, 2 dives → 1 有效)
///
/// 溫度單位：UDDF 使用 Kelvin，內部轉換為 Celsius
struct UDDFParser: DiveLogImporter {

    let format = DiveLogFormat.uddf

    // MARK: - DiveLogImporter 協議

    /// 只接受 .uddf，避免與其他 XML 解析器衝突
    func canHandle(filePath: String) -> Bool {
        (filePath as NSString).pathExtension.lowercased() == "uddf"
    }

    /// 驗證為有效 UDDF（XML 或 ZIP 包裝）
    func validateContent(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        // ZIP 魔術位元組 PK\x03\x04
        if data.prefix(4).elementsEqual([0x50, 0x4B, 0x03, 0x04]) { return true }
        // XML 宣告或 <uddf 根元素
        guard let head = String(data: data.prefix(512), encoding: .utf8) else { return false }
        return head.contains("<?xml") || head.contains("<uddf")
    }

    func parse(from filePath: String) throws -> [DiveLog] {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw DiveLogImportError.fileNotFound(filePath)
        }
        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: filePath),
                                       options: .mappedIfSafe) else {
            throw DiveLogImportError.corruptedData("無法讀取: \(filePath)")
        }
        guard !fileData.isEmpty else {
            throw DiveLogImportError.emptyFile
        }

        // ZIP vs 純 XML
        let xmlData: Data
        if fileData.prefix(4).elementsEqual([0x50, 0x4B, 0x03, 0x04]) {
            xmlData = try UDDFParser.extractXMLFromZIP(fileData)
        } else {
            xmlData = fileData
        }

        return try UDDFParser.parseXMLData(xmlData)
    }

    // MARK: - 靜態輔助（供單元測試直接呼叫）

    /// 從 XML Data 解析潛水記錄
    static func parseXMLData(_ data: Data) throws -> [DiveLog] {
        let delegate = UDDFXMLDelegate()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = delegate
        // shouldProcessNamespaces = false：直接取本地名稱，忽略命名空間前綴
        // 確保 test42.uddf (xmlns="http://www.streit.cc/uddf/3.2/") 與無命名空間版本行為一致
        xmlParser.shouldProcessNamespaces = false
        xmlParser.shouldReportNamespacePrefixes = false

        guard xmlParser.parse() else {
            let msg = xmlParser.parserError?.localizedDescription ?? "未知 XML 錯誤"
            throw DiveLogImportError.parsingFailed("XML 解析失敗: \(msg)")
        }
        if let err = delegate.fatalError {
            throw DiveLogImportError.parsingFailed(err)
        }
        return delegate.buildDiveLogs()
    }

    /// ZIP 解壓：改用跨平台 MinimalZipReader（v1.1 修正 iOS 原本完全不支援
    /// ZIP 包裝 UDDF 的缺口——原本用 Process 呼叫 macOS 系統 unzip，iOS 沙盒
    /// 無法執行任意可執行檔）。優先找 uddf.xml，找不到則退回任何 .xml 條目。
    static func extractXMLFromZIP(_ zipData: Data) throws -> Data {
        do {
            return try MinimalZipReader.extractFirstEntry(from: zipData) {
                $0.lowercased() == "uddf.xml"
            }
        } catch {
            return try MinimalZipReader.extractFirstEntry(from: zipData) {
                $0.lowercased().hasSuffix(".xml")
            }
        }
    }
}

/// SHEARWATER 解析器 (XML format)
// 真正實作見 ShearwaterXMLParser.swift（本檔案僅保留其餘格式的解析器）

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

/// Subsurface CSV 解析器 — Subsurface 手動 CSV 匯入格式
///
/// 格式特徵：
///   - 第一行為 header，以 `#Nr` 開頭
///   - 欄位：#Nr, date(M/D/YY), time(HH:MM), duration(MM:SS),
///           maxdepth, avgdepth, buddy, suit, notes
///   - RFC 4180 引號規則（欄位含逗號或換行時用 "" 包覆，
///     欄位內的 " 以 "" 轉義）
///   - 無氣體、無溫度欄位（使用 DiveLog 預設值）
///
/// 測試驗證：
///   - test41.csv（4 筆潛水，含多行 notes、逗號 buddy、double-quote 轉義）
///   - 參考輸出：test-csv.xml（Subsurface 原始碼 dives/test-csv.xml）
// AI-generated (Claude)
struct SubsurfaceCSVParser: DiveLogImporter {

    let format = DiveLogFormat.csv

    // MARK: - DiveLogImporter 協議

    /// 格式偵測：.csv 副檔名 + 內容首行以 "#Nr" 開頭
    func canHandle(filePath: String) -> Bool {
        let ext = (filePath as NSString).pathExtension.lowercased()
        guard ext == "csv" else { return false }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath),
                                   options: .mappedIfSafe) else { return false }
        return validateContent(data)
    }

    /// 驗證：讀取前 512 bytes 確認以 "#Nr" 開頭
    func validateContent(_ data: Data) -> Bool {
        guard let head = String(data: data.prefix(512), encoding: .utf8) else { return false }
        return head.hasPrefix("#Nr")
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
        return try SubsurfaceCSVParser.parseCSVData(data)
    }

    // MARK: - 靜態輔助（供單元測試直接呼叫）

    /// 從 Data 解析所有潛水記錄
    static func parseCSVData(_ data: Data) throws -> [DiveLog] {
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            throw DiveLogImportError.corruptedData("CSV 無法解碼為 UTF-8")
        }
        let rows = parseRFC4180(text)
        // 過濾 header 行（以 "#" 開頭的第一欄）及空行
        let dataRows = rows.filter { row in
            guard let first = row.first else { return false }
            return !first.hasPrefix("#") && !row.allSatisfy({ $0.isEmpty })
        }
        var dives: [DiveLog] = []
        for row in dataRows {
            if let dive = buildDiveLog(from: row) {
                dives.append(dive)
            }
        }
        if dives.isEmpty && !dataRows.isEmpty {
            throw DiveLogImportError.parsingFailed("CSV 無法解析任何有效潛水記錄")
        }
        return dives
    }

    // MARK: - RFC 4180 CSV 解析器

    /// RFC 4180 相容的 CSV 解析：支援多行 quoted fields 及 "" 轉義
    ///
    /// Swift 的 Array(String) 會將 \r\n 合併為單一 grapheme cluster，
    /// 導致 switch case "\r" 無法命中。
    /// 解法：解析前先正規化換行（\r\n 和 \r → \n），switch 只需處理 \n。
    static func parseRFC4180(_ text: String) -> [[String]] {
        // 正規化換行符號（\r\n 必須先於 \r 替換，避免重複替換）
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r",   with: "\n")

        var rows: [[String]] = []
        var fields: [String] = []
        var current: [Character] = []
        var inQuotes = false
        let chars = Array(normalized)
        var i = 0

        while i < chars.count {
            let ch = chars[i]
            if inQuotes {
                if ch == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        // "" → 轉義的雙引號
                        current.append("\"")
                        i += 2
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(ch)
                }
            } else {
                switch ch {
                case "\"":
                    inQuotes = true
                case ",":
                    fields.append(String(current))
                    current = []
                case "\n":
                    fields.append(String(current))
                    rows.append(fields)
                    fields = []
                    current = []
                default:
                    current.append(ch)
                }
            }
            i += 1
        }
        // 末尾殘留的欄位 / 行
        if !fields.isEmpty || !current.isEmpty {
            fields.append(String(current))
            if !fields.allSatisfy({ $0.isEmpty }) {
                rows.append(fields)
            }
        }
        return rows
    }

    // MARK: - 從 CSV row 建構 DiveLog

    /// 欄位對應：0=Nr, 1=date, 2=time, 3=duration, 4=maxdepth,
    ///           5=avgdepth, 6=buddy, 7=suit, 8=notes
    static func buildDiveLog(from row: [String]) -> DiveLog? {
        guard row.count >= 5 else { return nil }

        // 日期 + 時間
        let dateStr = row[1].trimmingCharacters(in: .whitespaces)
        let timeStr = row.count > 2 ? row[2].trimmingCharacters(in: .whitespaces) : "0:00"
        guard let dateTime = parseDateTime(date: dateStr, time: timeStr) else { return nil }

        // duration: MM:SS → seconds（注意：非 HH:MM）
        let durationStr = row.count > 3 ? row[3].trimmingCharacters(in: .whitespaces) : "0:00"
        let durationSec = parseDurationMMSS(durationStr)
        guard durationSec > 0 else { return nil }

        // maxdepth（公尺）
        let depthStr = row[4].trimmingCharacters(in: .whitespaces)
        guard let maxDepth = Double(depthStr), maxDepth >= 0 else { return nil }

        // avgdepth（第 5 欄）、buddy（第 6 欄）、suit（第 7 欄）、notes（第 8 欄）
        let avgDepthStr = row.count > 5 ? row[5].trimmingCharacters(in: .whitespaces) : ""
        let buddy = row.count > 6 ? row[6].trimmingCharacters(in: .whitespaces) : ""
        let suit  = row.count > 7 ? row[7].trimmingCharacters(in: .whitespaces) : ""
        let notes = row.count > 8 ? row[8] : ""

        let dive = DiveLog(
            dateTime: dateTime,
            location: "",
            maxDepth: maxDepth,
            diveTimeSeconds: durationSec
            // gasMixJSON 預設 "\"air\""，waterTemperature 預設 15.0
        )

        // 防寒衣：從 "wet, 3mm" / "3mm" 提取數字
        if !suit.isEmpty {
            let digits = suit.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if !digits.isEmpty { dive.wetsuitThickness = digits }
        }

        dive.notes = notes

        if let avg = Double(avgDepthStr), avg > 0 { dive.avgDepth = avg }
        var extras: [(String, String)] = []
        if !buddy.isEmpty { extras.append(("buddy", buddy)) }
        dive.importExtrasJSON = buildImportExtrasJSON(extras)

        dive.sourceFormat = "csv"
        return dive
    }

    // MARK: - 日期時間解析

    /// 解析 `M/D/YY` 或 `M/D/YYYY` + `HH:MM`，回傳 UTC Date
    /// NOTE: 僅支援 Subsurface 標準匯出格式（斜線分隔，月份在前）。
    /// 不支援歐洲格式（DD.MM.YYYY）或 ISO 格式（YYYY-MM-DD）。
    static func parseDateTime(date: String, time: String) -> Date? {
        let dp = date.split(separator: "/").map(String.init)
        guard dp.count == 3,
              let month = Int(dp[0]),
              let day   = Int(dp[1]),
              var year  = Int(dp[2]) else { return nil }
        if year < 100 { year += 2000 }

        let tp = time.split(separator: ":").map(String.init)
        let hour   = tp.count >= 1 ? (Int(tp[0]) ?? 0) : 0
        let minute = tp.count >= 2 ? (Int(tp[1]) ?? 0) : 0

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute; comps.second = 0
        return cal.date(from: comps)
    }

    /// 解析 `MM:SS` 或 `HH:MM:SS` 格式 → 秒數（Subsurface CSV duration）
    static func parseDurationMMSS(_ str: String) -> Int {
        let parts = str.split(separator: ":").map(String.init)
        switch parts.count {
        case 2:  // MM:SS
            guard let minutes = Int(parts[0]),
                  let seconds = Int(parts[1]) else { return 0 }
            return minutes * 60 + seconds
        case 3:  // HH:MM:SS（超過 1 小時的潛水）
            guard let hours   = Int(parts[0]),
                  let minutes = Int(parts[1]),
                  let seconds = Int(parts[2]) else { return 0 }
            return hours * 3600 + minutes * 60 + seconds
        default:
            return 0
        }
    }
}

/// Garmin Descent 解析器 — ANT+ FIT 格式（roznet/FitFileParser SPM）
///
/// 支援 Garmin Descent 系列手錶匯出的 .fit 檔案。
/// 依賴 roznet/FitFileParser（https://github.com/roznet/FitFileParser）
/// 該函式庫封裝 Garmin 官方 C SDK（FitSDK 21.115），支援所有官方訊息類型。
///
/// 解析策略（強型別 FitFileParser API，零 raw byte offset 運算）：
///   - session (GMN 18)       → start_time, total_elapsed_time
///   - dive_summary (GMN 268) → max_depth
///   - dive_gas (GMN 269)     → oxygen_content, helium_content → gasMixJSON
///
/// scale 換算由 FitFileParser 自動套用（官方 Profile.xlsx）：
///   - total_elapsed_time: raw ms → seconds（÷1000）
///   - max_depth: raw mm → metres（÷1000）
///
/// 測試驗證（Python binary 分析確認）：
///   - 2018-08-11-09-56-30.fit → maxDepth=27.022m, 3514s, start 07:56:30 UTC
///   - 2018-08-11-14-11-36.fit → maxDepth=20.628m, 3929s, start 12:11:36 UTC
///   - 2018-08-13-13-48-26.fit → maxDepth=15.230m, 4145s, start 11:48:26 UTC
struct GarminDescentParser: DiveLogImporter {

    let format = DiveLogFormat.garmin

    // MARK: - 常數（唯一的 Data 存取：magic bytes 驗證，非 parser 邏輯）

    private static let fitMinHeaderSize = 14
    // FIT magic bytes ".FIT" at offset 8
    private static let magic0: UInt8 = 0x2E  // '.'
    private static let magic1: UInt8 = 0x46  // 'F'
    private static let magic2: UInt8 = 0x49  // 'I'
    private static let magic3: UInt8 = 0x54  // 'T'

    // MARK: - DiveLogImporter

    func canHandle(filePath: String) -> Bool {
        guard filePath.lowercased().hasSuffix(".fit") else { return false }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath),
                                   options: .mappedIfSafe),
              data.count >= 12 else { return false }
        return hasFITMagic(data)
    }

    func validateContent(_ data: Data) -> Bool {
        guard data.count >= 12 else { return false }
        return hasFITMagic(data)
    }

    func parse(from filePath: String) throws -> [DiveLog] {

        // ── 1. 檔案存在性 ──────────────────────────────────────────────
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw DiveLogImportError.fileNotFound(filePath)
        }

        // ── 2. 讀取資料 + 長度驗證 ─────────────────────────────────────
        let url = URL(fileURLWithPath: filePath)
        guard let rawData = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            throw DiveLogImportError.corruptedData("無法讀取 FIT 檔案")
        }
        guard rawData.count >= Self.fitMinHeaderSize else {
            throw DiveLogImportError.corruptedData(
                "FIT 檔案過短（\(rawData.count) bytes，至少需 \(Self.fitMinHeaderSize) bytes）"
            )
        }

        // ── 3. Magic bytes 驗證（Data 下標，非 pointer arithmetic）───────
        guard hasFITMagic(rawData) else {
            throw DiveLogImportError.invalidFormat("非標準 FIT 格式（magic bytes 不符）")
        }

        // ── 4. FitFileParser 解析（.generic 模式解析所有 mesg_num，含 268/269）─
        // .fast 模式僅解析 fit_example.h 定義的訊息，不含 dive_summary / dive_gas
        let fitFile = FitFile(data: rawData, parsingType: .generic)

        // ── 5. 取出各訊息清單 ──────────────────────────────────────────
        // FitMessageType aka UInt16；dive-specific mesg_num 無具名常數，使用 raw value
        let sessions:      [FitMessage] = fitFile.messages(forMessageType: .session)
        let diveSummaries: [FitMessage] = fitFile.messages(forMessageType: 268)  // dive_summary GMN 268
        let diveGases:     [FitMessage] = fitFile.messages(forMessageType: 269)  // dive_gas     GMN 269
        let recordMessages:[FitMessage] = fitFile.messages(forMessageType: .record) // GMN 20

        guard !sessions.isEmpty else {
            throw DiveLogImportError.parsingFailed("FIT 檔案無 session 訊息（GMN 18 不存在）")
        }

        // ── 6. 逐 session 建構 DiveLog ────────────────────────────────
        var results: [DiveLog] = []

        for (index, session) in sessions.enumerated() {

            // start_time → Date（FitFileParser 自動轉換 FIT epoch → Unix）
            guard let startDate = session.interpretedField(key: "start_time")?.time else {
                throw DiveLogImportError.parsingFailed("session[\(index)] 缺少 start_time")
            }

            // total_elapsed_time → 秒（scale=1000 已由 FitFileParser 套用，回傳值單位為秒）
            guard let elapsedSecs = session.interpretedField(
                key: "total_elapsed_time")?.valueUnit?.value else {
                throw DiveLogImportError.parsingFailed(
                    "session[\(index)] 缺少 total_elapsed_time")
            }
            // Int() 截斷對應 FIT SDK integer division（raw ms / 1000）
            // 3514.748s → Int(3514.748) = 3514，與測試期望值一致
            let diveTimeSeconds = Int(elapsedSecs)

            // max_depth → 公尺（scale=1000 已由 FitFileParser 套用）
            // 優先 dive_summary，fallback session.max_depth
            let maxDepth: Double
            let summary = diveSummaries.indices.contains(index)
                ? diveSummaries[index]
                : diveSummaries.first
            if let d = summary?.interpretedField(key: "max_depth")?.valueUnit?.value {
                maxDepth = d
            } else if let d = session.interpretedField(key: "max_depth")?.valueUnit?.value {
                maxDepth = d
            } else {
                throw DiveLogImportError.parsingFailed(
                    "session[\(index)] 找不到 max_depth（dive_summary GMN 268 缺失）")
            }

            // gasMixJSON：取第一個 dive_gas；無則預設 Air
            let gasMixJSON = buildGasMixJSON(from: diveGases.first)

            // 平均深度：優先 dive_summary avg_depth，次選 session avg_depth
            let avgDepth: Double? = summary?.interpretedField(key: "avg_depth")?.valueUnit?.value
                ?? session.interpretedField(key: "avg_depth")?.valueUnit?.value

            // 水溫：優先 session avg_temperature；其次從 record messages 取平均值；最後預設 15.0°C
            let waterTemperature: Double
            if let temp = session.interpretedField(key: "avg_temperature")?.valueUnit?.value {
                waterTemperature = temp
            } else if let avg = extractAvgTemperature(from: recordMessages) {
                waterTemperature = avg
            } else {
                waterTemperature = 15.0
            }

            // GPS：session start_position_lat / start_position_long
            // FitFileParser 以 degrees 回傳（已套用 semicircle→degree 換算）
            // 防禦性檢查：若值超出 degrees 範圍則視為 semicircles 並換算
            let rawLat = session.interpretedField(key: "start_position_lat")?.valueUnit?.value
            let rawLon = session.interpretedField(key: "start_position_long")?.valueUnit?.value

            let dive = DiveLog(
                dateTime: startDate,
                location: "",
                maxDepth: maxDepth,
                diveTimeSeconds: diveTimeSeconds,
                gasMixJSON: gasMixJSON,
                waterTemperature: waterTemperature
            )
            dive.sourceFormat = "garmin"

            if let avg = avgDepth { dive.avgDepth = avg }

            // 深度剖面樣本：從 record messages 取 depth + timestamp
            dive.profileSamplesJSON = buildProfileSamplesJSON(from: recordMessages, startDate: startDate)

            // 設定 GPS 座標
            // 單位換算：FIT 規格存 semicircles（整數），FitFileParser 可能已換算成 degrees
            //   abs > 360 → 尚未換算 → 乘以 semicircle scale
            // 格式約束（非值過濾）：緯度必須在 ±90°、經度在 ±180° 內，
            //   超出此範圍代表資料損壞或換算失敗，物理上不存在這樣的座標
            if let rawLat, let rawLon {
                let semicircleScale = 180.0 / pow(2.0, 31.0)
                let lat = abs(rawLat) > 360 ? rawLat * semicircleScale : rawLat
                let lon = abs(rawLon) > 360 ? rawLon * semicircleScale : rawLon
                if abs(lat) <= 90, abs(lon) <= 180 {
                    dive.latitude  = lat
                    dive.longitude = lon
                }
            }

            results.append(dive)
        }

        return results
    }

    // MARK: - 私有輔助

    /// 驗證 FIT magic bytes ".FIT"（offset 8–11）
    private func hasFITMagic(_ data: Data) -> Bool {
        data[8] == Self.magic0 && data[9]  == Self.magic1
            && data[10] == Self.magic2 && data[11] == Self.magic3
    }

    /// record messages 水溫平均值（Garmin Descent 裝置存於 record 而非 session）
    private func extractAvgTemperature(from records: [FitMessage]) -> Double? {
        let temps = records.compactMap {
            $0.interpretedField(key: "temperature")?.valueUnit?.value
        }
        guard !temps.isEmpty else { return nil }
        return temps.reduce(0, +) / Double(temps.count)
    }

    /// record messages → profileSamplesJSON
    /// 最多取 300 點（間隔取樣），避免 JSON 過大
    /// v1.1 #4：record 有 temperature 欄位時一併寫入 w（水溫），無則省略（optional additive）
    private func buildProfileSamplesJSON(from records: [FitMessage], startDate: Date) -> String {
        var samples: [(t: Double, d: Double, w: Double?)] = []
        for record in records {
            guard let ts    = record.interpretedField(key: "timestamp")?.time,
                  let depth = record.interpretedField(key: "depth")?.valueUnit?.value,
                  depth >= 0 else { continue }
            let t = ts.timeIntervalSince(startDate)
            guard t >= 0 else { continue }
            let temp = record.interpretedField(key: "temperature")?.valueUnit?.value
            samples.append((t: t, d: depth, w: temp))
        }
        guard !samples.isEmpty else { return "[]" }
        // 間隔取樣：步長 = max(1, count / 300)
        let step = max(1, samples.count / 300)
        let chosen = stride(from: 0, to: samples.count, by: step).map { samples[$0] }
        let json = "[" + chosen.map { s -> String in
            if let w = s.w {
                return String(format: "{\"t\":%.1f,\"d\":%.3f,\"w\":%.1f}", s.t, s.d, w)
            }
            return String(format: "{\"t\":%.1f,\"d\":%.3f}", s.t, s.d)
        }.joined(separator: ",") + "]"
        return json
    }

    /// 將 dive_gas 訊息轉換為 JD2 gasMixJSON 格式
    ///
    /// - Air:    O₂ ≈ 21%, He = 0  → `"air"`
    /// - Nitrox: O₂ > 21%, He = 0  → `{"nitrox":{"fO2":0.32}}`
    /// - Trimix: He > 0             → `{"trimix":{"fO2":0.21,"fHe":0.35}}`
    private func buildGasMixJSON(from message: FitMessage?) -> String {
        guard let msg = message else { return "\"air\"" }
        let o2Pct = msg.interpretedField(key: "oxygen_content")?.valueUnit?.value ?? 21.0
        let hePct = msg.interpretedField(key: "helium_content")?.valueUnit?.value ?? 0.0

        if hePct > 0 {
            return "{\"trimix\":{\"fO2\":\(String(format: "%.2f", o2Pct / 100.0))," +
                   "\"fHe\":\(String(format: "%.2f", hePct / 100.0))}}"
        } else if abs(o2Pct - 21.0) < 0.5 {
            return "\"air\""
        } else {
            return "{\"nitrox\":{\"fO2\":\(String(format: "%.2f", o2Pct / 100.0))}}"
        }
    }
}

/// Garmin Connect JSON 解析器 — v1.1 #12：FIT 二進位格式的替代路線
///
/// ⚠️ 格式假設（待真實匯出樣本回驗，port 自 JD2-Ultra 的驗證過參考實作）：
/// 依 Garmin Connect 網站/API 潛水活動匯出（activity JSON）的公開結構解析：
///   根 = 單一 activity 物件，或 activity 物件陣列
///   activity.activityId                     — 偵測特徵之一
///   activity.activityName                   — 地點/名稱 → location
///   activity.summaryDTO                     — 偵測特徵之一，欄位：
///     .startTimeGMT / .startTimeLocal       — ISO 8601
///     .duration                             — 秒（Double）
///     .maxDepth                             — 公尺
///     .averageDepth（可選）                 — 公尺 → avgDepth
///     .minTemperature / .waterTemperature   — °C（可選；缺失 → 15.0）
///     .startLatitude / .startLongitude      — degrees（可選）
///   activity.description（可選）            — 備註
///   activity.samples（可選，[{"t":秒,"d":公尺}]）— 深度剖面
///
/// 氣體：Connect 匯出 summary 無氣體資訊 → 一律預設 Air（使用者可事後編輯）。
/// 內容偵測含 "summaryDTO" 或 "activityId" 特徵，明確排除 "DeviceLog"，不會誤吞 Suunto JSON。
struct GarminConnectJSONParser: DiveLogImporter {

    let format = DiveLogFormat.garmin

    // MARK: - DiveLogImporter 協議

    /// 格式偵測：.json 副檔名 + 內容前 512 bytes 含 Garmin Connect 特徵
    func canHandle(filePath: String) -> Bool {
        let ext = (filePath as NSString).pathExtension.lowercased()
        guard ext == "json" else { return false }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath),
                                   options: .mappedIfSafe) else { return false }
        return validateContent(data)
    }

    func validateContent(_ data: Data) -> Bool {
        guard let head = String(data: data.prefix(512), encoding: .utf8) else { return false }
        // 不吞 Suunto：DeviceLog 特徵直接排除
        guard !head.contains("DeviceLog") else { return false }
        return head.contains("summaryDTO") || head.contains("activityId")
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
        return try Self.parseJSONData(data)
    }

    // MARK: - 靜態輔助（供單元測試直接呼叫）

    static func parseJSONData(_ data: Data) throws -> [DiveLog] {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw DiveLogImportError.parsingFailed("JSON 解析失敗", underlyingError: error)
        }

        // 根可為單一 activity 或陣列
        let activities: [[String: Any]]
        if let single = json as? [String: Any] {
            activities = [single]
        } else if let array = json as? [[String: Any]] {
            activities = array
        } else {
            throw DiveLogImportError.invalidFormat("非 Garmin Connect activity JSON 結構")
        }

        var results: [DiveLog] = []
        for activity in activities {
            if let dive = try buildDive(from: activity) {
                results.append(dive)
            }
        }
        guard !results.isEmpty else {
            throw DiveLogImportError.parsingFailed("找不到有效的潛水活動（缺 summaryDTO 或必要欄位）")
        }
        return results
    }

    // MARK: - 單筆組裝

    private static func buildDive(from activity: [String: Any]) throws -> DiveLog? {
        // summaryDTO 或活動本體皆可承載欄位（防禦：兩層都查）
        let summary = (activity["summaryDTO"] as? [String: Any]) ?? activity

        // ── 開始時間（GMT 優先；local 次之）─────────────────────
        let timeStr = (summary["startTimeGMT"] as? String)
            ?? (summary["startTimeLocal"] as? String)
            ?? (activity["startTimeGMT"] as? String)
        guard let timeStr, let dateTime = parseGarminDate(timeStr) else { return nil }

        // ── 時長（秒）────────────────────────────────────────────
        guard let durationNum = summary["duration"] as? NSNumber else { return nil }
        let durationSec = Int(durationNum.doubleValue.rounded())
        guard durationSec > 0 else { return nil }

        // ── 最大深度（公尺）──────────────────────────────────────
        guard let depthNum = summary["maxDepth"] as? NSNumber else { return nil }
        let maxDepth = depthNum.doubleValue
        guard maxDepth >= 0 else { return nil }

        // ── 水溫（°C；缺失 → 15.0，同 FIT 路線預設）──────────────
        let waterTemp = (summary["minTemperature"] as? NSNumber)?.doubleValue
            ?? (summary["waterTemperature"] as? NSNumber)?.doubleValue
            ?? 15.0

        let dive = DiveLog(
            dateTime:         dateTime,
            location:         (activity["activityName"] as? String) ?? "",
            maxDepth:         maxDepth,
            diveTimeSeconds:  durationSec,
            gasMixJSON:       "\"air\"",     // Connect 匯出無氣體資訊
            waterTemperature: waterTemp
        )
        dive.sourceFormat = "garmin-json"

        // 平均深度（可選，v1.1 #8）
        if let avg = (summary["averageDepth"] as? NSNumber)?.doubleValue {
            dive.avgDepth = avg
        }

        // 備註（可選）
        if let desc = activity["description"] as? String, !desc.isEmpty {
            dive.notes = desc
        }

        // GPS（可選；格式約束：緯 ±90°、經 ±180°）
        if let lat = (summary["startLatitude"] as? NSNumber)?.doubleValue,
           let lon = (summary["startLongitude"] as? NSNumber)?.doubleValue,
           abs(lat) <= 90, abs(lon) <= 180 {
            dive.latitude  = lat
            dive.longitude = lon
        }

        // 深度剖面（可選，自家擴充鍵 samples: [{"t":秒,"d":公尺}]）
        if let samples = activity["samples"] as? [[String: Any]] {
            var profile: [DiveProfileSample] = []
            for s in samples {
                if let t = (s["t"] as? NSNumber)?.doubleValue,
                   let d = (s["d"] as? NSNumber)?.doubleValue,
                   t >= 0, d >= 0 {
                    profile.append(DiveProfileSample(timeSeconds: t, depthMeters: d))
                }
            }
            profile.sort { $0.timeSeconds < $1.timeSeconds }
            if !profile.isEmpty,
               let jsonData = try? JSONEncoder().encode(profile),
               let jsonStr  = String(data: jsonData, encoding: .utf8) {
                dive.profileSamplesJSON = jsonStr
            }
        }

        return dive
    }

    // MARK: - 日期解析

    /// Garmin Connect 時間格式："2023-08-17T08:51:59.0"（無時區＝GMT）、
    /// 或標準 ISO 8601（含 Z / 毫秒）
    static func parseGarminDate(_ str: String) -> Date? {
        // 標準 ISO 8601（含/不含毫秒）
        let fracFmt = ISO8601DateFormatter()
        fracFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fracFmt.date(from: str) { return d }
        let stdFmt = ISO8601DateFormatter()
        stdFmt.formatOptions = [.withInternetDateTime]
        if let d = stdFmt.date(from: str) { return d }
        // Connect 無時區格式（視為 GMT）
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "GMT")
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.S"
        if let d = fmt.date(from: str) { return d }
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = fmt.date(from: str) { return d }
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return fmt.date(from: str)
    }
}

/// Subsurface XML 解析器 (Subsurface v3 XML, .ssrf / .xml)
///
/// 涵蓋所有透過 Subsurface 軟體匯出的品牌資料：
///   Suunto EON Core、Nautic、Ocean、Shearwater、Cressi、Mares 等
///
/// 測試驗證：
///   - suunto_eon_core_nitrox.xml  (Nitrox 32%, 無地點)
///   - suunto_nautic_sidemount.xml (Air, 有 GPS 地點, 備註)
///   - suunto_ocean_air.xml        (Air, 有備註)
struct SubsurfaceXMLParser: DiveLogImporter {

    let format = DiveLogFormat.subsurface

    // MARK: - DiveLogImporter 協議

    /// 格式偵測：
    ///   - .ssrf → Subsurface 專屬副檔名，直接接受
    ///   - .xml  → 需讀取內容確認含 program='subsurface'，避免誤判其他 XML 格式
    func canHandle(filePath: String) -> Bool {
        let ext = (filePath as NSString).pathExtension.lowercased()
        if ext == "ssrf" { return true }
        guard ext == "xml" else { return false }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath),
                                   options: .mappedIfSafe) else { return false }
        return validateContent(data)
    }

    /// 驗證為 Subsurface XML（檢查 divelog program='subsurface'）
    func validateContent(_ data: Data) -> Bool {
        guard let head = String(data: data.prefix(256), encoding: .utf8) else { return false }
        return head.contains("divelog") &&
               (head.contains("program='subsurface'") || head.contains("program=\"subsurface\""))
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
        return try SubsurfaceXMLParser.parseXMLData(data)
    }

    // MARK: - 靜態輔助（供單元測試直接呼叫）

    static func parseXMLData(_ data: Data) throws -> [DiveLog] {
        let delegate = SubsurfaceXMLDelegate()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = delegate
        xmlParser.shouldProcessNamespaces = false
        xmlParser.shouldReportNamespacePrefixes = false
        guard xmlParser.parse() else {
            let msg = xmlParser.parserError?.localizedDescription ?? "未知 XML 錯誤"
            throw DiveLogImportError.parsingFailed("Subsurface XML 解析失敗: \(msg)")
        }
        if let err = delegate.fatalError { throw DiveLogImportError.parsingFailed(err) }
        return delegate.buildDiveLogs()
    }
}

/// Suunto JSON 解析器 — Suunto app 匯出的 DeviceLog JSON 格式
///
/// 格式特徵：
///   - 根鍵 "DeviceLog"，含 "Header" 子物件與 "Samples" 陣列
///   - Header.DateTime：ISO 8601 含毫秒及時區偏移（如 2024-10-06T02:33:51.530+02:00）
///   - Header.Duration：浮點秒數 → 四捨五入取整
///   - Header.Depth.Max：最大深度（公尺）
///   - Header.Diving.Gases[0].Oxygen：O2 分率（0.21≈Air, 0.32=Nitrox 32%）；缺失 → Air
///   - Header.Notes：備註字串（可選）
///   - Samples[].Temperature：水溫（Kelvin）；min - 273.15 = 最低水溫（°C）
///
/// 測試驗證：
///   - suunto_eon_core_nitrox.json  (Nitrox 32%, Duration=3970s, MaxDepth=22.65m, Temp=29.10°C)
///   - suunto_nautic_sidemount.json (Air, Duration=2011s, MaxDepth=21.24m, Temp=9.19°C, Notes)
///   - suunto_ocean_air.json        (Air, Duration=3312s, MaxDepth=23.4m, Temp=28.96°C, Notes)
// AI-generated (Claude)
struct SuuntoJSONParser: DiveLogImporter {

    let format = DiveLogFormat.suunto

    // MARK: - DiveLogImporter 協議

    /// 格式偵測：.json 副檔名 + 內容前 256 bytes 含 "DeviceLog"
    func canHandle(filePath: String) -> Bool {
        let ext = (filePath as NSString).pathExtension.lowercased()
        guard ext == "json" else { return false }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath),
                                   options: .mappedIfSafe) else { return false }
        return validateContent(data)
    }

    /// 驗證：前 256 bytes 含 "DeviceLog" 字串
    func validateContent(_ data: Data) -> Bool {
        guard let head = String(data: data.prefix(256), encoding: .utf8) else { return false }
        return head.contains("DeviceLog")
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
        return try SuuntoJSONParser.parseJSONData(data)
    }

    // MARK: - 靜態輔助（供單元測試直接呼叫）

    /// 從 Data 解析一筆 Suunto DeviceLog 潛水記錄
    static func parseJSONData(_ data: Data) throws -> [DiveLog] {
        guard !data.isEmpty else {
            throw DiveLogImportError.corruptedData("Suunto JSON 資料為空")
        }
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw DiveLogImportError.parsingFailed("JSON 解析失敗", underlyingError: error)
        }
        guard let root      = json as? [String: Any],
              let deviceLog = root["DeviceLog"] as? [String: Any],
              let header    = deviceLog["Header"] as? [String: Any]
        else {
            throw DiveLogImportError.invalidFormat("缺少 DeviceLog.Header 結構")
        }

        // ── DateTime ─────────────────────────────────────────────
        guard let dateTimeStr = header["DateTime"] as? String,
              let dateTime    = SuuntoJSONParser.parseISO8601(dateTimeStr)
        else {
            throw DiveLogImportError.parsingFailed("無法解析 Header.DateTime")
        }

        // ── Duration（浮點或整數秒數 → Int）─────────────────────
        guard let durationNum = header["Duration"] as? NSNumber else {
            throw DiveLogImportError.parsingFailed("缺少 Header.Duration")
        }
        let durationSec = Int(durationNum.doubleValue.rounded())
        guard durationSec > 0 else {
            throw DiveLogImportError.parsingFailed("Header.Duration 無效（≤ 0）")
        }

        // ── Depth.Max（公尺）────────────────────────────────────
        guard let depthDict = header["Depth"] as? [String: Any],
              let depthNum  = depthDict["Max"] as? NSNumber
        else {
            throw DiveLogImportError.parsingFailed("缺少 Header.Depth.Max")
        }
        let maxDepth = depthNum.doubleValue

        // ── 氣體（O2 分率；缺失 → 預設空氣）────────────────────
        let fO2: Double
        if let diving   = header["Diving"] as? [String: Any],
           let gases    = diving["Gases"] as? [[String: Any]],
           let firstGas = gases.first,
           let oxyNum   = firstGas["Oxygen"] as? NSNumber {
            fO2 = oxyNum.doubleValue
        } else {
            fO2 = 0.21
        }
        let gasMixJSON = SuuntoJSONParser.makeGasMixJSON(fO2: fO2)

        // ── 水溫 + 剖面樣本（Samples 陣列）────────────────────────
        var waterTemp = 20.0
        var profileSamples: [DiveProfileSample] = []
        if let samples = deviceLog["Samples"] as? [[String: Any]] {
            // 水溫：最低 Kelvin 值 → Celsius
            let kelvins = samples.compactMap { ($0["Temperature"] as? NSNumber)?.doubleValue }
            if let minK = kelvins.min() {
                waterTemp = (minK - 273.15).rounded(toDecimalPlaces: 2)
            }
            // 剖面：Depth（公尺）+ Time（秒）+ Temperature（v1.1 #4：Kelvin → Celsius，optional）
            for s in samples {
                if let depthNum = s["Depth"] as? NSNumber,
                   let timeNum  = s["Time"]  as? NSNumber {
                    let d = depthNum.doubleValue
                    let t = timeNum.doubleValue
                    let w = (s["Temperature"] as? NSNumber).map { $0.doubleValue - 273.15 }
                    if t >= 0, d >= 0 {
                        profileSamples.append(
                            DiveProfileSample(timeSeconds: t, depthMeters: d, waterTemp: w)
                        )
                    }
                }
            }
            profileSamples.sort { $0.timeSeconds < $1.timeSeconds }
        }

        // ── 建立 DiveLog ─────────────────────────────────────────
        let dive = DiveLog(
            dateTime:         dateTime,
            location:         "",
            maxDepth:         maxDepth,
            diveTimeSeconds:  durationSec,
            gasMixJSON:       gasMixJSON,
            waterTemperature: waterTemp
        )
        dive.sourceFormat = "suunto-json"

        if let notes = header["Notes"] as? String, !notes.isEmpty {
            dive.notes = notes
        }

        // ── 深度剖面 ─────────────────────────────────────────────
        if !profileSamples.isEmpty,
           let jsonData = try? JSONEncoder().encode(profileSamples),
           let jsonStr  = String(data: jsonData, encoding: .utf8) {
            dive.profileSamplesJSON = jsonStr
        }

        return [dive]
    }

    // MARK: - 私有輔助

    /// ISO 8601 解析（優先嘗試含毫秒格式，其次標準格式）
    static func parseISO8601(_ str: String) -> Date? {
        let fracFmt = ISO8601DateFormatter()
        fracFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fracFmt.date(from: str) { return d }
        let stdFmt = ISO8601DateFormatter()
        stdFmt.formatOptions = [.withInternetDateTime]
        return stdFmt.date(from: str)
    }

    /// fO2 → gasMixJSON（與其他解析器格式一致）
    /// 使用 "%.4g" 格式化浮點數，確保跨平台輸出一致（避免 Swift 插值的不確定精度）
    private static func makeGasMixJSON(fO2: Double) -> String {
        if abs(fO2 - 0.21) < 0.005 {
            return "\"air\""
        }
        return "{\"nitrox\":{\"fO2\":\(String(format: "%.4g", fO2))}}"
    }
}

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

// ============================================================
// MARK: - SeabearCSVParser
// ============================================================

/// Seabear CSV 解析器 — Seabear Diving Technology HUDC/T1 格式
///
/// 格式特徵：
///   - 開頭為 /* ... */ 版權區塊（可選）
///   - 接著 // 開頭的 metadata 行：
///       //SEABEAR DIVING TECHNOLOGY
///       //DIVE NR: 26
///       //2014.07.10 08:46:10
///       //Setting: 0 GF: 30/80 O2: 21%
///   - 資料區塊：
///       Time;Depth;NDT;TTS;Ceiling;Temperature;Tank pressure  ← 標題行
///       1;1;1;1;1;1;1                                          ← 單位縮放行（skip）
///       0;1;2;3;4;5;6                                          ← 欄位索引行（skip）
///       （空行）
///       1;1.2;200;0;0;25;199                                   ← 第一筆資料
///   - Time 單位：秒；Depth 單位：公尺；Temperature 單位：°C
///
/// 測試驗證：
///   - TestDiveSeabearHUDC.csv (2014-07-10 08:46:10Z, maxDepth=40.0m, diveTime=452s, temp=25.0°C, Air)
// AI-generated (Claude)
struct SeabearCSVParser: DiveLogImporter {

    let format = DiveLogFormat.seabear

    // MARK: - DiveLogImporter 協議

    /// 格式偵測：.csv 副檔名 + 前 512 bytes 含 "SEABEAR"
    func canHandle(filePath: String) -> Bool {
        guard (filePath as NSString).pathExtension.lowercased() == "csv" else { return false }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath),
                                   options: .mappedIfSafe),
              let head = String(data: data.prefix(512), encoding: .utf8) else { return false }
        return head.contains("SEABEAR")
    }

    func validateContent(_ data: Data) -> Bool {
        guard let head = String(data: data.prefix(512), encoding: .utf8) else { return false }
        return head.contains("SEABEAR")
    }

    func parse(from filePath: String) throws -> [DiveLog] {

        // ── 1. 讀取檔案 ──────────────────────────────────────────────
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw DiveLogImportError.fileNotFound(filePath)
        }
        guard let rawContent = try? String(contentsOfFile: filePath, encoding: .utf8),
              !rawContent.isEmpty else {
            throw DiveLogImportError.emptyFile
        }
        guard rawContent.contains("SEABEAR") else {
            throw DiveLogImportError.invalidFormat("非 Seabear CSV 格式（缺少 SEABEAR 標識）")
        }

        let lines = rawContent.components(separatedBy: .newlines)

        // ── 2. 解析 metadata 區塊（// 開頭的行）──────────────────────
        var dateTime: Date?
        var gasFO2: Double = 0.21      // 預設 Air

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("//") else { continue }
            let meta = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)

            // 日期時間：形如 "2014.07.10 08:46:10"
            if dateTime == nil, let dt = parseSeabearDateTime(meta) {
                dateTime = dt
            }

            // 氣體：形如 "Setting: 0 GF: 30/80 O2: 21%"
            if meta.hasPrefix("Setting:"), let fO2 = parseSeabearO2(meta) {
                gasFO2 = fO2
            }
        }

        guard let dt = dateTime else {
            throw DiveLogImportError.parsingFailed("Seabear CSV 缺少日期時間行")
        }

        // ── 3. 解析資料行 ────────────────────────────────────────────
        // 欄位：Time(s); Depth(m); NDT; TTS; Ceiling; Temperature(°C); TankPressure(bar)
        var maxDepth: Double = 0.0
        var lastTime: Int    = 0
        var firstTemp: Double?
        var inDataSection    = false
        var skipCount        = 0     // 標題行後跳過 2 行（單位行 + 索引行）

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 略過空行與 comment 行
            guard !trimmed.isEmpty,
                  !trimmed.hasPrefix("//"),
                  !trimmed.hasPrefix("/*"),
                  !trimmed.hasPrefix(" *"),
                  !trimmed.hasPrefix("*") else { continue }

            // 標題行（含 "Time" 或 "Depth"）
            if !inDataSection && (trimmed.contains("Time") || trimmed.contains("Depth")) {
                inDataSection = true
                skipCount = 0
                continue
            }
            guard inDataSection else { continue }

            // 跳過標題後的單位行（1;1;1;...）和索引行（0;1;2;...）
            if skipCount < 2 {
                skipCount += 1
                continue
            }

            // 解析資料行：分號分隔，至少 6 欄
            let parts = trimmed.components(separatedBy: ";")
            guard parts.count >= 6,
                  let timeSec = Int(parts[0].trimmingCharacters(in: .whitespaces)),
                  let depth   = Double(parts[1].trimmingCharacters(in: .whitespaces)),
                  let temp    = Double(parts[5].trimmingCharacters(in: .whitespaces)) else {
                continue
            }

            if depth > maxDepth { maxDepth = depth }
            lastTime = timeSec
            if firstTemp == nil { firstTemp = temp }
        }

        guard maxDepth > 0, lastTime > 0 else {
            throw DiveLogImportError.parsingFailed("Seabear CSV 無有效潛水資料（depth/time 均為 0）")
        }

        let gasMixJSON = SeabearCSVParser.buildGasMixJSON(fO2: gasFO2)

        let dive = DiveLog(
            dateTime:         dt,
            location:         "",
            maxDepth:         maxDepth,
            diveTimeSeconds:  lastTime,
            gasMixJSON:       gasMixJSON,
            waterTemperature: firstTemp ?? 20.0
        )
        dive.sourceFormat = "seabear"

        return [dive]
    }

    // MARK: - 私有輔助

    /// 解析 Seabear 日期時間格式："2014.07.10 08:46:10"（UTC）
    private func parseSeabearDateTime(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd HH:mm:ss"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.date(from: s)
    }

    /// 從 "Setting: 0 GF: 30/80 O2: 21%" 解析 O2 百分比 → fO2
    private func parseSeabearO2(_ s: String) -> Double? {
        guard let range = s.range(of: "O2:") else { return nil }
        let after = String(s[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        let numStr = after.components(separatedBy: CharacterSet(charactersIn: " %\t")).first ?? ""
        guard let pct = Double(numStr), pct > 0 else { return nil }
        return pct / 100.0
    }

    /// 建立 gasMixJSON 字串（使用 "%.4g" 確保浮點輸出一致）
    private static func buildGasMixJSON(fO2: Double) -> String {
        if abs(fO2 - 0.21) < 0.005 { return "\"air\"" }
        return "{\"nitrox\":{\"fO2\":\(String(format: "%.4g", fO2))}}"
    }
}

// ============================================================
// MARK: - UDDF 私有實現（XML 狀態機 + 資料結構）
// ============================================================

// MARK: - XML 委託解析器

/// UDDF XML 狀態機
///
/// 解析優先順序：
///   1. `<divesite>` → 建立 siteId → UDDFSite 字典
///   2. `<gasdefinitions>` → 建立 mixId → UDDFGasMixData 字典
///   3. `<profiledata>/<repetitiongroup>/<dive>` → 解析各次潛水
///
/// 地點連結：
///   `<informationbeforedive>/<link ref="siteId"/>` 對應 sites[siteId]
///
/// 氣體連結（開路）：
///   `<tankdata>/<link ref="mixId"/>` → 第一個有效 mixId
///
/// 氣體連結（CCR）：
///   `<samples>/<waypoint>/<switchmix ref="mixId"/>` → 第一個出現的 mixId
private final class UDDFXMLDelegate: NSObject, XMLParserDelegate {

    // MARK: 解析結果

    private var sites:     [String: UDDFSite]       = [:]
    private var gasMixes:  [String: UDDFGasMixData] = [:]
    private var parsedDives: [UDDFParsedDive]        = []

    /// 是否曾出現過 <dive> 元素（用於區分「空檔案」和「有結構但無有效潛水」）
    private(set) var hadDiveElements = false

    /// XML 解析器層級的致命錯誤
    private(set) var fatalError: String?

    // MARK: 解析狀態

    private var currentText = ""

    // ── 地點 ──────────────────────────────────────────────────
    private var inDiveSite      = false
    private var inSiteBlock     = false   // 目前在 <site id="..."> 內
    private var inSiteGeo       = false   // 目前在 <site>/<geography> 內
    private var currentSiteId:  String?
    private var currentSite =   UDDFSite()

    // ── 氣體定義 ──────────────────────────────────────────────
    private var inGasDefs       = false
    private var inMix           = false   // 目前在 <gasdefinitions>/<mix> 內
    private var currentMixId:   String?
    private var currentMix =    UDDFGasMixData()

    // ── 潛水 ──────────────────────────────────────────────────
    private var currentDive:    UDDFParsedDive?
    private var inInfoBefore    = false
    private var inInfoAfter     = false
    private var inTankData      = false
    private var inSamples       = false
    private var inWaypoint      = false
    private var inNotes         = false

    // 裝備（equipmentused divecomputer）
    private var inEquipmentUsed     = false
    private var inEquipmentDiveComp = false

    // waypoint 暫存（每個樣本點獨立收集後 append）
    private var waypointTime:  Double?
    private var waypointDepth: Double?

    // MARK: - XMLParserDelegate：開始元素

    // swiftlint:disable function_body_length cyclomatic_complexity
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentText = ""

        switch elementName {

        // ── 地點區塊 ──────────────────────────────────────────
        case "divesite":
            inDiveSite = true

        case "site" where inDiveSite:
            currentSiteId = attributeDict["id"]
            currentSite   = UDDFSite()
            inSiteBlock   = true

        case "geography" where inDiveSite:
            inSiteGeo = true

        // ── 氣體定義區塊 ──────────────────────────────────────
        case "gasdefinitions":
            inGasDefs = true

        case "mix" where inGasDefs:
            currentMixId = attributeDict["id"]
            currentMix   = UDDFGasMixData()
            inMix        = true

        // ── 潛水區塊 ──────────────────────────────────────────
        case "dive":
            hadDiveElements = true
            currentDive     = UDDFParsedDive()
            // 重置所有潛水子狀態（避免前一次未正常關閉的殘留）
            inInfoBefore        = false
            inInfoAfter         = false
            inTankData          = false
            inSamples           = false
            inWaypoint          = false
            inNotes             = false
            inEquipmentUsed     = false
            inEquipmentDiveComp = false

        case "informationbeforedive" where currentDive != nil:
            inInfoBefore = true

        case "informationafterdive" where currentDive != nil:
            inInfoAfter = true

        case "tankdata" where currentDive != nil:
            inTankData = true

        case "samples" where currentDive != nil:
            inSamples = true

        case "waypoint" where inSamples:
            inWaypoint = true

        case "notes" where inInfoAfter:
            inNotes = true

        case "equipmentused" where currentDive != nil:
            inEquipmentUsed = true

        case "divecomputer" where inEquipmentUsed:
            inEquipmentDiveComp = true

        // ── 連結元素（自閉合）──────────────────────────────────
        case "link":
            if let ref = attributeDict["ref"] {
                if inInfoBefore {
                    // siteRefs：稍後與 sites 字典交叉查詢
                    currentDive?.siteRefs.append(ref)
                } else if inTankData {
                    currentDive?.tankMixRefs.append(ref)
                }
            }

        // ── CCR 氣體切換（<switchmix ref="..."/>）──────────────
        case "switchmix":
            if inWaypoint, let ref = attributeDict["ref"] {
                // 僅記錄首次出現（代表初始氣體）
                if currentDive?.switchMixRef == nil {
                    currentDive?.switchMixRef = ref
                }
            }

        default:
            break
        }
    }

    // MARK: - XMLParserDelegate：文字內容

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    // MARK: - XMLParserDelegate：結束元素

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { currentText = "" }

        switch elementName {

        // ══ 地點 ═══════════════════════════════════════════════

        case "divesite":
            inDiveSite  = false
            inSiteBlock = false
            inSiteGeo   = false

        case "site" where inDiveSite:
            if let id = currentSiteId, !id.isEmpty {
                sites[id] = currentSite
            }
            currentSiteId = nil
            currentSite   = UDDFSite()
            inSiteBlock   = false
            inSiteGeo     = false

        case "geography" where inDiveSite:
            inSiteGeo = false

        case "name" where inSiteBlock && !inGasDefs:
            // <site>/<name>：地點顯示名稱
            // 條件 !inGasDefs 防止 <gasdefinitions> 中氣體名稱污染（理論上不會同時為真，保險起見）
            if !text.isEmpty { currentSite.name = text }

        case "name" where inEquipmentDiveComp:
            // <equipmentused>/<divecomputer>/<name>：裝置型號
            if currentDive?.deviceModel == nil, !text.isEmpty {
                currentDive?.deviceModel = text
            }

        case "serialnumber" where inEquipmentDiveComp:
            if !text.isEmpty { currentDive?.deviceSerial = text }

        case "firmware" where inEquipmentDiveComp:
            if !text.isEmpty { currentDive?.deviceFirmware = text }

        case "equipmentused":
            inEquipmentUsed     = false
            inEquipmentDiveComp = false

        case "divecomputer" where inEquipmentUsed:
            inEquipmentDiveComp = false

        case "location" where inSiteGeo:
            // <geography>/<location>：地理描述（備用，優先使用 <name>）
            if currentSite.geographyLocation == nil, !text.isEmpty {
                currentSite.geographyLocation = text
            }

        case "latitude" where inSiteGeo:
            currentSite.latitude = Double(text)

        case "longitude" where inSiteGeo:
            currentSite.longitude = Double(text)

        // ══ 氣體定義 ══════════════════════════════════════════

        case "gasdefinitions":
            inGasDefs = false

        case "mix" where inGasDefs:
            if let id = currentMixId, !id.isEmpty {
                gasMixes[id] = currentMix
            }
            currentMixId = nil
            currentMix   = UDDFGasMixData()
            inMix        = false

        case "o2" where inMix:
            currentMix.fO2 = Double(text) ?? 0.21

        case "he" where inMix:
            currentMix.fHe = Double(text) ?? 0.0

        // ══ 潛水 ══════════════════════════════════════════════

        case "dive":
            if let dive = currentDive {
                parsedDives.append(dive)
            }
            currentDive         = nil
            inInfoBefore        = false
            inInfoAfter         = false
            inTankData          = false
            inSamples           = false
            inWaypoint          = false
            inNotes             = false
            inEquipmentUsed     = false
            inEquipmentDiveComp = false

        case "informationbeforedive":
            inInfoBefore = false

        case "informationafterdive":
            inInfoAfter = false

        case "tankdata":
            inTankData = false

        case "samples":
            inSamples = false

        case "waypoint":
            // 若本樣本點同時有 time 和 depth，寫入剖面陣列
            if let t = waypointTime, let d = waypointDepth {
                currentDive?.samples.append((timeSeconds: t, depthMeters: d))
            }
            waypointTime  = nil
            waypointDepth = nil
            inWaypoint = false

        case "notes":
            inNotes = false

        // ── 必填欄位 ──────────────────────────────────────────
        case "divenumber" where inInfoBefore:
            currentDive?.diveNumber = Int(text)

        case "datetime" where inInfoBefore:
            if !text.isEmpty { currentDive?.dateTimeString = text }

        case "airtemperature" where inInfoBefore:
            // 單位換算：UDDF 規格為 Kelvin；部分廠商（如 ATMOS）輸出 Celsius
            // 啟發式格式偵測：值 < 100 → Celsius（正常氣溫不超過 99°C）→ 補回 Kelvin
            // 值的正確性由使用者自行保證
            if let raw = Double(text) {
                currentDive?.airTempKelvin = raw < 100 ? raw + 273.15 : raw
            }

        case "firstname" where inInfoBefore:
            // UDDF buddy 名字（<buddy><firstname>David</firstname>）
            if let name = currentDive?.buddy {
                currentDive?.buddy = "\(name) \(text)"  // 多位潛伴
            } else {
                currentDive?.buddy = text
            }

        case "greatestdepth" where inInfoAfter:
            currentDive?.greatestDepth = Double(text)

        case "averagedepth" where inInfoAfter:
            currentDive?.averageDepth = Double(text)

        case "diveduration" where inInfoAfter:
            // 值為秒數（可能帶小數，如 6240.0）
            currentDive?.diveDuration = Double(text)

        case "lowesttemperature" where inInfoAfter:
            // UDDF 最低水溫（Kelvin）
            currentDive?.lowestTempKelvin = Double(text)

        case "visibility" where inInfoAfter:
            // UDDF visibility 單位：公尺（整數，如 10）
            currentDive?.visibility = Double(text)

        case "leadquantity" where inInfoBefore:
            // 配重（kg）
            currentDive?.leadQuantityKg = Double(text)

        case "tankpressurebegin" where inTankData:
            // 單位換算：UDDF 規格為 Pascal；部分廠商直接輸出 bar（非標準）
            // 啟發式格式偵測：值 > 1000 → Pa → 換算成 bar（÷ 100,000）
            // 值的正確性由使用者自行保證
            if currentDive?.tankPressureBegin == nil, let raw = Double(text) {
                currentDive?.tankPressureBegin = raw > 1000 ? raw / 100_000.0 : raw
            }

        case "tankpressureend" where inTankData:
            // 單位換算：同 tankpressurebegin
            if currentDive?.tankPressureEnd == nil, let raw = Double(text) {
                currentDive?.tankPressureEnd = raw > 1000 ? raw / 100_000.0 : raw
            }

        case "tankvolume" where inTankData:
            // 單位換算：UDDF 規格為公升（L）；部分廠商（如 ATMOS）輸出 m³
            // 啟發式格式偵測：值 < 1 → m³ → 換算成公升（× 1000）
            // 值的正確性由使用者自行保證
            if currentDive?.tankVolumeLitres == nil, let raw = Double(text) {
                currentDive?.tankVolumeLitres = raw < 1 ? raw * 1000.0 : raw
            }

        // ── 取樣點時間 / 深度（剖面）────────────────────────
        case "divetime" where inWaypoint:
            // UDDF <divetime> 單位：秒（整數或帶小數）
            if let sec = Double(text) { waypointTime = sec }

        case "depth" where inWaypoint:
            // UDDF <depth> 單位：公尺
            if let m = Double(text) { waypointDepth = m }

        // ── 取樣點溫度（追蹤最低值）──────────────────────────
        case "temperature" where inWaypoint:
            if let kelvin = Double(text) {
                if let prev = currentDive?.waypointMinTempKelvin {
                    currentDive?.waypointMinTempKelvin = min(prev, kelvin)
                } else {
                    currentDive?.waypointMinTempKelvin = kelvin
                }
            }

        // ── 潛水備註 ──────────────────────────────────────────
        case "para" where inNotes:
            if !text.isEmpty { currentDive?.notes = text }

        default:
            break
        }
    }
    // swiftlint:enable function_body_length cyclomatic_complexity

    // MARK: - XMLParserDelegate：錯誤

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        fatalError = "XML 解析錯誤: \(parseError.localizedDescription)"
    }

    // MARK: - DiveLog 組裝

    /// 將解析結果轉換為 DiveLog 陣列
    ///
    /// 跳過條件：缺少日期、最大深度、潛水時間（如 UDDF 的 previous_dive 佔位記錄）
    func buildDiveLogs() -> [DiveLog] {
        // 支援含時區（ISO 8601）與不含時區兩種格式
        let isoFormatter   = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let isoFracFormatter = ISO8601DateFormatter()
        isoFracFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let noTZFormatter: DateFormatter = {
            let f = DateFormatter()
            f.locale     = Locale(identifier: "en_US_POSIX")
            f.timeZone   = TimeZone(secondsFromGMT: 0)
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            return f
        }()

        func parseDate(_ s: String) -> Date? {
            isoFormatter.date(from: s)
                ?? isoFracFormatter.date(from: s)
                ?? noTZFormatter.date(from: s)
        }

        var result: [DiveLog] = []

        for dive in parsedDives {

            // ── 必填欄位驗證（缺失則跳過）───────────────────
            guard
                let dateStr      = dive.dateTimeString,
                let date         = parseDate(dateStr),
                let depth        = dive.greatestDepth,
                let durationSec  = dive.diveDuration,
                depth  >= 0,
                durationSec > 0
            else { continue }

            // ── 地點解析 ─────────────────────────────────────
            // 注意：找不到地點時保持空字串，讓 View 層透過 String(localized:) 顯示本地化文字
            var locationName = ""
            var lat: Double?
            var lon: Double?

            // 優先：informationbeforedive 中的 link ref → 對應 sites 字典
            for ref in dive.siteRefs {
                if let site = sites[ref] {
                    locationName = site.name ?? site.geographyLocation ?? ""
                    lat = site.latitude
                    lon = site.longitude
                    break
                }
            }

            // 備用：若無 link ref 且僅有一個 site，直接使用
            if locationName.isEmpty, sites.count == 1,
               let sole = sites.values.first {
                locationName = sole.name ?? sole.geographyLocation ?? ""
                lat = sole.latitude
                lon = sole.longitude
            }

            // ── 氣體解析 ─────────────────────────────────────
            // 優先：tankdata（開路氣瓶）> switchmix（CCR）> 預設空氣
            let mixRef     = dive.tankMixRefs.first ?? dive.switchMixRef
            let gasMixJSON: String
            if let ref = mixRef, let mix = gasMixes[ref] {
                gasMixJSON = UDDFXMLDelegate.makeGasMixJSON(fO2: mix.fO2, fHe: mix.fHe)
            } else {
                gasMixJSON = "\"air\""
            }

            // ── 水溫解析（Kelvin → Celsius）─────────────────
            // 優先：informationafterdive lowesttemperature
            //     > 取樣點最低溫（waypoint minimum）
            //     > 水面氣溫（airtemperature，作為後備）
            //     > 預設 20°C
            let tempCelsius: Double
            if let k = dive.lowestTempKelvin {
                tempCelsius = (k - 273.15).rounded(toDecimalPlaces: 2)
            } else if let k = dive.waypointMinTempKelvin {
                tempCelsius = (k - 273.15).rounded(toDecimalPlaces: 2)
            } else if let k = dive.airTempKelvin {
                tempCelsius = (k - 273.15).rounded(toDecimalPlaces: 2)
            } else {
                tempCelsius = 20.0
            }

            // ── 建立 DiveLog ─────────────────────────────────
            let log = DiveLog(
                dateTime:         date,
                location:         locationName,
                maxDepth:         depth,
                diveTimeSeconds:  Int(durationSec),
                gasMixJSON:       gasMixJSON,
                waterTemperature: tempCelsius
            )

            log.sourceFormat = "UDDF"

            if let lat = lat, let lon = lon {
                log.latitude  = lat
                log.longitude = lon
            }

            // ── 能見度 ────────────────────────────────────────
            log.visibility = dive.visibility

            // ── 氣溫（Kelvin → Celsius，僅當與水溫來源不同時才存）──
            if dive.lowestTempKelvin == nil, dive.waypointMinTempKelvin == nil,
               let k = dive.airTempKelvin {
                // airTempKelvin 被用作水溫後備，此時不另存 airTemperature
            } else if let k = dive.airTempKelvin {
                log.airTemperature = (k - 273.15).rounded(toDecimalPlaces: 1)
            }

            // ── 裝備 ──────────────────────────────────────────
            log.weightTotal           = dive.leadQuantityKg
            log.cylinderStartPressure = dive.tankPressureBegin
            log.cylinderEndPressure   = dive.tankPressureEnd
            if let vol = dive.tankVolumeLitres {
                log.cylinderSize = String(format: "%.0fL", vol)
            }

            log.notes = dive.notes ?? ""

            if let avg = dive.averageDepth { log.avgDepth = avg }
            var extras: [(String, String)] = []
            if let b = dive.buddy, !b.isEmpty { extras.append(("buddy", b)) }
            if let nr = dive.diveNumber { extras.append(("diveNumber", String(nr))) }
            if let model = dive.deviceModel { extras.append(("deviceModel", model)) }
            if let sn = dive.deviceSerial { extras.append(("deviceSerial", sn)) }
            if let fw = dive.deviceFirmware { extras.append(("deviceFirmware", fw)) }
            log.importExtrasJSON = buildImportExtrasJSON(extras)

            // ── 深度剖面 ─────────────────────────────────────
            if !dive.samples.isEmpty {
                let sorted = dive.samples.sorted { $0.timeSeconds < $1.timeSeconds }
                let profileSamples = sorted.map {
                    DiveProfileSample(timeSeconds: $0.timeSeconds, depthMeters: $0.depthMeters)
                }
                if let jsonData = try? JSONEncoder().encode(profileSamples),
                   let jsonStr  = String(data: jsonData, encoding: .utf8) {
                    log.profileSamplesJSON = jsonStr
                }
            }

            result.append(log)
        }

        return result
    }

    // MARK: - 私有輔助

    /// 將 fO2/fHe 轉換為 DiveLog 使用的 gasMixJSON 字串
    ///
    /// 對應 GasMix Codable 編碼格式：
    ///   - air       → `"air"`
    ///   - nitrox    → `{"nitrox":{"fO2":0.32}}`
    ///   - trimix    → `{"trimix":{"fO2":0.16,"fHe":0.45}}`
    /// 使用 "%.4g" 確保浮點數跨平台輸出一致
    private static func makeGasMixJSON(fO2: Double, fHe: Double) -> String {
        if fHe > 0.001 {
            return "{\"trimix\":{\"fO2\":\(String(format: "%.4g", fO2)),\"fHe\":\(String(format: "%.4g", fHe))}}"
        } else if abs(fO2 - 0.21) < 0.005 {
            return "\"air\""
        } else {
            return "{\"nitrox\":{\"fO2\":\(String(format: "%.4g", fO2))}}"
        }
    }
}

// MARK: - UDDF 內部資料結構

/// 潛水地點（來自 UDDF `<divesite>/<site>`）
private struct UDDFSite {
    var name:              String?
    var geographyLocation: String?
    var latitude:          Double?
    var longitude:         Double?
}

/// 氣體定義（來自 UDDF `<gasdefinitions>/<mix>`）
private struct UDDFGasMixData {
    var fO2: Double = 0.21
    var fHe: Double = 0.0
}

/// 一次潛水的原始解析資料（尚未轉換為 DiveLog）
private struct UDDFParsedDive {
    var dateTimeString:        String?    // informationbeforedive datetime
    var diveNumber:            Int?
    var siteRefs:              [String] = []   // informationbeforedive link ref
    var tankMixRefs:           [String] = []   // tankdata link ref（開路）
    var switchMixRef:          String?         // waypoint switchmix ref（CCR）
    var greatestDepth:         Double?         // informationafterdive greatestdepth（公尺）
    var diveDuration:          Double?         // informationafterdive diveduration（秒）
    var lowestTempKelvin:      Double?         // informationafterdive lowesttemperature
    var airTempKelvin:         Double?         // informationbeforedive airtemperature（Kelvin）
    var waypointMinTempKelvin: Double?         // 取樣點最低溫（逐步 min 更新）
    var visibility:            Double?         // informationafterdive visibility（公尺）
    var leadQuantityKg:        Double?         // equipmentused leadquantity（配重 kg）
    var tankPressureBegin:     Double?         // tankdata tankpressurebegin（bar）
    var tankPressureEnd:       Double?         // tankdata tankpressureend（bar）
    var tankVolumeLitres:      Double?         // tankdata tankvolume（公升）
    var buddy:                 String?         // informationbeforedive buddy firstname
    var notes:                 String?
    var samples: [(timeSeconds: Double, depthMeters: Double)] = []   // 深度剖面樣本
    var averageDepth:          Double?         // informationafterdive averagedepth（公尺）
    var deviceModel:           String?         // equipmentused divecomputer name
    var deviceSerial:          String?         // equipmentused divecomputer serialnumber
    var deviceFirmware:        String?         // equipmentused divecomputer firmware
}

// MARK: - Double 精確度輔助

private extension Double {
    /// 四捨五入到指定小數位數
    func rounded(toDecimalPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}

// ============================================================
// MARK: - Subsurface XML 私有實現
// ============================================================

// MARK: - Subsurface XML Delegate

/// Subsurface XML v3 狀態機
///
/// 解析優先順序：
///   1. `<divesites>/<site uuid='' name='' gps='lat lon'>` → 地點字典
///   2. `<dives>/<dive date='' time='' duration='' divesiteid=''>` → 潛水記錄
///
/// 溫度優先順序：
///   `<divetemperature water='X.XX C'>` > `<divecomputer>/<temperature water='X.XX C'>`
///
/// 氣體：取第一個 `<cylinder o2='...'>` 的 fO2；無 o2 屬性 → Air
private final class SubsurfaceXMLDelegate: NSObject, XMLParserDelegate {

    // MARK: 解析結果

    private var sites:       [String: SubsurfaceSite]       = [:]   // uuid → site
    private var parsedDives: [SubsurfaceParsedDive]          = []

    private(set) var fatalError: String?

    // MARK: 解析狀態

    private var currentText       = ""
    private var inDiveSites       = false
    private var currentSiteUUID:  String?
    private var currentSite:      SubsurfaceSite?

    private var inDives           = false
    private var currentDive:      SubsurfaceParsedDive?
    private var inDiveComputer    = false
    private var inNotes           = false
    private var firstCylinderDone = false   // 只取第一個 cylinder

    // MARK: - XMLParserDelegate：開始元素

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attrs: [String: String] = [:]
    ) {
        currentText = ""

        switch elementName {

        // ── 地點區塊 ──────────────────────────────────────────
        case "divesites":
            inDiveSites = true

        case "site" where inDiveSites:
            currentSiteUUID = attrs["uuid"]
            var site = SubsurfaceSite()
            site.name = attrs["name"]
            if let gps = attrs["gps"] {
                // gps='48.332115 7.777142'  → lat lon
                let parts = gps.split(separator: " ").compactMap { Double($0) }
                if parts.count == 2 {
                    site.latitude  = parts[0]
                    site.longitude = parts[1]
                }
            }
            currentSite = site

        // ── 潛水區塊 ──────────────────────────────────────────
        case "dives":
            inDives = true

        case "dive" where inDives:
            var dive          = SubsurfaceParsedDive()
            dive.dateString   = attrs["date"]
            dive.timeString   = attrs["time"]
            dive.durationStr  = attrs["duration"]
            dive.diveSiteId   = attrs["divesiteid"]
            // visibility 與 rating 是 dive 的屬性（整數）
            if let visStr = attrs["visibility"], let v = Double(visStr) {
                dive.visibility = v
            }
            if let numStr = attrs["number"], let n = Int(numStr) {
                dive.diveNumber = n
            }
            if let t = attrs["tags"], !t.isEmpty {
                dive.tags = t
            }
            if let avgStr = attrs["avgdepth"] {
                let cleaned = avgStr.replacingOccurrences(of: "m", with: "")
                                    .trimmingCharacters(in: .whitespaces)
                dive.avgDepth = Double(cleaned)
            }
            currentDive       = dive
            firstCylinderDone = false

        case "cylinder" where currentDive != nil && !firstCylinderDone:
            firstCylinderDone = true
            // o2='32.0%' → fO2 = 0.32；無屬性 → nil（預設 air）
            if let o2Str = attrs["o2"] {
                let cleaned = o2Str.replacingOccurrences(of: "%", with: "")
                                    .trimmingCharacters(in: .whitespaces)
                currentDive?.cylinderFO2 = (Double(cleaned) ?? 21.0) / 100.0
            }
            // 氣瓶規格與壓力
            if let sizeStr = attrs["size"] { currentDive?.cylinderSizeL = parseMeters(sizeStr) }
            if let startStr = attrs["start"] { currentDive?.cylinderStartBar = parseBar(startStr) }
            if let endStr   = attrs["end"]   { currentDive?.cylinderEndBar   = parseBar(endStr) }

        // 潛水層級溫度（優先於電腦內溫度）
        case "divetemperature" where currentDive != nil:
            if let s = attrs["water"] { currentDive?.diveTemperature = parseTemp(s) }

        // 水面氣壓（barometric，用於高海拔計算）
        case "surface" where currentDive != nil:
            if let s = attrs["pressure"] { currentDive?.airPressureBar = parseBar(s) }

        case "divecomputer" where currentDive != nil:
            inDiveComputer = true
            if currentDive?.diveComputerModel == nil {
                currentDive?.diveComputerModel = attrs["model"]
            }
            if currentDive?.diveComputerSerial == nil {
                currentDive?.diveComputerSerial = attrs["deviceid"] ?? attrs["serial"]
            }

        case "depth" where inDiveComputer:
            if let s = attrs["max"] { currentDive?.maxDepth = parseMeters(s) }

        // 電腦層級溫度（次要來源）+ 氣溫
        case "temperature" where inDiveComputer:
            if let s = attrs["water"] { currentDive?.computerTemperature = parseTemp(s) }
            if let s = attrs["air"]   { currentDive?.airTemperatureCelsius = parseTemp(s) }

        // 配重
        case "weightsystem" where currentDive != nil:
            if let s = attrs["weight"] {
                // "4.536 kg" → Double
                let val = s.replacingOccurrences(of: "kg", with: "")
                           .trimmingCharacters(in: .whitespaces)
                if let kg = Double(val) {
                    let existing = currentDive?.weightKg ?? 0
                    currentDive?.weightKg = existing + kg
                }
            }

        case "sample" where currentDive != nil && inDiveComputer:
            // <sample time='0:10 min' depth='4.07 m' .../>
            if let timeStr  = attrs["time"],
               let depthStr = attrs["depth"],
               let t = parseTimeToSeconds(timeStr),
               let d = parseMeters(depthStr) {
                currentDive?.samples.append((timeSeconds: t, depthMeters: d))
            }

        case "notes" where currentDive != nil:
            inNotes = true

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    // MARK: - XMLParserDelegate：結束元素

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        defer { currentText = "" }

        switch elementName {

        case "divesites":
            inDiveSites = false

        case "site" where inDiveSites:
            if let uuid = currentSiteUUID, let site = currentSite {
                sites[uuid] = site
            }
            currentSiteUUID = nil
            currentSite     = nil

        case "dives":
            inDives = false

        case "dive" where inDives:
            if let dive = currentDive { parsedDives.append(dive) }
            currentDive       = nil
            firstCylinderDone = false

        case "divecomputer":
            inDiveComputer = false

        case "suit" where currentDive != nil:
            // <suit>wet, 3mm</suit> → 嘗試提取數字部分作為 wetsuitThickness
            let raw = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !raw.isEmpty { currentDive?.wetsuitRaw = raw }

        case "buddy" where currentDive != nil:
            let raw = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !raw.isEmpty { currentDive?.buddy = raw }

        case "notes":
            currentDive?.notes = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            inNotes = false

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        fatalError = "XML 解析錯誤: \(parseError.localizedDescription)"
    }

    // MARK: - 建立 DiveLog

    func buildDiveLogs() -> [DiveLog] {
        parsedDives.compactMap { dive in
            guard let dateStr = dive.dateString,
                  let timeStr = dive.timeString,
                  let dateTime = parseDateTime(date: dateStr, time: timeStr),
                  let durationSec = parseDuration(dive.durationStr),
                  durationSec > 0,
                  let maxDepth = dive.maxDepth,
                  maxDepth >= 0
            else { return nil }

            // 溫度：dive 層級 > computer 層級 > 預設值
            let temp = dive.diveTemperature ?? dive.computerTemperature ?? 20.0

            // 地點與 GPS
            // 注意：找不到地點時保持空字串，讓 View 層透過 String(localized:) 顯示本地化文字
            var locationName = ""
            var lat: Double?
            var lon: Double?
            if let siteId = dive.diveSiteId, let site = sites[siteId] {
                locationName = site.name ?? ""
                lat = site.latitude
                lon = site.longitude
            }

            // 氣體：有 fO2 → Nitrox 或 Air；無 → Air
            let fO2 = dive.cylinderFO2 ?? 0.21
            let gasMixJSON = SubsurfaceXMLDelegate.buildGasMixJSON(fO2: fO2)

            let log = DiveLog(
                dateTime:        dateTime,
                location:        locationName,
                maxDepth:        maxDepth,
                diveTimeSeconds: durationSec,
                gasMixJSON:      gasMixJSON,
                waterTemperature: temp
            )
            log.sourceFormat = "Subsurface"
            if let lat, let lon {
                log.latitude  = lat
                log.longitude = lon
            }

            // ── 環境資料 ──────────────────────────────────────
            log.visibility      = dive.visibility
            log.airTemperature  = dive.airTemperatureCelsius
            if let p = dive.airPressureBar { log.surfacePressureBar = p }

            // ── 裝備 ──────────────────────────────────────────
            if let kg = dive.weightKg           { log.weightTotal           = kg }
            if let sp = dive.cylinderStartBar   { log.cylinderStartPressure = sp }
            if let ep = dive.cylinderEndBar     { log.cylinderEndPressure   = ep }
            if let l  = dive.cylinderSizeL      { log.cylinderSize          = String(format: "%.0fL", l) }

            // 防寒衣：從 "wet, 3mm" / "dry, 5mm" 提取數字
            if let raw = dive.wetsuitRaw {
                let digits = raw.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .joined()
                if !digits.isEmpty { log.wetsuitThickness = digits }
            }

            log.notes = dive.notes ?? ""

            if let avg = dive.avgDepth { log.avgDepth = avg }
            var extras: [(String, String)] = []
            if let b  = dive.buddy, !b.isEmpty  { extras.append(("buddy", b)) }
            if let tg = dive.tags,  !tg.isEmpty { extras.append(("tags", tg)) }
            if let nr = dive.diveNumber { extras.append(("diveNumber", String(nr))) }
            if let model = dive.diveComputerModel { extras.append(("deviceModel", model)) }
            if let sn = dive.diveComputerSerial { extras.append(("deviceSerial", sn)) }
            log.importExtrasJSON = buildImportExtrasJSON(extras)

            // 剖面樣本：依時間去重（同一時間點出現兩次），排序後 JSON encode
            var seen = Set<Double>()
            let unique = dive.samples
                .filter { seen.insert($0.timeSeconds).inserted }
                .sorted { $0.timeSeconds < $1.timeSeconds }
            let profileSamples = unique.map {
                DiveProfileSample(timeSeconds: $0.timeSeconds, depthMeters: $0.depthMeters)
            }
            if !profileSamples.isEmpty,
               let encoded = try? JSONEncoder().encode(profileSamples),
               let json = String(data: encoded, encoding: .utf8) {
                log.profileSamplesJSON = json
            }

            return log
        }
    }

    // MARK: - 私有工具方法

    private func parseTemp(_ str: String) -> Double? {
        // "29.1 C" 或 "29.1C"
        Double(str.replacingOccurrences(of: "C", with: "").trimmingCharacters(in: .whitespaces))
    }

    private func parseBar(_ str: String) -> Double? {
        // "1.031 bar" 或 "200.0 bar"
        Double(str.replacingOccurrences(of: "bar", with: "").trimmingCharacters(in: .whitespaces))
    }

    private func parseMeters(_ str: String) -> Double? {
        // "22.65 m"
        Double(str.replacingOccurrences(of: "m", with: "").trimmingCharacters(in: .whitespaces))
    }

    private func parseTimeToSeconds(_ str: String) -> Double? {
        // "0:10 min" → 10.0, "1:30 min" → 90.0, "46:12 min" → 2772.0
        let cleaned = str.replacingOccurrences(of: " min", with: "")
                         .trimmingCharacters(in: .whitespaces)
        let parts = cleaned.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return Double(parts[0] * 60 + parts[1])
    }

    private func parseDateTime(date: String, time: String) -> Date? {
        // date="2024-10-06" time="00:33:51" → UTC
        let f = DateFormatter()
        f.dateFormat  = "yyyy-MM-dd HH:mm:ss"
        f.timeZone    = TimeZone(secondsFromGMT: 0)
        return f.date(from: "\(date) \(time)")
    }

    private func parseDuration(_ str: String?) -> Int? {
        // "66:10 min" → 66*60+10 = 3970
        // "31:00 min" → 1860
        guard let str else { return nil }
        let cleaned = str.replacingOccurrences(of: " min", with: "")
                         .trimmingCharacters(in: .whitespaces)
        let parts = cleaned.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }

    /// 使用 "%.4g" 確保浮點數跨平台輸出一致
    private static func buildGasMixJSON(fO2: Double) -> String {
        if abs(fO2 - 0.21) < 0.005 { return "\"air\"" }
        return "{\"nitrox\":{\"fO2\":\(String(format: "%.4g", fO2))}}"
    }
}

// MARK: - Subsurface 私有資料結構

private struct SubsurfaceSite {
    var name:      String?
    var latitude:  Double?
    var longitude: Double?
}

private struct SubsurfaceParsedDive {
    var dateString:          String?
    var timeString:          String?
    var durationStr:         String?
    var diveSiteId:          String?
    var maxDepth:            Double?
    var diveTemperature:     Double?   // <divetemperature> — 優先
    var computerTemperature: Double?   // <divecomputer>/<temperature> — 次要
    var airTemperatureCelsius: Double? // <temperature air='X.X C'>
    var cylinderFO2:         Double?   // nil = air
    var cylinderStartBar:    Double?   // <cylinder start='200.0 bar'>
    var cylinderEndBar:      Double?   // <cylinder end='50.0 bar'>
    var cylinderSizeL:       Double?   // <cylinder size='12.0 l'>
    var diveComputerModel:   String?
    var diveComputerSerial: String?   // deviceid or serial attribute on <divecomputer>
    var avgDepth:            Double?   // avgdepth attribute on <dive>
    var wetsuitRaw:          String?   // <suit>wet, 3mm</suit>
    var weightKg:            Double?   // <weightsystem weight='4.5 kg'>
    var visibility:          Double?   // visibility attribute on <dive>
    var airPressureBar:      Double?   // <surface pressure='1.031 bar'>
    var buddy:               String?   // <buddy>
    var diveNumber:          Int?      // number attribute on <dive>
    var tags:                String?   // tags attribute on <dive>
    var notes:               String?
    /// 原始樣本（含重複時間點，buildDiveLogs 時去重）
    var samples:             [(timeSeconds: Double, depthMeters: Double)] = []
}
