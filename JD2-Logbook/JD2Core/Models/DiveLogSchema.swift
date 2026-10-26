// DiveLogSchema.swift — JD2Core/Models/DiveLogSchema.swift
// v1.4 A1（PM 2026-10-26 裁示 D3：趁 A1 把 v1.3 立成 VersionedSchema V1）
//
// SwiftData 版本化 schema 與遷移計劃。v1.3 以前沒有版本化，靠 SwiftData 隱式輕量遷移
// （v1.1 additive 欄位、v1.2 `diveMode`、C2 `waterTemperature` 改 optional 都是這樣過的）。
// 從 v1.4 起每次改 schema 都要：①新增 `DiveLogSchemaVn`（凍結當時的 `DiveLog`）②在
// `DiveLogMigrationPlan` 加一個 stage ③用前一版真實 store 實測（`DiveLogSchemaMigrationTests`）。
//
// 🔴 `DiveLogSchemaV1.DiveLog` 是 **v1.3 (Build 4) 上架時的 `DiveLog` 儲存欄位的凍結拷貝**
// （`git diff 5954409 HEAD -- JD2Core/Models/` 為空：v1.3 送審 commit 到 v1.4 開工前模型沒變）。
// **不得修改**——它和磁碟上 v1.3 store 的模型雜湊對不上時，開檔會失敗並進入 `DatabaseOpenErrorView`
// （資料不會被刪，但使用者打不開 App 內容）。只留儲存欄位與 init，計算屬性不需要。

import Foundation
import SwiftData

// MARK: - V1（v1.3 Build 4）

enum DiveLogSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [DiveLog.self] }

    @Model
    final class DiveLog {
        var dateTime: Date
        var location: String
        var latitude: Double?
        var longitude: Double?
        var maxDepth: Double
        var diveTimeSeconds: Int
        var gasMixJSON: String
        var waterTemperature: Double?
        var environmentType: String = "seawater"
        var surfacePressureBar: Double = 1.0
        var metersPerBar: Double = 10.0
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
        var notes: String = ""
        var profileSamplesJSON: String = "[]"
        var sourceFormat: String = "manual"
        var diveMode: String = "scuba"
        var avgDepth: Double = 0
        var importExtrasJSON: String = "{}"
        var createdAt: Date
        var updatedAt: Date

        init(dateTime: Date, location: String, maxDepth: Double, diveTimeSeconds: Int,
             gasMixJSON: String = "\"air\"", waterTemperature: Double? = nil) {
            self.dateTime = dateTime
            self.location = location
            self.maxDepth = maxDepth
            self.diveTimeSeconds = diveTimeSeconds
            self.gasMixJSON = gasMixJSON
            self.waterTemperature = waterTemperature
            let now = Date()
            self.createdAt = now
            self.updatedAt = now
        }
    }
}

// MARK: - V2（v1.4：`environmentType` 改 optional，nil＝未記錄）

enum DiveLogSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    /// 目前的 `DiveLog`（頂層型別）。下次改 schema 時把它凍結成 V2 拷貝、頂層再前進一版。
    static var models: [any PersistentModel.Type] { [DiveLog.self] }
}

// MARK: - 遷移計劃

enum DiveLogMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [DiveLogSchemaV1.self, DiveLogSchemaV2.self] }

    /// V1 → V2：只有 `environmentType` 由 `String` 改 `String?` ⇒ 輕量遷移，**既有值原樣保留**
    /// （PM 2026-10-26：既有紀錄不回溯清理，舊紀錄照樣是 "seawater" 等原值）。
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: DiveLogSchemaV1.self, toVersion: DiveLogSchemaV2.self)]
    }
}
