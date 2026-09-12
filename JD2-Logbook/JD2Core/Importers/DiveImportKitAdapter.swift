// DiveImportKitAdapter.swift — JD2Core/Importers/
// F6 階段一（2026-07-19）：改用家族共用匯入解析器套件 DiveImportKit。
// 家族層 import 共用第二階段（2026-07-19）：新增 10 個格式的薄包裝（DAN DL7／
// Divesoft DLF／Reefnet Sensus／Diving Log／Suunto DM5／SML／SDE／JSON／
// Garmin Connect JSON／Garmin FIT），原本地實作全數刪除，改由 Kit 提供。
//
// 本檔是「全 App 唯一」import DiveImportKit 的檔案——Kit 的型別名
// （DiveLogImporter / DiveLogFormat / DiveLogImportError）與本 repo 同名，
// 其他檔案一律不 import Kit，避免全面歧義；本檔內以 DiveImportKit. 前綴
// 明確限定 Kit 型別，未加前綴的名稱依 Swift 同模組遮蔽規則解析為本地型別。
//
// 已搬遷至 Kit 的解析器在此以薄包裝 struct 重新掛回本地 DiveLogImporter
// protocol：struct 名稱與原本地實作相同，DiveLogImporterFactory 與既有測試
// （F5DiveKitMigrationE2ETests 等）不需改動。
//
// MinimalZipReader 已完全搬遷至 Kit（原本地轉發用途僅供 SuuntoSDEParser，
// 該解析器現也改為 Kit 薄包裝，本地轉發已無消費端，一併移除）。

import Foundation
import DiveImportKit

// MARK: - ParsedDiveLog → DiveLog 轉換

/// Kit 中性 DTO → 本地 SwiftData `DiveLog`，逐欄位對映。
/// 序列化欄位維持既有 schema 不動：
///   - `profileSamples`（陣列）→ `profileSamplesJSON`（短鍵 t/d/w JSON 字串）
///   - `importExtras`（陣列）→ `importExtrasJSON`（sortedKeys JSON dict 字串，
///     沿用既有 `buildImportExtrasJSON`，輸出與搬遷前逐 byte 一致）
func makeDiveLog(from parsed: DiveImportKit.ParsedDiveLog) -> DiveLog {
    let dive = DiveLog(
        dateTime:         parsed.dateTime,
        location:         parsed.location,
        maxDepth:         parsed.maxDepth,
        diveTimeSeconds:  parsed.diveTimeSeconds,
        gasMixJSON:       parsed.gasMixJSON,
        waterTemperature: parsed.waterTemperature
    )

    // 基本信息
    dive.latitude  = parsed.latitude
    dive.longitude = parsed.longitude

    // 環境信息（Kit 為 optional；本地為帶預設值的必填欄位，nil = 維持預設）
    if let environmentType    = parsed.environmentType    { dive.environmentType    = environmentType }
    if let surfacePressureBar = parsed.surfacePressureBar { dive.surfacePressureBar = surfacePressureBar }
    if let metersPerBar       = parsed.metersPerBar       { dive.metersPerBar       = metersPerBar }

    // 環境與條件詳細資訊
    dive.weather          = parsed.weather
    dive.airTemperature   = parsed.airTemperature
    dive.surfaceCondition = parsed.surfaceCondition
    dive.waterflow        = parsed.waterflow
    dive.visibility       = parsed.visibility

    // 時間詳細資訊
    dive.entryTime = parsed.entryTime
    dive.exitTime  = parsed.exitTime

    // 裝備信息
    dive.wetsuitThickness      = parsed.wetsuitThickness
    dive.weightTotal           = parsed.weightTotal
    dive.cylinderMaterial      = parsed.cylinderMaterial
    dive.cylinderSize          = parsed.cylinderSize
    dive.cylinderStartPressure = parsed.cylinderStartPressure
    dive.cylinderEndPressure   = parsed.cylinderEndPressure

    // 額外信息
    dive.notes        = parsed.notes
    dive.sourceFormat = parsed.sourceFormat
    if let avgDepth = parsed.avgDepth { dive.avgDepth = avgDepth }

    // 剖面樣本：Kit DTO 陣列 → 本地短鍵 JSON 字串（CodingKeys t/d/w 與本地一致）
    if !parsed.profileSamples.isEmpty {
        let samples = parsed.profileSamples.map {
            DiveProfileSample(timeSeconds: $0.timeSeconds,
                              depthMeters: $0.depthMeters,
                              waterTemp:   $0.waterTemp)
        }
        if let data = try? JSONEncoder().encode(samples),
           let json = String(data: data, encoding: .utf8) {
            dive.profileSamplesJSON = json
        }
    }

    // 匯入原始資料：Kit 結構化陣列 → 既有 sortedKeys JSON dict 字串
    dive.importExtrasJSON = buildImportExtrasJSON(parsed.importExtras.map { ($0.key, $0.value) })

    return dive
}

