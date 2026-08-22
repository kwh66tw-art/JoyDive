// DiveModeTests.swift — JD2-LogbookTests
// 2026-08-22：`DiveLog.diveMode`（潛水類型）欄位與 DiveKit `isBreathHold` 的接線驗證。
//
// 這裡**不重複驗證 Kit 的殘氮鏈演算法**（那是 DiveKit `ReplayChainTests` 的職責），
// 只驗證本 repo 該負責的四件事：
//   ① 新欄位預設值＝水肺（既有紀錄語意不變）、未知 rawValue 優雅退回
//   ② SwiftData additive 欄位：既有資料讀回來不壞，落在預設值
//   ③ 備份 round-trip 帶得到；**沒有 diveMode key 的舊備份仍能還原**（→ scuba）
//   ④ `replayInput.isBreathHold` 對 scuba / free / snorkel 各自映射正確
//
// 規格：`_JD2-family/decisions/2026-08-22_重放連續潛水殘氮與前置判斷-設計.md` 第六之三節

import XCTest
import SwiftData
import DiveKit
@testable import JoyDive_

@MainActor
final class DiveModeTests: XCTestCase {

    private func squareProfileJSON(depth: Double, seconds: Int) -> String {
        let samples = [
            JoyDive_.DiveProfileSample(timeSeconds: 0, depthMeters: 0),
            JoyDive_.DiveProfileSample(timeSeconds: 30, depthMeters: depth),
            JoyDive_.DiveProfileSample(timeSeconds: Double(seconds - 30), depthMeters: depth),
            JoyDive_.DiveProfileSample(timeSeconds: Double(seconds), depthMeters: 0),
        ]
        return String(data: try! JSONEncoder().encode(samples), encoding: .utf8)!
    }

    private func makeDive(at date: Date = Date(timeIntervalSince1970: 1_700_000_000),
                          depth: Double = 20, seconds: Int = 2400) -> DiveLog {
        let dive = DiveLog(dateTime: date, location: "Test Site",
                           maxDepth: depth, diveTimeSeconds: seconds,
                           gasMixJSON: "\"air\"", waterTemperature: 25)
        dive.profileSamplesJSON = squareProfileJSON(depth: depth, seconds: seconds)
        return dive
    }

    // MARK: - ① 預設值與型別化存取

    func testNewDiveDefaultsToScuba() {
        let dive = makeDive()
        XCTAssertEqual(dive.diveMode, "scuba",
                       "Logbook 是水肺日誌，新紀錄與既有紀錄一律預設水肺")
        XCTAssertEqual(dive.diveModeValue, .scuba)
        XCTAssertFalse(dive.diveModeValue.isBreathHold)
    }

    func testBreathHoldClassification() {
        XCTAssertFalse(DiveLogMode.scuba.isBreathHold)
        XCTAssertTrue(DiveLogMode.free.isBreathHold)
        XCTAssertTrue(DiveLogMode.snorkel.isBreathHold)
    }

    func testRawValuesMatchUltraForBreathHoldModes() {
        // ultra 的 DiveLogEntry.diveMode 用 "free"／"snorkel"，字面必須一致，
        // 未來跨 App 同步才不需要轉換（水肺側 Logbook 收斂成單一 "scuba"）。
        XCTAssertEqual(DiveLogMode.free.rawValue, "free")
        XCTAssertEqual(DiveLogMode.snorkel.rawValue, "snorkel")
        XCTAssertEqual(DiveLogMode.scuba.rawValue, "scuba")
    }

    func testUnknownRawValueFallsBackToScuba() {
        let dive = makeDive()
        dive.diveMode = "rebreather-from-the-future"
        XCTAssertEqual(dive.diveModeValue, .scuba,
                       "未知值必須優雅退回水肺，不得讓整筆紀錄讀不出來")
        XCTAssertFalse(dive.replayInput.isBreathHold)
    }

    func testDiveModeValueSetterWritesRawValue() {
        let dive = makeDive()
        dive.diveModeValue = .free
        XCTAssertEqual(dive.diveMode, "free")
    }

    // MARK: - ② SwiftData additive 欄位（既有資料不壞）

