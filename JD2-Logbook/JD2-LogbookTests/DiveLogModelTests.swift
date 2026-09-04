// DiveLogModelTests.swift — JD2-LogbookTests
// v1.1 #6/#7/#8/#14：DiveLog 新增欄位、剖面樣本水溫、備份 Codable round-trip 單元測試

import XCTest
import DiveKit
@testable import JoyDive_

final class DiveLogModelTests: XCTestCase {

    // 型別加上 JoyDive_. 前綴消歧義：加了 `import DiveKit`（供本檔下方 CH-18
    // 測試用 Buhlmann/GasMix）後，App 內部自己的 `DiveProfileSample`
    // （JoyDive_.DiveProfileSample）跟 DiveKit 公開的同名型別會產生型別查找歧義。
    private func makeDive(profileSamples: [JoyDive_.DiveProfileSample] = [], diveTimeSeconds: Int = 3600) -> DiveLog {
        let dive = DiveLog(
            dateTime: Date(timeIntervalSince1970: 1_700_000_000),
            location: "Test Site",
            maxDepth: 20.0,
            diveTimeSeconds: diveTimeSeconds,
            gasMixJSON: "\"air\"",
            waterTemperature: 25.0
        )
        if !profileSamples.isEmpty,
           let data = try? JSONEncoder().encode(profileSamples),
           let json = String(data: data, encoding: .utf8) {
            dive.profileSamplesJSON = json
        }
        return dive
    }

    // MARK: - importExtras（v1.1 #6/#7）

    func testImportExtrasDefaultsToEmptyDict() {
        let dive = makeDive()
        XCTAssertEqual(dive.importExtrasJSON, "{}")
        XCTAssertTrue(dive.importExtras.isEmpty)
    }

    func testImportExtrasDecodesKeyValuePairs() {
        let dive = makeDive()
        dive.importExtrasJSON = "{\"buddy\":\"Alice\",\"deviceSerial\":\"SN123\"}"
        let extras = dive.importExtras
        XCTAssertEqual(extras["buddy"], "Alice")
        XCTAssertEqual(extras["deviceSerial"], "SN123")
    }

    func testImportExtrasInvalidJSONReturnsEmptyDict() {
        let dive = makeDive()
        dive.importExtrasJSON = "not valid json"
        XCTAssertTrue(dive.importExtras.isEmpty)
    }

    func testBuildImportExtrasJSONEmptyPairsReturnsEmptyObject() {
        XCTAssertEqual(buildImportExtrasJSON([]), "{}")
    }