// MARK: - Kit 錯誤 → 本地錯誤轉換

/// Kit 的 `DiveLogImportError` → 本地同名 enum，逐 case 對映。
/// ImportWizardView 以本地 case 逐一 catch 顯示錯誤訊息，
/// 不轉換的話 Kit 錯誤會落到通用 catch，UI 錯誤提示劣化。
/// Kit 的 `parsingFailed` underlyingError 為 String?（Sendable 限制），
/// 併回 detail 字串，訊息內容與 Kit errorDescription 一致。
func mapImportKitError(_ error: Error) -> Error {
    guard let kitError = error as? DiveImportKit.DiveLogImportError else { return error }
    switch kitError {
    case .fileNotFound(let path):        return DiveLogImportError.fileNotFound(path)
    case .invalidFormat(let format):     return DiveLogImportError.invalidFormat(format)
    case .parsingFailed(let detail, let underlying):
        return DiveLogImportError.parsingFailed(
            underlying == nil ? detail : "\(detail) (\(underlying!))")
    case .unsupportedFormat(let format): return DiveLogImportError.unsupportedFormat(format)
    case .corruptedData(let detail):     return DiveLogImportError.corruptedData(detail)
    case .emptyFile:                     return DiveLogImportError.emptyFile
    }
}

// MARK: - 背景安全批次處理（家族層 import 共用第二階段，2026-07-19）
//
// 給 ImportCoordinator 在背景 Task 內呼叫：選格式＋解析＋驗證全程只碰
// Kit 的 Sendable DTO（ParsedDiveLog），沒有本地 DiveLogImporter 協定回傳
// SwiftData DiveLog 那種跨 actor 邊界的 Sendable 問題，不需要 Task.detached
// 補丁也能安全在背景執行緒跑（修復 SYNC #3）。呼叫端拿到結果後才呼叫下面的
// `makeDiveLog(from:)` 轉換回 SwiftData（輕量、非 CPU 密集，MainActor 上做無妨）。

/// 選格式＋解析＋基本驗證（maxDepth >= 0、diveTimeSeconds > 0）。
/// - Throws: 對應 App 本地 `DiveLogImportError`（已透過 `mapImportKitError` 轉換）。
func parseAndValidateForBackground(filePath: String) throws -> [DiveImportKit.ParsedDiveLog] {
    do {
        return try DiveImportKit.ImportBatchProcessor.parseAndValidate(filePath: filePath)
    } catch {
        throw mapImportKitError(error)
    }
}

/// R-070 App 半（2026-09-03）：從 `importExtrasJSON`（既有 sortedKeys JSON dict
/// 字串，見 `makeDiveLog(from:)` 註解／`DiveLog.importExtras`）解碼出 round-trip
/// 指紋 ID（`DiveImportKit.jd2RoundtripIDKey`）。與 `DiveLog.importExtras` 用
/// 同一套解碼做法，這裡直接吃原始 JSON 字串是為了同時供 `DiveLog` 與
/// `DiveLogBackupEntry`（兩者皆有 `importExtrasJSON` 欄位，但後者沒有前者那個
/// 型別化的 `importExtras` computed property）共用同一份抽取邏輯，不重複寫。
/// 找不到欄位或欄位不存在的舊資料（Kit round-trip 機制導入前匯入的記錄）
/// 一律回傳 nil——`DiveFingerprint.matches` 任一邊為 nil 時完全退回既有模糊
/// 比對，向後相容不受影響。
func roundtripID(fromImportExtrasJSON json: String) -> String? {
    guard let data = json.data(using: .utf8),
          let dict = try? JSONDecoder().decode([String: String].self, from: data)
    else { return nil }
    return dict[DiveImportKit.jd2RoundtripIDKey]
}