    func testExistingRecordsSurviveWithDefaultDiveMode() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DiveLog.self, configurations: config)
        let context = ModelContext(container)

        // 「既有紀錄」＝走既有 init 建立、完全沒碰過 diveMode 的紀錄
        let legacy = makeDive()
        legacy.avgDepth = 11.5
        legacy.notes = "pre-diveMode record"
        context.insert(legacy)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DiveLog>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].notes, "pre-diveMode record", "既有欄位不得受影響")
        XCTAssertEqual(fetched[0].avgDepth, 11.5, accuracy: 0.001)
        XCTAssertEqual(fetched[0].diveMode, "scuba",
                       "additive 欄位有預設值，lightweight migration 應補 scuba")
        XCTAssertFalse(fetched[0].replayInput.isBreathHold)
    }

    func testDiveModePersistsAndFetchesBack() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DiveLog.self, configurations: config)
        let context = ModelContext(container)

        let dive = makeDive()
        dive.diveModeValue = .snorkel
        context.insert(dive)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DiveLog>())
        XCTAssertEqual(fetched[0].diveModeValue, .snorkel)
        XCTAssertTrue(fetched[0].replayInput.isBreathHold)
    }

    // MARK: - ③ 備份 round-trip

    func testBackupEntryCarriesDiveMode() {
        let dive = makeDive()
        dive.diveModeValue = .free

        let restored = DiveLogBackupEntry(from: dive).makeDiveLog()
        XCTAssertEqual(restored.diveModeValue, .free, "備份還原不得掉 diveMode")
        XCTAssertTrue(restored.replayInput.isBreathHold)
    }

    func testBackupJSONRoundTripCarriesDiveMode() throws {
        let dive = makeDive()
        dive.diveModeValue = .snorkel
        let backup = DiveLogBackup(appVersion: "1.2", dives: [DiveLogBackupEntry(from: dive)])

        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)
        XCTAssertTrue(String(data: data, encoding: .utf8)!.contains("\"diveMode\""),
                      "diveMode 必須真的寫進備份 JSON，不能只是還原時補預設值")

        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DiveLogBackup.self, from: data)
        XCTAssertEqual(decoded.dives[0].diveMode, "snorkel")
        XCTAssertEqual(decoded.dives[0].makeDiveLog().diveModeValue, .snorkel)
    }

    func testLegacyBackupWithoutDiveModeStillRestores() throws {
        // v1.1/v1.2 產出的既有備份檔沒有 diveMode key。DTO 欄位宣告成 Optional
        // 就是為了這件事（Codable 合成的 init(from:) 對缺鍵的非 Optional 會 throw）。
        let dive = makeDive()
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(DiveLogBackup(appVersion: "1.1",
                                                    dives: [DiveLogBackupEntry(from: dive)]))
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var dives = json["dives"] as! [[String: Any]]
        dives[0].removeValue(forKey: "diveMode")
        XCTAssertNil(dives[0]["diveMode"])
        json["dives"] = dives
        let legacyData = try JSONSerialization.data(withJSONObject: json)

        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DiveLogBackup.self, from: legacyData)
        XCTAssertNil(decoded.dives[0].diveMode)
        let restored = decoded.dives[0].makeDiveLog()
        XCTAssertEqual(restored.diveModeValue, .scuba, "舊備份還原應落在水肺預設值")
        XCTAssertEqual(restored.location, "Test Site", "其餘欄位照常還原")
    }

    // MARK: - ④ replayInput 映射（本次任務的核心接線）

    func testReplayInputIsBreathHoldMapping() {
        let scuba = makeDive();   scuba.diveModeValue = .scuba
        let free = makeDive();    free.diveModeValue = .free
        let snorkel = makeDive(); snorkel.diveModeValue = .snorkel

        XCTAssertFalse(scuba.replayInput.isBreathHold)
        XCTAssertTrue(free.replayInput.isBreathHold, "自由潛水＝閉氣潛水")
        XCTAssertTrue(snorkel.replayInput.isBreathHold, "浮潛＝閉氣潛水")
    }

    /// 接到 Kit 之後真的會走到 P7（不是只有旗標傳過去而已）
    func testBreathHoldTargetIsReportedAsAnomaly() {
        let dive = makeDive(depth: 20, seconds: 180)
        dive.diveModeValue = .free

        guard case .anomaly(let reason) =
                DiveReplayEngine.replayChain(target: dive.replayInput, precedingDives: [])
        else { return XCTFail("目標潛水為閉氣潛水時應回報 P7") }
        XCTAssertEqual(reason, .breathHoldTarget)
    }

    /// 閉氣的**前導**潛水（有完整剖面樣本）必須被濾出鏈外——這正是本欄位要防的
    /// 「模型以為這個人在 20m 持續呼吸了兩分鐘」的錯誤高估。
    func testBreathHoldPrecedingDiveIsExcludedFromChain() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let freedive = makeDive(at: base, depth: 20, seconds: 180)
        freedive.diveModeValue = .free
        let target = makeDive(at: base.addingTimeInterval(2 * 3600), depth: 25, seconds: 2400)

        guard case .replayed(let withFreedive) =
                DiveReplayEngine.replayChain(target: target.replayInput,
                                             precedingDives: [freedive.replayInput]),
              case .replayed(let alone) =
                DiveReplayEngine.replayChain(target: target.replayInput, precedingDives: [])
        else { return XCTFail("兩次重放都應該通過前置判斷") }

        XCTAssertEqual(withFreedive.chainDiveCount, 1,
                       "閉氣的前導潛水應在建鏈階段被濾掉（不是判為異常）")
        XCTAssertEqual(withFreedive.chainDiveCount, alone.chainDiveCount)
        for (a, b) in zip(withFreedive.finalTissuePN2, alone.finalTissuePN2) {
            XCTAssertEqual(a, b, accuracy: 1e-9,
                           "濾掉後逐隔室數值必須與「沒有那筆」完全相同")
        }
    }

    /// 對照組：同一筆前導潛水**若標記為水肺**就會進鏈並帶進殘氮——證明上一個測試
    /// 不是因為「這筆本來就不影響」而通過的（破壞性對照）。
    func testSameDiveCountsIntoChainWhenMarkedScuba() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let preceding = makeDive(at: base, depth: 20, seconds: 180)   // 預設 scuba
        let target = makeDive(at: base.addingTimeInterval(2 * 3600), depth: 25, seconds: 2400)

        guard case .replayed(let chained) =
                DiveReplayEngine.replayChain(target: target.replayInput,
                                             precedingDives: [preceding.replayInput])
        else { return XCTFail("水肺前導潛水應通過前置判斷") }
        XCTAssertEqual(chained.chainDiveCount, 2,
                       "同一筆標記為水肺時必須進鏈——否則上一個測試是空轉通過")
    }
}
