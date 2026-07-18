// DiveImportKitAdapter.swift — JD2Core/Importers/
// F6 階段一（2026-07-19）：改用家族共用匯入解析器套件 DiveImportKit。
//
// 本檔是「全 App 唯一」import DiveImportKit 的檔案——Kit 的型別名
// （DiveLogImporter / DiveLogFormat / DiveLogImportError）與本 repo 同名，
// 其他檔案一律不 import Kit，避免全面歧義；本檔內以 DiveImportKit. 前綴
// 明確限定 Kit 型別，未加前綴的名稱依 Swift 同模組遮蔽規則解析為本地型別。
//
// 已搬遷至 Kit 的 5 個真解析器（UDDF / Subsurface XML / Subsurface CSV /
// Shearwater / Seabear CSV）在此以薄包裝 struct 重新掛回本地
// DiveLogImporter protocol：struct 名稱與原本地實作相同，
// DiveLogImporterFactory 與既有測試（F5DiveKitMigrationE2ETests 等）不需改動。
//
// MinimalZipReader 亦已搬遷至 Kit，本檔以 typealias 轉出供
// SuuntoSDEParser（Logbook 專屬解析器）與既有測試繼續使用。

import Foundation
import DiveImportKit

// MARK: - MinimalZipReader 轉出（原 Importers/MinimalZipReader.swift 已搬遷至 Kit）

/// 本地薄轉發（不能用 typealias：專案啟用 MemberImportVisibility，
/// 未直接 import DiveImportKit 的檔案無法呼叫別名型別的成員）。
/// 供 SuuntoSDEParser（Logbook 專屬解析器）與既有 MinimalZipReaderTests 使用。
enum MinimalZipReader {
    static func extractFirstEntry(from data: Data,
                                  matching predicate: (String) -> Bool) throws -> Data {
        try DiveImportKit.MinimalZipReader.extractFirstEntry(from: data, matching: predicate)
    }
}

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