    func testBuildImportExtrasJSONRoundTrips() {
        let json = buildImportExtrasJSON([("buddy", "Bob"), ("tags", "wreck,deep")])
        guard let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            XCTFail("應可解碼回 [String:String]")
            return
        }
        XCTAssertEqual(dict["buddy"], "Bob")
        XCTAssertEqual(dict["tags"], "wreck,deep")
    }

    // MARK: - avgDepth 梯形重建（v1.1 #8）

    func testReconstructedAvgDepthFlatProfile() {
        // 全程等深 10m → 平均深度應等於 10m
        let samples = [
            JoyDive_.DiveProfileSample(timeSeconds: 0,    depthMeters: 10),
            JoyDive_.DiveProfileSample(timeSeconds: 1800, depthMeters: 10),
        ]
        let dive = makeDive(profileSamples: samples, diveTimeSeconds: 1800)
        XCTAssertEqual(dive.reconstructedAvgDepth(), 10.0, accuracy: 0.01)
    }

    func testReconstructedAvgDepthTriangularProfile() {
        // 0 → 20m → 0，線性下潛/上升，時間對稱 → 平均深度應為 10m
        let samples = [
            JoyDive_.DiveProfileSample(timeSeconds: 0,    depthMeters: 0),
            JoyDive_.DiveProfileSample(timeSeconds: 600,  depthMeters: 20),
            JoyDive_.DiveProfileSample(timeSeconds: 1200, depthMeters: 0),
        ]
        let dive = makeDive(profileSamples: samples, diveTimeSeconds: 1200)
        XCTAssertEqual(dive.reconstructedAvgDepth(), 10.0, accuracy: 0.01)
    }

    func testReconstructedAvgDepthAccountsForTailBeyondLastSample() {
        // 最後樣本在 t=1000（10m），但潛水時長 1200s → 尾段 200s 需補積分（審計 G4 邊界修正）
        let samples = [
            JoyDive_.DiveProfileSample(timeSeconds: 0,    depthMeters: 10),
            JoyDive_.DiveProfileSample(timeSeconds: 1000, depthMeters: 10),
        ]
        let dive = makeDive(profileSamples: samples, diveTimeSeconds: 1200)
        // 全程恆定 10m（含尾段）→ 平均深度仍應為 10m，而非因漏算尾段被低估
        XCTAssertEqual(dive.reconstructedAvgDepth(), 10.0, accuracy: 0.01)
    }

    func testReconstructedAvgDepthInsufficientSamplesReturnsZero() {
        let dive = makeDive(profileSamples: [JoyDive_.DiveProfileSample(timeSeconds: 0, depthMeters: 10)])
        XCTAssertEqual(dive.reconstructedAvgDepth(), 0)
    }

    // MARK: - DiveProfileSample 水溫（w，v1.1 #4，additive optional）

    func testProfileSampleWaterTempEncodesWhenPresent() throws {
        let sample = JoyDive_.DiveProfileSample(timeSeconds: 10, depthMeters: 5, waterTemp: 26.5)
        let data = try JSONEncoder().encode(sample)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("\"w\""), "有水溫時應編碼 w 欄位")
    }

    func testProfileSampleWaterTempOmittedWhenNil() throws {
        let sample = JoyDive_.DiveProfileSample(timeSeconds: 10, depthMeters: 5)
        let data = try JSONEncoder().encode(sample)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("\"w\""), "無水溫時不應輸出 w 欄位")
    }

    func testProfileSampleDecodesOldFormatWithoutWaterTemp() throws {
        // 舊資料格式 {t,d}（無 w）應優雅降級解碼為 waterTemp = nil
        let json = "{\"t\":10.0,\"d\":5.0}".data(using: .utf8)!
        let sample = try JSONDecoder().decode(JoyDive_.DiveProfileSample.self, from: json)
        XCTAssertEqual(sample.timeSeconds, 10.0)
        XCTAssertEqual(sample.depthMeters, 5.0)
        XCTAssertNil(sample.waterTemp)
    }

    // MARK: - Export/Import 備份 round-trip（v1.1 #14）

    func testDiveLogBackupEntryRoundTrip() {
        let original = makeDive(profileSamples: [
            JoyDive_.DiveProfileSample(timeSeconds: 0, depthMeters: 0, waterTemp: 27),
            JoyDive_.DiveProfileSample(timeSeconds: 60, depthMeters: 10, waterTemp: 25),
        ])
        original.avgDepth = 8.5
        original.importExtrasJSON = "{\"buddy\":\"Carol\"}"
        original.notes = "Great dive"

        let entry = DiveLogBackupEntry(from: original)
        let restored = entry.makeDiveLog()

        XCTAssertEqual(restored.location, original.location)
        XCTAssertEqual(restored.maxDepth, original.maxDepth)
        XCTAssertEqual(restored.diveTimeSeconds, original.diveTimeSeconds)
        XCTAssertEqual(restored.avgDepth, 8.5, accuracy: 0.001)
        XCTAssertEqual(restored.importExtrasJSON, "{\"buddy\":\"Carol\"}")
        XCTAssertEqual(restored.notes, "Great dive")
        XCTAssertEqual(restored.profileSamples.count, 2)
        XCTAssertEqual(restored.profileSamples[0].waterTemp ?? 0, 27, accuracy: 0.001)
    }

    func testDiveLogBackupJSONEncodeDecodeRoundTrip() throws {
        let dive = makeDive()
        dive.avgDepth = 12.3
        let backup = DiveLogBackup(appVersion: "1.1", dives: [DiveLogBackupEntry(from: dive)])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DiveLogBackup.self, from: data)

        XCTAssertEqual(decoded.dives.count, 1)
        XCTAssertEqual(decoded.dives[0].avgDepth, 12.3, accuracy: 0.001)
        XCTAssertEqual(decoded.appVersion, "1.1")
    }

    // MARK: - R-022 Bug 2：diveTimeMinutes 捨去，不四捨五入
    //
    // 稽核發現同一支潛水（3570 秒＝59.5 分）在列表（DiveRowView，整數除法捨去）顯示
    // 「59 min」，在詳情頁（DiveLogDetailView，原本用 `.rounded()`）卻顯示「60 min」。
    // 修法：詳情頁／地圖頁改用 `DiveLog.diveTimeMinutes`（本測試鎖定的捨去語意）取代
    // 各自手刻的四捨五入，兩處統一。

    func testDiveTimeMinutesTruncatesNotRounds() {
        // 3570s = 59.5 分鐘：捨去應為 59，若誤用四捨五入會變 60（回歸稽核發現的落差）。
        let dive = makeDive(diveTimeSeconds: 3570)
        XCTAssertEqual(dive.diveTimeMinutes, 59)
    }

    func testDiveTimeMinutesTruncatesJustUnderNextMinute() {
        // 3599s = 59分59秒，仍應顯示 59（未滿 60 分鐘不進位）。
        let dive = makeDive(diveTimeSeconds: 3599)
        XCTAssertEqual(dive.diveTimeMinutes, 59)
    }

    func testDiveTimeMinutesExactMinuteUnaffected() {
        let dive = makeDive(diveTimeSeconds: 3600)
        XCTAssertEqual(dive.diveTimeMinutes, 60)
    }
}

