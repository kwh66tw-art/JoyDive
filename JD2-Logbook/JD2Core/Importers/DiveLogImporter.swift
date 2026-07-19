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
        guard hasFITMagic(data) else { return false }
        return Self.nonGarminManufacturer(in: data) == nil
    }

    func validateContent(_ data: Data) -> Bool {
        guard data.count >= 12 else { return false }
        guard hasFITMagic(data) else { return false }
        return Self.nonGarminManufacturer(in: data) == nil
    }

    /// file_id（GMN 0）的 manufacturer 欄位若明確存在且不是 garmin，回傳該廠牌名稱；
    /// 缺欄位或本來就是 garmin 時回傳 nil（維持既有寬鬆行為，不誤擋欄位不全的合法檔）。
    ///
    /// 2026-07-19 用真實 Suunto D4i 匯出的 .fit 發現：FIT 是共通容器格式，非 Garmin
    /// 裝置的匯出檔一樣會通過 magic bytes 驗證與 session（GMN 18）解析（start_time／
    /// total_elapsed_time 是通用欄位），但沒有 Garmin 專屬的 dive_gas（GMN 269）訊息，
    /// 導致 gasMixJSON 靜默退回預設值 "air"——深度/時長看起來正確，氣體卻是錯的，
    /// 不會拋錯，是最危險的一種靜默資料錯誤（可能誤導下游減壓計算）。加此檢查後，
    /// 非 Garmin 廠牌一律在 canHandle 階段就被拒絕，交給 factory 標記為不支援格式。
    private static func nonGarminManufacturer(in data: Data) -> String? {
        let fitFile = FitFile(data: data, parsingType: .generic)
        guard let fileId = fitFile.messages(forMessageType: .file_id).first,
              let manufacturer = fileId.interpretedField(key: "manufacturer")?.name,
              !manufacturer.lowercased().contains("garmin")
        else { return nil }
        return manufacturer
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

        // ── 3b. 廠牌驗證：非 Garmin 的 FIT 檔案會缺少 dive_gas/dive_summary
        // 訊息，硬解析會得到錯誤但不報錯的氣體資料，故明確拒絕 ───────────
        if let otherBrand = Self.nonGarminManufacturer(in: rawData) {
            throw DiveLogImportError.unsupportedFormat(
                "此 FIT 檔案由 \(otherBrand) 裝置產生，非 Garmin 格式，缺少 Garmin 專屬的" +
                "氣體/潛水摘要訊息，目前不支援解析（避免產生錯誤的氣體混合資料）"
            )
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

/// Subsurface XML 解析器
// F6：實作已搬遷至 DiveImportKit，薄包裝見 DiveImportKitAdapter.swift

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
///   - Samples[].Time：**真機 Suunto App 匯出實際只有 `TimeISO8601`（絕對時間戳），
///     從未出現相對秒數的 `Time` 欄位**（2026-07-19 用真實裝置匯出驗證發現；先前
///     此欄位純屬臆測，從未有真實或模擬資料驗證過）。剖面樣本時間改以
///     `TimeISO8601 - Header.DateTime` 反推相對秒數，`Time` 僅作為 fallback 保留
///     （若未來遇到真的帶 `Time` 欄位的匯出，仍可運作）。
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
            // 剖面：Depth（公尺）+ Time（秒，罕見）／TimeISO8601（絕對時間戳，真機
            // 實測唯一存在的欄位，相對秒數＝與 Header.DateTime 的差）+ Temperature
            // （v1.1 #4：Kelvin → Celsius，optional）
            for s in samples {
                guard let depthNum = s["Depth"] as? NSNumber else { continue }
                let d = depthNum.doubleValue
                var t: Double?
                if let timeNum = s["Time"] as? NSNumber {
                    t = timeNum.doubleValue
                } else if let tsStr = s["TimeISO8601"] as? String,
                          let ts = SuuntoJSONParser.parseISO8601(tsStr) {
                    t = ts.timeIntervalSince(dateTime)
                }
                guard let t, t >= 0, d >= 0 else { continue }
                let w = (s["Temperature"] as? NSNumber).map { $0.doubleValue - 273.15 }
                profileSamples.append(
                    DiveProfileSample(timeSeconds: t, depthMeters: d, waterTemp: w)
                )
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