/// 去重：候選記錄 vs 資料庫既有記錄（修復 SYNC #2，邏輯與 Kit 內建測試一致，
/// 兩邊 App 共用同一份，不再各自維護容易走鐘的版本）。
/// R-070：既有記錄的指紋帶上已儲存的 round-trip ID（若有），讓 UDDF round-trip
/// 匯入（ultra/immersion → Logbook）優先走精確 ID 比對，不再 100% 依賴地點/
/// 時間/深度模糊比對——後者在 UDDF 匯出改寫地點名稱等情況下會失效。
func dedupeAgainstExisting(
    _ dives: [DiveImportKit.ParsedDiveLog],
    existing: [DiveLog]
) -> (kept: [DiveImportKit.ParsedDiveLog], skippedCount: Int) {
    let fingerprints = existing.map {
        DiveImportKit.DiveFingerprint(
            dateTime: $0.dateTime, location: $0.location, maxDepth: $0.maxDepth,
            roundtripID: roundtripID(fromImportExtrasJSON: $0.importExtrasJSON)
        )
    }
    return DiveImportKit.ImportBatchProcessor.dedupe(dives, against: fingerprints)
}

/// 去重：候選記錄 vs 資料庫既有記錄，本地 `DiveLog` 版本（R-074 收斂，2026-09-06）。
/// 供 `ImportCoordinator.deduplicateDives`/`dedupe`（現況：非生產匯入路徑呼叫，
/// 保留供既有單元測試／未來若有本地 SwiftData DiveLog 陣列直接呼叫的場景使用）
/// 呼叫，取代原本手寫的「地點＋深度容差＋60秒時間窗」比對規則與獨立
/// `depthMatchToleranceMeters` 常數——兩者是同一條 Kit `DiveFingerprint.matches`
/// 規則的影子複製（見 `_JD2-family/decisions/DRAFT_2026-08-31_全盤稽核統一修復
/// 計畫.md` R-074）。與 JD2-ultra `DiveImportKitAdapter.dedupeLocalDivesAgainstExisting`
/// 同款寫法，改呼叫 Kit 的泛型 `ImportBatchProcessor.dedupe<T>`，不再各自維護
/// 比對邏輯與容差數值。
func dedupeLocalDivesAgainstExisting(
    _ dives: [DiveLog],
    existing: [DiveLog]
) -> (kept: [DiveLog], skippedCount: Int) {
    let fingerprints = existing.map {
        DiveImportKit.DiveFingerprint(
            dateTime: $0.dateTime, location: $0.location, maxDepth: $0.maxDepth,
            roundtripID: roundtripID(fromImportExtrasJSON: $0.importExtrasJSON)
        )
    }
    return DiveImportKit.ImportBatchProcessor.dedupe(dives, against: fingerprints) {
        DiveImportKit.DiveFingerprint(
            dateTime: $0.dateTime, location: $0.location, maxDepth: $0.maxDepth,
            roundtripID: roundtripID(fromImportExtrasJSON: $0.importExtrasJSON)
        )
    }
}

/// R-070 測試專用建構器（2026-09-03）：讓測試能建構帶／不帶 round-trip ID 的
/// `DiveImportKit.ParsedDiveLog` 候選記錄，驗證 `dedupeAgainstExisting` 的精確
/// ID 比對，同時不必讓測試檔自己 `import DiveImportKit`——本檔頭已明文「全 App
/// 唯一 import DiveImportKit 的檔案」；經實測，讓 App target 以外的檔案（含測試
/// target）也直接 `import DiveImportKit` 會在 macOS（Mac Catalyst／原生 macOS）
/// destination 的 explicit module build 下觸發 `unable to resolve module
/// dependency: 'JoyDive_'`（iOS Simulator 不受影響，只有 macOS 目的地重現），
/// 靠回傳型別推斷讓呼叫端完全不需要拼出 `DiveImportKit.` 前綴即可繞開。
/// C2（2026-09-07）：新增 `waterTemperature` 參數（預設 nil，與 Kit 側
/// `ParsedDiveLog.init` 的預設一致），供 `WaterTemperatureOptionalTests` 驗證
/// `makeDiveLog(from:)` 對水溫的 nil/非 nil 都原樣傳遞、不重新填入編造值。
func makeTestParsedDiveLog(
    dateTime: Date,
    location: String,
    maxDepth: Double,
    diveTimeSeconds: Int,
    roundtripID: String?,
    waterTemperature: Double? = nil
) -> DiveImportKit.ParsedDiveLog {
    DiveImportKit.ParsedDiveLog(
        dateTime: dateTime,
        location: location,
        maxDepth: maxDepth,
        diveTimeSeconds: diveTimeSeconds,
        waterTemperature: waterTemperature,
        importExtras: roundtripID.map {
            [DiveImportKit.ImportExtra(key: DiveImportKit.jd2RoundtripIDKey, value: $0)]
        } ?? []
    )
}