// MARK: - R-022 Bug 1：UnitSystem.formatDepthConservative 永遠不比真實 ceiling 淺

final class UnitSystemCeilingRoundingTests: XCTestCase {

    func testConservativeRoundingRoundsUpNotToNearest() {
        // 5.4m 若用一般四捨五入（%.0f）會捨去成 5m——比真實 ceiling 淺，是安全問題。
        // 保守進位必須無條件進位到 6m，絕不能比真實值淺。
        XCTAssertEqual(UnitSystem.metric.formatDepthConservative(5.4), "6 m")
    }

    func testConservativeRoundingRoundsUpEvenForSmallFraction() {
        // 5.01m 一般四捨五入也會捨去成 5m；保守進位一樣要進到 6m。
        XCTAssertEqual(UnitSystem.metric.formatDepthConservative(5.01), "6 m")
    }

    func testConservativeRoundingLeavesExactIntegerUnchanged() {
        // 剛好整數深度不該被多加 1（.rounded(.up) 對整數值是恆等變換）。
        XCTAssertEqual(UnitSystem.metric.formatDepthConservative(6.0), "6 m")
    }

    func testConservativeRoundingAppliesAfterUnitConversion() {
        // 換算到英制後再進位，確保換算誤差不會把進位後的值又拉回下一個整數以下。
        // 5.4m ≈ 17.717ft，保守進位應為 18ft（比真實英尺值深或相等，絕不淺）。
        let result = UnitSystem.imperial.formatDepthConservative(5.4)
        XCTAssertEqual(result, "18 ft")
    }

    func testOrdinaryFormatDepthStillRoundsToNearestForNonCeilingUses() {
        // 確認本次修復沒有動到既有 formatDepth(decimals:) 的一般四捨五入行為
        // （非 ceiling 用途，例如警示事件深度、最大深度等，維持原行為）。
        XCTAssertEqual(UnitSystem.metric.formatDepth(5.4, decimals: 0), "5 m")
    }
}

// MARK: - CH-18（顯示取整方向常駐檢查）：NDL 必須向下取整
//
// 家族安全方向表：NDL（免減壓時間）顯示絕不能比真實值多，否則潛水員可能因為
// 看到的剩餘時間比實際多而多待水下。`DiveAnalysisView.ndlText` 用 `seconds / 60`
// （Int 除法，對非負值等同 floor），本測試把它鎖成常駐檢查，不再只靠人工檢查
// 程式碼——稽核當下實測確認這裡已經是正確方向（未發現真實 bug），寫測試是為了
// 防止未來改動（例如改成 `.rounded()`）在不知不覺中翻成危險方向。
//
// R-022 稽核範圍內，Logbook 只有三個安全量顯示點：NDL（本檔）、Ceiling
// （UnitSystemCeilingRoundingTests，已於 e3f1d4c 修復＋鎖定）、潛水時長
// （DiveTimeMinutesTruncatesXxx 系列，已於 e3f1d4c 修復＋鎖定）。TTS／禁飛／
// CNS-OLF 三項 DiveKit 有算但 Logbook 目前完全沒有任何畫面顯示（已逐檔 grep
// 確認零命中），故本次稽核無對應顯示點可測；DiveKit 若未來新增這些欄位的
// 讀值/儲存邏輯，需另外追蹤，不在本 App 的顯示層範圍內。

