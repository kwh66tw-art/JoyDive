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
    case uddf       = "UDDF"
    case subsurface = "Subsurface"   // Subsurface XML (.ssrf / .xml)
    case shearwater = "SHEARWATER"
    case peregrine  = "Peregrine"
    case cresiMares = "Cressi/Mares"
    case garmin     = "Garmin"
    case suunto     = "Suunto"
    case oceanic    = "Oceanic"

    /// 支援的檔案副檔名
    var supportedExtensions: [String] {
        switch self {
        case .uddf:       return ["uddf", "zip"]
        case .subsurface: return ["ssrf", "xml"]   // .ssrf 原生，.xml 為 Subsurface 匯出
        case .shearwater: return ["xml"]
        case .peregrine:  return ["xml"]
        case .cresiMares: return ["csv"]
        case .garmin:     return ["fit"]
        case .suunto:     return ["xml", "sde", "sdp"]
        case .oceanic:    return ["ocf", "xml"]
        }
    }

    /// 格式顯示名稱
    var displayName: String {
        self.rawValue
    }

    /// 優先順序（用於格式自動偵測）
    /// Subsurface 優先級最高：canHandle 含內容驗證，不會誤判其他 .xml
    var priority: Int {
        switch self {
        case .subsurface: return 0   // 最優先，內容驗證確保正確性
        case .uddf:       return 1
        case .shearwater: return 2
        case .garmin:     return 3
        case .suunto:     return 4
        case .oceanic:    return 5
        case .peregrine:  return 6
        case .cresiMares: return 7
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
            xmlData = try UDDFParser.extractXMLFromZIP(filePath: filePath)
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

    /// ZIP 解壓：macOS 使用系統 unzip；iOS 需整合 ZipFoundation
    static func extractXMLFromZIP(filePath: String) throws -> Data {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", filePath, "uddf.xml"]
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()
        do { try process.run() } catch {
            throw DiveLogImportError.parsingFailed("ZIP 解壓失敗: \(error.localizedDescription)")
        }
        process.waitUntilExit()
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        guard !data.isEmpty else {
            throw DiveLogImportError.invalidFormat("ZIP 內未找到 uddf.xml (\(filePath))")
        }
        return data
        #else
        throw DiveLogImportError.unsupportedFormat(
            "ZIP 包裝格式在 iOS 需要 ZipFoundation，目前僅支援純 XML UDDF"
        )
        #endif
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

    /// 副檔名 + 內容雙重驗證，避免誤判其他 .xml 格式
    func canHandle(filePath: String) -> Bool {
        let ext = (filePath as NSString).pathExtension.lowercased()
        guard ext == "ssrf" || ext == "xml" else { return false }
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
            inInfoBefore = false
            inInfoAfter  = false
            inTankData   = false
            inSamples    = false
            inWaypoint   = false
            inNotes      = false

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
            currentDive  = nil
            inInfoBefore = false
            inInfoAfter  = false
            inTankData   = false
            inSamples    = false
            inWaypoint   = false
            inNotes      = false

        case "informationbeforedive":
            inInfoBefore = false

        case "informationafterdive":
            inInfoAfter = false

        case "tankdata":
            inTankData = false

        case "samples":
            inSamples = false

        case "waypoint":
            inWaypoint = false

        case "notes":
            inNotes = false

        // ── 必填欄位 ──────────────────────────────────────────
        case "divenumber" where inInfoBefore:
            currentDive?.diveNumber = Int(text)

        case "datetime" where inInfoBefore:
            if !text.isEmpty { currentDive?.dateTimeString = text }

        case "airtemperature" where inInfoBefore:
            // 水面氣溫（Kelvin），作為無 watertemp 時的後備值
            currentDive?.airTempKelvin = Double(text)

        case "greatestdepth" where inInfoAfter:
            currentDive?.greatestDepth = Double(text)

        case "diveduration" where inInfoAfter:
            // 值為秒數（可能帶小數，如 6240.0）
            currentDive?.diveDuration = Double(text)

        case "lowesttemperature" where inInfoAfter:
            // UDDF 最低水溫（Kelvin）
            currentDive?.lowestTempKelvin = Double(text)

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
            var locationName = "Unknown Location"
            var lat: Double?
            var lon: Double?

            // 優先：informationbeforedive 中的 link ref → 對應 sites 字典
            for ref in dive.siteRefs {
                if let site = sites[ref] {
                    locationName = site.name ?? site.geographyLocation ?? "Unknown Location"
                    lat = site.latitude
                    lon = site.longitude
                    break
                }
            }

            // 備用：若無 link ref 且僅有一個 site，直接使用
            if locationName == "Unknown Location", sites.count == 1,
               let sole = sites.values.first {
                locationName = sole.name ?? sole.geographyLocation ?? "Unknown Location"
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

            if let notes = dive.notes, !notes.isEmpty {
                log.notes = notes
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
    private static func makeGasMixJSON(fO2: Double, fHe: Double) -> String {
        if fHe > 0.001 {
            return "{\"trimix\":{\"fO2\":\(fO2),\"fHe\":\(fHe)}}"
        } else if abs(fO2 - 0.21) < 0.005 {
            return "\"air\""
        } else {
            return "{\"nitrox\":{\"fO2\":\(fO2)}}"
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
    var airTempKelvin:         Double?         // informationbeforedive airtemperature
    var waypointMinTempKelvin: Double?         // 取樣點最低溫（逐步 min 更新）
    var notes:                 String?
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

        // 潛水層級溫度（優先於電腦內溫度）
        case "divetemperature" where currentDive != nil:
            if let s = attrs["water"] { currentDive?.diveTemperature = parseTemp(s) }

        case "divecomputer" where currentDive != nil:
            inDiveComputer = true
            if currentDive?.diveComputerModel == nil {
                currentDive?.diveComputerModel = attrs["model"]
            }

        case "depth" where inDiveComputer:
            if let s = attrs["max"] { currentDive?.maxDepth = parseMeters(s) }

        // 電腦層級溫度（次要來源）
        case "temperature" where inDiveComputer:
            if let s = attrs["water"] { currentDive?.computerTemperature = parseTemp(s) }

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
                  maxDepth > 0
            else { return nil }

            // 溫度：dive 層級 > computer 層級 > 預設值
            let temp = dive.diveTemperature ?? dive.computerTemperature ?? 20.0

            // 地點與 GPS
            var locationName = "Unknown Location"
            var lat: Double?
            var lon: Double?
            if let siteId = dive.diveSiteId, let site = sites[siteId] {
                locationName = site.name ?? "Unknown Location"
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
            log.notes        = dive.notes ?? ""
            if let lat, let lon {
                log.latitude  = lat
                log.longitude = lon
            }
            return log
        }
    }

    // MARK: - 私有工具方法

    private func parseTemp(_ str: String) -> Double? {
        // "29.1 C" 或 "29.1C"
        Double(str.replacingOccurrences(of: "C", with: "").trimmingCharacters(in: .whitespaces))
    }

    private func parseMeters(_ str: String) -> Double? {
        // "22.65 m"
        Double(str.replacingOccurrences(of: "m", with: "").trimmingCharacters(in: .whitespaces))
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

    private static func buildGasMixJSON(fO2: Double) -> String {
        if abs(fO2 - 0.21) < 0.005 { return "\"air\"" }
        return "{\"nitrox\":{\"fO2\":\(fO2)}}"
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
    var cylinderFO2:         Double?   // nil = air
    var diveComputerModel:   String?
    var notes:               String?
}
