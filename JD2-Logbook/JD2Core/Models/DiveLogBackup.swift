// DiveLogBackup.swift — JD2Core/Models/DiveLogBackup.swift
// v1.1 #14 — Export/Import 備份功能
//
// DiveLog（SwiftData @Model）不直接做 Codable，改用獨立 DTO 解耦匯出格式與
// SwiftData schema，未來 schema 演進時備份格式可獨立版本化（schemaVersion）。

import Foundation

/// 單筆潛水日誌的備份 DTO，欄位與 DiveLog 一一對應
struct DiveLogBackupEntry: Codable {
    var dateTime: Date
    var location: String
    var latitude: Double?
    var longitude: Double?
    var maxDepth: Double
    var diveTimeSeconds: Int
    var gasMixJSON: String
    var waterTemperature: Double
    var environmentType: String
    var surfacePressureBar: Double
    var metersPerBar: Double
    var weather: String?
    var airTemperature: Double?
    var surfaceCondition: String?
    var waterflow: String?
    var visibility: Double?
    var entryTime: Date?
    var exitTime: Date?
    var wetsuitThickness: String?
    var weightTotal: Double?
    var cylinderMaterial: String?
    var cylinderSize: String?
    var cylinderStartPressure: Double?
    var cylinderEndPressure: Double?
    var notes: String
    var profileSamplesJSON: String
    var sourceFormat: String
    var avgDepth: Double
    var importExtrasJSON: String
    var createdAt: Date
    var updatedAt: Date

    init(from dive: DiveLog) {
        dateTime              = dive.dateTime
        location              = dive.location
        latitude              = dive.latitude
        longitude             = dive.longitude
        maxDepth              = dive.maxDepth
        diveTimeSeconds       = dive.diveTimeSeconds
        gasMixJSON            = dive.gasMixJSON
        waterTemperature      = dive.waterTemperature
        environmentType       = dive.environmentType
        surfacePressureBar    = dive.surfacePressureBar
        metersPerBar          = dive.metersPerBar
        weather               = dive.weather
        airTemperature        = dive.airTemperature
        surfaceCondition      = dive.surfaceCondition
        waterflow             = dive.waterflow
        visibility            = dive.visibility
        entryTime             = dive.entryTime
        exitTime              = dive.exitTime
        wetsuitThickness      = dive.wetsuitThickness
        weightTotal           = dive.weightTotal
        cylinderMaterial      = dive.cylinderMaterial
        cylinderSize          = dive.cylinderSize
        cylinderStartPressure = dive.cylinderStartPressure
        cylinderEndPressure   = dive.cylinderEndPressure
        notes                 = dive.notes
        profileSamplesJSON    = dive.profileSamplesJSON
        sourceFormat          = dive.sourceFormat
        avgDepth              = dive.avgDepth
        importExtrasJSON      = dive.importExtrasJSON
        createdAt             = dive.createdAt
        updatedAt             = dive.updatedAt
    }

    /// 還原為新的 DiveLog 實例（尚未 insert 進 modelContext）
    func makeDiveLog() -> DiveLog {
        let dive = DiveLog(
            dateTime:         dateTime,
            location:         location,
            maxDepth:         maxDepth,
            diveTimeSeconds:  diveTimeSeconds,
            gasMixJSON:       gasMixJSON,
            waterTemperature: waterTemperature
        )
        dive.latitude              = latitude
        dive.longitude             = longitude
        dive.environmentType       = environmentType
        dive.surfacePressureBar    = surfacePressureBar
        dive.metersPerBar          = metersPerBar
        dive.weather               = weather
        dive.airTemperature        = airTemperature
        dive.surfaceCondition      = surfaceCondition
        dive.waterflow             = waterflow
        dive.visibility            = visibility
        dive.entryTime             = entryTime
        dive.exitTime              = exitTime
        dive.wetsuitThickness      = wetsuitThickness
        dive.weightTotal           = weightTotal
        dive.cylinderMaterial      = cylinderMaterial
        dive.cylinderSize          = cylinderSize
        dive.cylinderStartPressure = cylinderStartPressure
        dive.cylinderEndPressure   = cylinderEndPressure
        dive.notes                 = notes
        dive.profileSamplesJSON    = profileSamplesJSON
        dive.sourceFormat          = sourceFormat
        dive.avgDepth              = avgDepth
        dive.importExtrasJSON      = importExtrasJSON
        dive.createdAt             = createdAt
        dive.updatedAt             = updatedAt
        return dive
    }
}

/// 完整備份檔案結構（含版本號，供未來格式演進判斷相容性）
struct DiveLogBackup: Codable {
    var schemaVersion: Int = 1
    var exportedAt: Date = Date()
    var appVersion: String
    var dives: [DiveLogBackupEntry]
}
