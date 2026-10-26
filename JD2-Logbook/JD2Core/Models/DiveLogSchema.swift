// DiveLogSchema.swift — JD2Core/Models/DiveLogSchema.swift
// v1.4 A1（PM 2026-10-26 裁示 D3：趁 A1 把 schema 版本化；同日裁示 A 方案：補齊歷代上架版本）
//
// SwiftData 版本化 schema 與遷移計劃。v1.3 以前沒有版本化，靠 SwiftData 隱式推斷遷移。
// 🔴 **改用 `SchemaMigrationPlan` 後，store 的模型雜湊必須等於計劃裡某一版，否則開檔失敗**
// （不再隱式推斷）。2026-10-26 實測：只列 v1.3 時，v1.2 store 直接裝 v1.4 ⇒ `DatabaseOpenErrorView`
// （資料未動）。所以**每一個上架過的版本**都要在這裡有一份凍結拷貝：
//
// | Schema | 上架版本 | 凍結來源 commit | 與前一版差異 |
// |---|---|---|---|
// | `DiveLogSchemaV1_0` | v1.0 (Build 2) | `d54966b`（2026-06-17 送審） | — |
// | `DiveLogSchemaV1_2` | v1.2 (Build 3) | `3ba4bd2`（2026-07-28 送審） | ＋`avgDepth`、＋`importExtrasJSON` |
// | `DiveLogSchemaV1_3` | v1.3 (Build 4) | `5954409`（2026-10-10 送審） | `waterTemperature` 改 optional、＋`diveMode` |
// | `DiveLogSchemaV1_4` | v1.4（開發中） | 頂層 `DiveLog` | `environmentType` 改 optional |
//
// （v1.1 未上架：開發完成後直接升版成 v1.2 送審，沒有獨立的 store 版本。）
//
// 凍結拷貝**只留儲存欄位與 init**，逐字照抄該 commit 的 `DiveLog` 宣告（預設值寫法、型別、可選性都要一致），
// **不得修改**——對不上 store 雜湊就打不開。版本號跟 App 版號對齊；版本號只是識別，比對靠模型雜湊。
// 下次改 schema：①把頂層 `DiveLog` 凍結成 `DiveLogSchemaV1_4` 拷貝 ②新增下一版 ③加 stage
// ④用**每一個**上架版本的真實 store 實測（`docs/V1_4_AUDIT_TEST_PLAN.md` T1–T3 的作法）。

import Foundation
import SwiftData

// MARK: - v1.0 (Build 2)

enum DiveLogSchemaV1_0: VersionedSchema {
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
        var waterTemperature: Double
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
        var createdAt: Date
        var updatedAt: Date

        init(dateTime: Date, location: String, maxDepth: Double, diveTimeSeconds: Int,
             gasMixJSON: String = "\"air\"", waterTemperature: Double = 15.0) {
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

// MARK: - v1.2 (Build 3)

enum DiveLogSchemaV1_2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 2, 0) }
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
        var waterTemperature: Double
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
        var avgDepth: Double = 0
        var importExtrasJSON: String = "{}"
        var createdAt: Date
        var updatedAt: Date

        init(dateTime: Date, location: String, maxDepth: Double, diveTimeSeconds: Int,
             gasMixJSON: String = "\"air\"", waterTemperature: Double = 15.0) {
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

// MARK: - v1.3 (Build 4)

enum DiveLogSchemaV1_3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 3, 0) }
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

// MARK: - v1.4（開發中：`environmentType` 改 optional，nil＝未記錄）

enum DiveLogSchemaV1_4: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 4, 0) }
    /// 目前的 `DiveLog`（頂層型別）。下次改 schema 時把它凍結成 V1_4 拷貝、頂層再前進一版。
    static var models: [any PersistentModel.Type] { [DiveLog.self] }
}

// MARK: - 遷移計劃

enum DiveLogMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [DiveLogSchemaV1_0.self, DiveLogSchemaV1_2.self, DiveLogSchemaV1_3.self, DiveLogSchemaV1_4.self]
    }

    /// 每一步都只是新增有預設值的欄位或放寬為 optional ⇒ 輕量遷移，**既有值原樣保留**
    /// （PM 2026-10-26：既有紀錄不回溯清理）。
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: DiveLogSchemaV1_0.self, toVersion: DiveLogSchemaV1_2.self),
            .lightweight(fromVersion: DiveLogSchemaV1_2.self, toVersion: DiveLogSchemaV1_3.self),
            .lightweight(fromVersion: DiveLogSchemaV1_3.self, toVersion: DiveLogSchemaV1_4.self),
        ]
    }
}