/// 格式顯示名稱（供 log 訊息用，不需要讓呼叫端知道 Kit 的 DiveLogFormat 型別存在）。
func formatDisplayName(for filePath: String) -> String? {
    DiveImportKit.DiveLogImporterFactory.selectImporter(for: filePath)?.format.displayName
}

/// 去重：備份還原候選項 vs 資料庫既有記錄（家族層共用抽取 B 組，2026-07-19）。
/// 跟匯入流程用的是同一套 Kit 比對規則（地點+深度+60秒），供
/// `DiveLogDatabase.importFromJSON` 呼叫，不再手寫一份物理重複的邏輯。
/// R-070：`DiveLogBackupEntry` 也帶有 `importExtrasJSON`（`DiveLogBackup.swift`
/// 逐欄位對拷自 `DiveLog`），兩邊指紋都接上 round-trip ID——只接 `existing`
/// 側會讓 `DiveFingerprint.matches` 因為 `other.roundtripID` 恆為 nil 而永遠
/// 走不到精確比對分支，等於白接；備份／還原資料完整保留 `importExtrasJSON`
/// 原樣（非重新產生的匯出），ID 本來就在，接上沒有向後相容疑慮。
func dedupeBackupEntries(
    _ entries: [DiveLogBackupEntry],
    against existing: [DiveLog]
) -> (kept: [DiveLogBackupEntry], skippedCount: Int) {
    let fingerprints = existing.map {
        DiveImportKit.DiveFingerprint(
            dateTime: $0.dateTime, location: $0.location, maxDepth: $0.maxDepth,
            roundtripID: roundtripID(fromImportExtrasJSON: $0.importExtrasJSON)
        )
    }
    return DiveImportKit.ImportBatchProcessor.dedupe(entries, against: fingerprints) {
        DiveImportKit.DiveFingerprint(
            dateTime: $0.dateTime, location: $0.location, maxDepth: $0.maxDepth,
            roundtripID: roundtripID(fromImportExtrasJSON: $0.importExtrasJSON)
        )
    }
}

// MARK: - Kit 解析器薄包裝（實作本地 DiveLogImporter protocol）

/// UDDF 解析器（ISO 12639:2015）——實作已搬遷至 DiveImportKit
struct UDDFParser: DiveLogImporter {
    private let kit = DiveImportKit.UDDFParser()

    let format = DiveLogFormat.uddf
    var name: String { kit.name }

    func canHandle(filePath: String) -> Bool { kit.canHandle(filePath: filePath) }
    func validateContent(_ data: Data) -> Bool { kit.validateContent(data) }

    func parse(from filePath: String) throws -> [DiveLog] {
        do {
            return try kit.parse(from: filePath).map(makeDiveLog(from:))
        } catch {
            throw mapImportKitError(error)
        }
    }
}

/// Subsurface XML 解析器（.ssrf / .xml）——實作已搬遷至 DiveImportKit
struct SubsurfaceXMLParser: DiveLogImporter {
    private let kit = DiveImportKit.SubsurfaceXMLParser()

    let format = DiveLogFormat.subsurface
    var name: String { kit.name }

    func canHandle(filePath: String) -> Bool { kit.canHandle(filePath: filePath) }
    func validateContent(_ data: Data) -> Bool { kit.validateContent(data) }

    func parse(from filePath: String) throws -> [DiveLog] {
        do {
            return try kit.parse(from: filePath).map(makeDiveLog(from:))
        } catch {
            throw mapImportKitError(error)
        }
    }
}

/// Subsurface 手動 CSV 解析器（#Nr header）——實作已搬遷至 DiveImportKit
struct SubsurfaceCSVParser: DiveLogImporter {
    private let kit = DiveImportKit.SubsurfaceCSVParser()

    let format = DiveLogFormat.csv
    var name: String { kit.name }

    func canHandle(filePath: String) -> Bool { kit.canHandle(filePath: filePath) }
    func validateContent(_ data: Data) -> Bool { kit.validateContent(data) }

    func parse(from filePath: String) throws -> [DiveLog] {
        do {
            return try kit.parse(from: filePath).map(makeDiveLog(from:))
        } catch {
            throw mapImportKitError(error)
        }
    }
}

