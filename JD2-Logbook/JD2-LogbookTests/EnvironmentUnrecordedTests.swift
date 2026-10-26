// EnvironmentUnrecordedTests.swift — JD2-LogbookTests
// v1.4 A1（PM 2026-10-26）：`environmentType` 改 optional（nil＝未記錄）、高海拔改由水面氣壓推導、
// 舊標籤 altitude＋預設 1.0 bar ⇒ 重放 App 層閘門。決策：`docs/decisions/D-2026-10-26-環境欄位未記錄.md`。
//
// 釘住的事：
//   1. V1（v1.3）store → V2 遷移：既有值原樣保留（不回溯清理）。
//   2. 舊備份（environmentType 為字串）照樣讀回原值；新備份 nil 能往返。
//   3. 匯入：Kit 給 nil ⇒ nil（不再補 "seawater"）；有值原樣帶入、不改寫。
//   4. 顯示：nil／舊標籤 ⇒ 未記錄；高海拔徽章只看氣壓；推導不寫回。
//   5. 閘門：只有「altitude 且恰為 1.0」擋下；用明確等於，不設容差。

import XCTest
import Foundation
import SwiftData
@testable import JoyDive_

@MainActor
final class EnvironmentUnrecordedTests: XCTestCase {

    private var tempDir: URL!

    /// 整個測試類別共用、**刻意不釋放**：`AppLanguageManager`（`@MainActor @Observable`）在測試中被釋放時，
    /// isolated deinit 的 back-deploy 路徑會 SIGABRT（2026-10-26 crash report：
    /// `swift_task_deinitOnExecutorMainActorBackDeploy` → `POINTER_BEING_FREED_WAS_NOT_ALLOCATED`）。
    /// App 內它是單一長存實例、不會被釋放，所以只有測試會碰到。
    private static let languageManager = AppLanguageManager(defaults: UserDefaults(suiteName: "EnvironmentUnrecordedTests")!)

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EnvironmentUnrecordedTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func makeDive(environment: String?, surfacePressure: Double = 1.0) -> DiveLog {
        let dive = DiveLog(dateTime: Date(timeIntervalSince1970: 1_700_000_000), location: "Test",
                           maxDepth: 18, diveTimeSeconds: 2400)
        dive.environmentType = environment
        dive.surfacePressureBar = surfacePressure
        return dive
    }

    // MARK: 1. 遷移

    /// V1 store（v1.3 模型的凍結拷貝寫出）用 App 的開檔路徑（含遷移計劃）打開 ⇒ 成功，既有值逐筆不變。
    func testV1StoreMigratesToV2PreservingValues() throws {
        let storeURL = tempDir.appendingPathComponent("v1.store")
        let cases: [(String, Double)] = [("seawater", 1.0), ("freshwater", 1.0), ("altitude", 1.0), ("altitude", 0.8)]

        do {
            let v1Schema = Schema(versionedSchema: DiveLogSchemaV1_3.self)
            let container = try ModelContainer(for: v1Schema,
                                               configurations: [ModelConfiguration(schema: v1Schema, url: storeURL)])
            let context = ModelContext(container)
            for (index, (env, pressure)) in cases.enumerated() {
                let old = DiveLogSchemaV1_3.DiveLog(dateTime: Date(timeIntervalSince1970: Double(index) * 86_400),
                                                  location: "case\(index)", maxDepth: 20, diveTimeSeconds: 2400)
                old.environmentType = env
                old.surfacePressureBar = pressure
                context.insert(old)
            }
            try context.save()
        }

        let v2Schema = Schema(versionedSchema: DiveLogSchemaV1_4.self)
        let result = DiveLogDatabase.openPersistentContainer(
            schema: v2Schema, configuration: ModelConfiguration(schema: v2Schema, url: storeURL))
        guard case .success(let container) = result else {
            return XCTFail("V1 store 應可遷移到 V2，實際：\(result)")
        }
        let dives = try ModelContext(container).fetch(FetchDescriptor<DiveLog>(sortBy: [SortDescriptor(\.dateTime)]))
        XCTAssertEqual(dives.count, cases.count)
        for (dive, expected) in zip(dives, cases) {
            XCTAssertEqual(dive.environmentType, expected.0, "\(dive.location)：既有值不得被改寫或清掉")
            XCTAssertEqual(dive.surfacePressureBar, expected.1)
        }
    }