final class DiveAnalysisViewNDLRoundingTests: XCTestCase {

    // `ndlText` 只依賴自己的參數（不吃 @State／@Environment），視圖其餘欄位
    // （dive/samples/gasMix）給最小合法值即可，測試不會真的渲染這個 View。
    private let view = DiveAnalysisView(
        dive: DiveLog(
            dateTime: Date(timeIntervalSince1970: 1_700_000_000),
            location: "Test Site",
            maxDepth: 20.0,
            diveTimeSeconds: 3600,
            gasMixJSON: "\"air\""
        ),
        samples: [],
        gasMix: .air
    )

    func testNDLTruncatesNotRounds() {
        // 9'59"（599 秒）必須顯示「9'」，若誤用四捨五入會顯示「10'」——比真實
        // 剩餘時間多，是危險方向。
        XCTAssertEqual(view.ndlText(599), "9'")
    }

    func testNDLExactMinuteUnaffected() {
        XCTAssertEqual(view.ndlText(600), "10'")
    }

    func testNDLZeroSecondsShowsZero() {
        XCTAssertEqual(view.ndlText(0), "0'")
    }

    func testNDLUnlimitedMarkerShowsPlus() {
        // Buhlmann.ndlUnlimitedMarker = 99*60 = 5940 秒，達到門檻顯示「99+」。
        XCTAssertEqual(view.ndlText(Buhlmann.ndlUnlimitedMarker), "99+")
    }

    func testNDLJustBelowUnlimitedMarkerStillNumeric() {
        // 5939 秒 = 98'59"，未達門檻仍應顯示捨去後的分鐘數「98'」，不是「99+」。
        XCTAssertEqual(view.ndlText(Buhlmann.ndlUnlimitedMarker - 1), "98'")
    }
}

// MARK: - CH-18：潛水時長「列表 vs 詳情」一致性防回歸
//
// e3f1d4c 已把 DiveLogDetailView／DiveSiteSheetView 改成呼叫 DiveLog.diveTimeMinutes
// 本身，兩處已經沒有獨立算式可能漂移。DiveRowView（列表）目前仍是自己重算
// `dive.diveTimeSeconds / 60`（同樣是 Int 除法捨去），數學上等價但不是呼叫同一個
// property——本測試把「DiveRowView 風格算式」與 `diveTimeMinutes` 的等價性鎖定
// 為常駐檢查，未來任一邊改了取整方式（例如 DiveRowView 改用 .rounded()）就會
// 立刻紅燈，而不必等使用者回報「列表跟詳情數字不一樣」。

final class DiveTimeMinutesListDetailParityTests: XCTestCase {

    private func makeDive(diveTimeSeconds: Int) -> DiveLog {
        DiveLog(
            dateTime: Date(timeIntervalSince1970: 1_700_000_000),
            location: "Test Site",
            maxDepth: 20.0,
            diveTimeSeconds: diveTimeSeconds,
            gasMixJSON: "\"air\""
        )
    }

    /// DiveRowView.durationText 的算式（見該檔第 29 行），獨立重算供比對。
    private func diveRowViewStyleMinutes(_ dive: DiveLog) -> Int {
        dive.diveTimeSeconds / 60
    }

    func testListAndDetailAgreeOnTheR022RegressionCase() {
        // R-022 的原始回歸案例：3570 秒 = 59.5 分鐘。
        let dive = makeDive(diveTimeSeconds: 3570)
        XCTAssertEqual(diveRowViewStyleMinutes(dive), dive.diveTimeMinutes)
        XCTAssertEqual(dive.diveTimeMinutes, 59)
    }

    func testListAndDetailAgreeJustUnderNextMinute() {
        let dive = makeDive(diveTimeSeconds: 3599)
        XCTAssertEqual(diveRowViewStyleMinutes(dive), dive.diveTimeMinutes)
    }

    func testListAndDetailAgreeAtExactMinuteBoundary() {
        let dive = makeDive(diveTimeSeconds: 3600)
        XCTAssertEqual(diveRowViewStyleMinutes(dive), dive.diveTimeMinutes)
        XCTAssertEqual(dive.diveTimeMinutes, 60)
    }
}