/// Shearwater Cloud/Desktop XML 解析器——實作已搬遷至 DiveImportKit
struct SHEARWATERParser: DiveLogImporter {
    private let kit = DiveImportKit.SHEARWATERParser()

    let format = DiveLogFormat.shearwater
    var name: String { kit.name }

    func canHandle(filePath: String) -> Bool { kit.canHandle(filePath: filePath) }
    func validateContent(_ data: Data) -> Bool { kit.validateContent(data) }

    func parse(from filePath: String) throws -> [DiveLog] {
        do {
            return try kit.parse(from: filePath).map(makeDiveLog(from:))
        } catch {
            throw mapImportKitError(error)
        }
    }
}

/// Seabear Diving Technology CSV 解析器——實作已搬遷至 DiveImportKit
struct SeabearCSVParser: DiveLogImporter {
    private let kit = DiveImportKit.SeabearCSVParser()

    let format = DiveLogFormat.seabear
    var name: String { kit.name }

    func canHandle(filePath: String) -> Bool { kit.canHandle(filePath: filePath) }
    func validateContent(_ data: Data) -> Bool { kit.validateContent(data) }

    func parse(from filePath: String) throws -> [DiveLog] {
        do {
            return try kit.parse(from: filePath).map(makeDiveLog(from:))
        } catch {
            throw mapImportKitError(error)
        }
    }
}

// MARK: - 家族層 import 共用第二階段（2026-07-19）新增的 10 個薄包裝

/// DAN DL7 / ZXU 解析器——實作已搬遷至 DiveImportKit
struct DANDL7Parser: DiveLogImporter {
    private let kit = DiveImportKit.DANDL7Parser()

    let format = DiveLogFormat.danDL7
    var name: String { kit.name }

    func canHandle(filePath: String) -> Bool { kit.canHandle(filePath: filePath) }
    func validateContent(_ data: Data) -> Bool { kit.validateContent(data) }

    func parse(from filePath: String) throws -> [DiveLog] {
        do {
            return try kit.parse(from: filePath).map(makeDiveLog(from:))
        } catch {
            throw mapImportKitError(error)
        }
    }
}

/// Divesoft Freedom/Liberty DLF 解析器——實作已搬遷至 DiveImportKit
struct DivesoftDLFParser: DiveLogImporter {
    private let kit = DiveImportKit.DivesoftDLFParser()

    let format = DiveLogFormat.divesoft
    var name: String { kit.name }

    func canHandle(filePath: String) -> Bool { kit.canHandle(filePath: filePath) }
    func validateContent(_ data: Data) -> Bool { kit.validateContent(data) }

    func parse(from filePath: String) throws -> [DiveLog] {
        do {
            return try kit.parse(from: filePath).map(makeDiveLog(from:))
        } catch {
            throw mapImportKitError(error)
        }
    }
}

/// Reefnet Sensus CSV 解析器——實作已搬遷至 DiveImportKit
struct ReefnetSensusParser: DiveLogImporter {
    private let kit = DiveImportKit.ReefnetSensusParser()

    let format = DiveLogFormat.sensus
    var name: String { kit.name }

    func canHandle(filePath: String) -> Bool { kit.canHandle(filePath: filePath) }
    func validateContent(_ data: Data) -> Bool { kit.validateContent(data) }

    func parse(from filePath: String) throws -> [DiveLog] {
        do {
            return try kit.parse(from: filePath).map(makeDiveLog(from:))
        } catch {
            throw mapImportKitError(error)
        }
    }
}

/// Diving Log 6.0 SQLite 解析器——實作已搬遷至 DiveImportKit
struct DivingLogSQLiteParser: DiveLogImporter {
    private let kit = DiveImportKit.DivingLogSQLiteParser()

    let format = DiveLogFormat.divingLog
    var name: String { kit.name }

    func canHandle(filePath: String) -> Bool { kit.canHandle(filePath: filePath) }
    func validateContent(_ data: Data) -> Bool { kit.validateContent(data) }

    func parse(from filePath: String) throws -> [DiveLog] {
        do {
            return try kit.parse(from: filePath).map(makeDiveLog(from:))
        } catch {
            throw mapImportKitError(error)
        }
    }
}

/// Suunto DM4/DM5 WCF XML 解析器——實作已搬遷至 DiveImportKit
struct SuuntoDM5XMLParser: DiveLogImporter {
    private let kit = DiveImportKit.SuuntoDM5XMLParser()