    /// 遷移後的 V2 store 可寫入 nil（新紀錄未記錄）並讀回 nil。
    func testV2StoreRoundtripsNil() throws {
        let storeURL = tempDir.appendingPathComponent("v2.store")
        let schema = Schema(versionedSchema: DiveLogSchemaV1_4.self)
        let config = ModelConfiguration(schema: schema, url: storeURL)
        do {
            guard case .success(let container) = DiveLogDatabase.openPersistentContainer(schema: schema, configuration: config)
            else { return XCTFail("全新 V2 store 應可開啟") }
            let context = ModelContext(container)
            context.insert(makeDive(environment: nil))
            try context.save()
        }
        guard case .success(let container) = DiveLogDatabase.openPersistentContainer(schema: schema, configuration: config)
        else { return XCTFail("重開 V2 store 失敗") }
        let dives = try ModelContext(container).fetch(FetchDescriptor<DiveLog>())
        XCTAssertEqual(dives.count, 1)
        XCTAssertNil(dives.first?.environmentType)
    }

    /// 新建紀錄的模型預設＝未記錄（不再是 "seawater"）。
    func testNewDiveDefaultsToUnrecorded() {
        let dive = DiveLog(dateTime: Date(), location: "x", maxDepth: 10, diveTimeSeconds: 600)
        XCTAssertNil(dive.environmentType)
        XCTAssertNil(dive.waterType)
    }

    // MARK: 2. 備份