    let format = DiveLogFormat.suuntoDM5
    var name: String { kit.name }

    func canHandle(filePath: String) -> Bool { kit.canHandle(filePath: filePath) }
    func validateContent(_ data: Data) -> Bool { kit.validateContent(data) }

    func parse(from filePath: String) throws -> [DiveLog] {
        do {
            return try kit.parse(from: filePath).map(makeDiveLog(from:))
        } catch {
            throw mapImportKitError(error)
        }
    }
}

/// Suunto SML（Moveslink）解析器——實作已搬遷至 DiveImportKit
struct SuuntoSMLParser: DiveLogImporter {
    private let kit = DiveImportKit.SuuntoSMLParser()

    let format = DiveLogFormat.suuntoSML
    var name: String { kit.name }

    func canHandle(filePath: String) -> Bool { kit.canHandle(filePath: filePath) }
    func validateContent(_ data: Data) -> Bool { kit.validateContent(data) }

    func parse(from filePath: String) throws -> [DiveLog] {
        do {
            return try kit.parse(from: filePath).map(makeDiveLog(from:))
        } catch {
            throw mapImportKitError(error)
        }
    }
}

/// Suunto SDE（ZIP 包裝 DM3 XML）解析器——實作已搬遷至 DiveImportKit
struct SuuntoSDEParser: DiveLogImporter {
    private let kit = DiveImportKit.SuuntoSDEParser()

    let format = DiveLogFormat.suuntoSDE
    var name: String { kit.name }

    func canHandle(filePath: String) -> Bool { kit.canHandle(filePath: filePath) }
    func validateContent(_ data: Data) -> Bool { kit.validateContent(data) }

    func parse(from filePath: String) throws -> [DiveLog] {
        do {
            return try kit.parse(from: filePath).map(makeDiveLog(from:))
        } catch {
            throw mapImportKitError(error)
        }
    }
}

/// Suunto App DeviceLog JSON 解析器——實作已搬遷至 DiveImportKit
/// （2026-07-19 家族層共用：與 App-u 原本各自維護的重複實作合併，以 App-lb
/// 修復後版本為準，含 TimeISO8601 fallback 真實 bug 修復）
struct SuuntoJSONParser: DiveLogImporter {
    private let kit = DiveImportKit.SuuntoJSONParser()

    let format = DiveLogFormat.suunto
    var name: String { kit.name }

    func canHandle(filePath: String) -> Bool { kit.canHandle(filePath: filePath) }
    func validateContent(_ data: Data) -> Bool { kit.validateContent(data) }

    func parse(from filePath: String) throws -> [DiveLog] {
        do {
            return try kit.parse(from: filePath).map(makeDiveLog(from:))
        } catch {
            throw mapImportKitError(error)
        }
    }
}

/// Garmin Connect activity JSON 解析器——實作已搬遷至 DiveImportKit
/// （2026-07-19 家族層共用：與 App-u 原本各自維護的重複實作合併）
struct GarminConnectJSONParser: DiveLogImporter {
    private let kit = DiveImportKit.GarminConnectJSONParser()

    let format = DiveLogFormat.garmin
    var name: String { kit.name }

    func canHandle(filePath: String) -> Bool { kit.canHandle(filePath: filePath) }
    func validateContent(_ data: Data) -> Bool { kit.validateContent(data) }

    func parse(from filePath: String) throws -> [DiveLog] {
        do {
            return try kit.parse(from: filePath).map(makeDiveLog(from:))
        } catch {
            throw mapImportKitError(error)
        }
    }
}

/// Garmin Descent ANT+ FIT 解析器——實作已搬遷至 DiveImportKit
/// （2026-07-19 含跨廠牌誤判防護修復：非 Garmin 廠牌的 .fit 檔案明確拒絕，
/// 避免 gasMixJSON 靜默退回錯誤的預設值）
struct GarminDescentParser: DiveLogImporter {
    private let kit = DiveImportKit.GarminDescentParser()

    let format = DiveLogFormat.garmin
    var name: String { kit.name }

    func canHandle(filePath: String) -> Bool { kit.canHandle(filePath: filePath) }
    func validateContent(_ data: Data) -> Bool { kit.validateContent(data) }

    func parse(from filePath: String) throws -> [DiveLog] {
        do {
            return try kit.parse(from: filePath).map(makeDiveLog(from:))
        } catch {
            throw mapImportKitError(error)
        }
    }
}