    /// v1.3 以前的備份檔：environmentType 是字串 ⇒ 照原值還原。
    func testLegacyBackupWithStringEnvironmentRestoresValue() throws {
        let entry = DiveLogBackupEntry(from: makeDive(environment: "freshwater"))
        var json = try JSONSerialization.jsonObject(with: encode(entry)) as! [String: Any]
        XCTAssertEqual(json["environmentType"] as? String, "freshwater", "前提：舊格式帶字串")
        json["environmentType"] = "altitude"
        let decoded = try decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.environmentType, "altitude")
        XCTAssertEqual(decoded.makeDiveLog().environmentType, "altitude")
    }

    /// 新備份檔：nil 時沒有這個 key ⇒ 解碼為 nil（decodeIfPresent），不會整份讀不出來。
    func testBackupWithoutEnvironmentKeyDecodesNil() throws {
        let data = try encode(DiveLogBackupEntry(from: makeDive(environment: nil)))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNil(json["environmentType"], "nil 應省略 key")
        let decoded = try decode(data)
        XCTAssertNil(decoded.environmentType)
        XCTAssertNil(decoded.makeDiveLog().environmentType)
    }

    private func encode(_ entry: DiveLogBackupEntry) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(entry)
    }

    private func decode(_ data: Data) throws -> DiveLogBackupEntry {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DiveLogBackupEntry.self, from: data)
    }

    // MARK: 3. 匯入

    func testImportWithoutEnvironmentStaysUnrecorded() {
        let parsed = makeTestParsedDiveLog(dateTime: Date(), location: "x", maxDepth: 10,
                                           diveTimeSeconds: 600, roundtripID: nil)
        XCTAssertNil(makeDiveLog(from: parsed).environmentType, "Kit 未提供 ⇒ 未記錄，不得補成 seawater")
    }

    func testImportWithEnvironmentKeepsValueVerbatim() {
        for value in ["seawater", "freshwater", "altitude"] {
            let parsed = makeTestParsedDiveLog(dateTime: Date(), location: "x", maxDepth: 10,
                                               diveTimeSeconds: 600, roundtripID: nil, environmentType: value)
            XCTAssertEqual(makeDiveLog(from: parsed).environmentType, value, "有值的紀錄絕不改寫")
        }
    }

    // MARK: 4. 顯示

    func testWaterTypeMapping() {
        XCTAssertEqual(makeDive(environment: "seawater").waterType, .seawater)
        XCTAssertEqual(makeDive(environment: "freshwater").waterType, .freshwater)
        XCTAssertNil(makeDive(environment: nil).waterType)
        XCTAssertNil(makeDive(environment: "altitude").waterType, "舊標籤＝水域未記錄")
        XCTAssertNil(makeDive(environment: "brackish").waterType, "未知值＝未記錄，不得落到海水")
    }

    func testHighAltitudeBadgeDependsOnlyOnSurfacePressure() {
        XCTAssertTrue(makeDive(environment: "seawater", surfacePressure: 0.8).isHighAltitude)
        XCTAssertTrue(makeDive(environment: "altitude", surfacePressure: 0.94).isHighAltitude)
        XCTAssertFalse(makeDive(environment: "altitude", surfacePressure: 1.0).isHighAltitude)
        XCTAssertFalse(makeDive(environment: nil, surfacePressure: 0.95).isHighAltitude, "門檻是「低於」0.95")
    }

    func testEnvironmentDisplayText() {
        let lm = Self.languageManager
        let sea = lm.localized("Seawater"), fresh = lm.localized("Freshwater")
        let none = lm.localized("Not Recorded"), alt = lm.localized("Altitude")
        XCTAssertEqual(makeDive(environment: "seawater").environmentDisplayText(lm), sea)
        XCTAssertEqual(makeDive(environment: "freshwater").environmentDisplayText(lm), fresh)
        XCTAssertEqual(makeDive(environment: nil).environmentDisplayText(lm), none)
        XCTAssertEqual(makeDive(environment: "altitude").environmentDisplayText(lm), none)
        XCTAssertEqual(makeDive(environment: "seawater", surfacePressure: 0.8).environmentDisplayText(lm), sea + " · " + alt)
        XCTAssertEqual(makeDive(environment: "altitude", surfacePressure: 0.8).environmentDisplayText(lm), none + " · " + alt)
    }

    /// 推導只讀不寫：取顯示字串、判定徽章／閘門後，儲存值不變。
    func testDerivationDoesNotWriteBack() {
        let lm = Self.languageManager
        for env in [nil, "seawater", "altitude"] as [String?] {
            let dive = makeDive(environment: env, surfacePressure: 0.8)
            _ = dive.environmentDisplayText(lm)
            _ = dive.isHighAltitude
            _ = dive.isReplayBlockedByLegacyAltitude
            XCTAssertEqual(dive.environmentType, env)
        }
    }

    // MARK: 5. 重放閘門

    func testReplayGateOnlyLegacyAltitudeAtExactDefaultPressure() {
        XCTAssertTrue(makeDive(environment: "altitude", surfacePressure: 1.0).isReplayBlockedByLegacyAltitude)
        XCTAssertFalse(makeDive(environment: "altitude", surfacePressure: 0.8).isReplayBlockedByLegacyAltitude, "有實測氣壓 ⇒ 照算")
        XCTAssertFalse(makeDive(environment: "altitude", surfacePressure: 0.9999).isReplayBlockedByLegacyAltitude, "明確等於，不設容差")
        XCTAssertFalse(makeDive(environment: "altitude", surfacePressure: 1.0001).isReplayBlockedByLegacyAltitude, "明確等於，不設容差")
        XCTAssertFalse(makeDive(environment: "seawater", surfacePressure: 1.0).isReplayBlockedByLegacyAltitude)
        XCTAssertFalse(makeDive(environment: nil, surfacePressure: 1.0).isReplayBlockedByLegacyAltitude)
    }

    /// 原因句與通用句的接法：中日文全形句號直接相接，英文補空格。
    func testUnavailableReasonSentenceJoining() {
        XCTAssertEqual(DiveAnalysisView.sentencePrefix("無法推算組織負荷。"), "無法推算組織負荷。")
        XCTAssertEqual(DiveAnalysisView.sentencePrefix("推定できません。"), "推定できません。")
        XCTAssertEqual(DiveAnalysisView.sentencePrefix("can't be estimated."), "can't be estimated. ")
        XCTAssertEqual(DiveAnalysisView.sentencePrefix(""), "")
    }

    /// 編輯頁把舊標籤改掉 ⇒ 重放指紋改變（詳細頁 `.id` 依此重建分析區，閘門立刻解除）。
    func testFingerprintChangesWithEnvironmentType() {
        let dive = makeDive(environment: "altitude")
        let before = dive.replayInputsFingerprint
        dive.environmentType = "seawater"
        XCTAssertNotEqual(before, dive.replayInputsFingerprint)
    }
}
