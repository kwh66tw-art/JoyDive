// DiveReplayChainAdoptionTests.swift — JD2-LogbookTests
// 2026-08-22：Logbook 採用 DiveKit 共用重放引擎（`replayChain`）後的 App 層驗證。
//
// 這裡**不重複驗證演算法本身**（那是 DiveKit `ReplayChainTests` 的職責），只驗證
// 本 repo 該負責的兩件事：
//   ① `DiveLog` → `DiveReplayEngine.DiveInput` 的映射正確（尤其 maxDepth 有帶、
//      recordedSeriesIndex 誠實地留 nil）
//   ② 前導潛水查詢真的回傳 96h 窗口內、且不含目標潛水自己
//
// 規格：`_JD2-family/decisions/2026-08-22_重放連續潛水殘氮與前置判斷-設計.md`

import XCTest
import SwiftData
import DiveKit
import DiveImportKit
@testable import JoyDive_

@MainActor
final class DiveReplayChainAdoptionTests: XCTestCase {

    private func squareProfileJSON(depth: Double, seconds: Int) -> String {
        let samples = [
            JoyDive_.DiveProfileSample(timeSeconds: 0, depthMeters: 0),
            JoyDive_.DiveProfileSample(timeSeconds: 60, depthMeters: depth),
            JoyDive_.DiveProfileSample(timeSeconds: Double(seconds - 60), depthMeters: depth),
            JoyDive_.DiveProfileSample(timeSeconds: Double(seconds), depthMeters: 0),
        ]
        let data = try! JSONEncoder().encode(samples)
        return String(data: data, encoding: .utf8)!
    }

    private func makeDive(at date: Date, depth: Double = 25, seconds: Int = 2400,
                          gasMixJSON: String = "\"air\"") -> DiveLog {
        let dive = DiveLog(dateTime: date, location: "Test", maxDepth: depth,
                           diveTimeSeconds: seconds, gasMixJSON: gasMixJSON)
        dive.profileSamplesJSON = squareProfileJSON(depth: depth, seconds: seconds)
        return dive
    }

    // MARK: - ① 映射

    func testReplayInputMapping() {
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        let dive = makeDive(at: started, depth: 27.5, seconds: 3000)
        let input = dive.replayInput

        XCTAssertEqual(input.startedAt, started)
        XCTAssertEqual(input.durationSeconds, 3000)
        XCTAssertEqual(input.maxDepthMeters, 27.5,
                       "maxDepth 必須傳給 Kit——它是保守上界截斷的方形剖面估算依據")
        XCTAssertEqual(input.profileSamples.count, 4)
        XCTAssertFalse(input.gasMix.isTrimix)
        XCTAssertEqual(input.environment, .seaLevel,
                       "預設 surfacePressureBar=1.0 / metersPerBar=10.0 應等同 seaLevel")
        XCTAssertNil(input.recordedSeriesIndex,
                     "Logbook 沒有 diveNumberInSeries 欄位——刻意留 nil 讓 Kit 跳過 P4，不得假造")
        XCTAssertEqual(input.endedAt, started.addingTimeInterval(3000))
    }

    func testFreshwaterEnvironmentIsCarriedThrough() {
        let dive = makeDive(at: Date())
        dive.setEnvironment(type: "freshwater", surfacePressure: 1.0, metersPerBar: 10.2)
        XCTAssertEqual(dive.replayInput.environment.metersPerBar, 10.2)
    }

    // MARK: - ② 鏈式重放（走 Kit，只驗證 App 端接線）

    func testRepetitiveDiveCarriesResidualNitrogen() {
        let first = makeDive(at: Date(timeIntervalSince1970: 1_700_000_000), depth: 30, seconds: 2400)
        let second = makeDive(at: Date(timeIntervalSince1970: 1_700_000_000 + 3 * 3600),
                              depth: 30, seconds: 2400)

        guard case .replayed(let standalone) =
                DiveReplayEngine.replayChain(target: second.replayInput, precedingDives: []),
              case .replayed(let chained) =
                DiveReplayEngine.replayChain(target: second.replayInput,
                                             precedingDives: [first.replayInput])
        else { return XCTFail("兩次重放都應該通過前置判斷") }

        XCTAssertEqual(chained.chainDiveCount, 2)
        XCTAssertEqual(standalone.chainDiveCount, 1)
        let slowChained = chained.finalTissuePN2.last ?? 0
        let slowStandalone = standalone.finalTissuePN2.last ?? 0
        XCTAssertGreaterThan(slowChained, slowStandalone,
                             "3 小時水面間隔的第二趟應帶有前一潛殘氮，慢隔室分壓必須更高")
    }

    func testTrimixTargetIsReportedAsAnomaly() {
        let trimixJSON = #"{"trimix":{"fO2":0.16,"fHe":0.45}}"#
        let dive = makeDive(at: Date(), depth: 39, seconds: 3000, gasMixJSON: trimixJSON)
        XCTAssertTrue(dive.replayGasMix.isTrimix, "GasMix JSON 格式已變動，測試需更新")

        guard case .anomaly(let reason) =
                DiveReplayEngine.replayChain(target: dive.replayInput, precedingDives: [])
        else { return XCTFail("trimix 應被前置判斷 P1 攔下") }
        XCTAssertEqual(reason, .technicalDive(chainIndex: 0, isTargetDive: true))
    }

    /// v1.3（PM 2026-10-05）：匯入時標記 `gasMixConfidence=unknown`（例：Garmin FIT 多氣體／CCR）
    /// 的潛水，即使 gasMixJSON 是合法的 "air"，重放也必須拒算——先前 App 從未讀這個標記。
    func testImportFlaggedUnknownGasIsReportedAsAnomaly() {
        let dive = makeDive(at: Date(), depth: 30, seconds: 2400)
        dive.importExtrasJSON = #"{"gasMixConfidence":"unknown"}"#
        XCTAssertEqual(dive.replayGasMixConfidence, .unknown)

        guard case .anomaly(let reason) =
                DiveReplayEngine.replayChain(target: dive.replayInput, precedingDives: [])
        else { return XCTFail("匯入標記氣體不可信，應被前置判斷攔下") }
        XCTAssertEqual(reason, .unknownGasMix(chainIndex: 0, isTargetDive: true))
    }

    func testUnflaggedAirDiveStillReplays() {
        let dive = makeDive(at: Date(), depth: 18, seconds: 2400)
        dive.importExtrasJSON = #"{"deviceSerial":"123"}"#
        XCTAssertEqual(dive.replayGasMixConfidence, .confirmed)
        guard case .replayed = DiveReplayEngine.replayChain(target: dive.replayInput, precedingDives: [])
        else { return XCTFail("沒有不可信標記的空氣潛水應照常重放") }
    }

    /// v1.3（PM 2026-10-05 裁示 A）：舊版匯入的 Garmin FIT（無已驗證標記）氣體一律被寫成 air ⇒ 視為不可信。
    func testLegacyGarminFITWithoutVerifiedMarkIsUnknown() {
        let dive = makeDive(at: Date(), depth: 30, seconds: 2400)
        dive.sourceFormat = "garmin"
        XCTAssertEqual(dive.replayGasMixConfidence, .unknown)
        guard case .anomaly(let reason) =
                DiveReplayEngine.replayChain(target: dive.replayInput, precedingDives: [])
        else { return XCTFail("舊版 Garmin 匯入應被前置判斷攔下") }
        XCTAssertEqual(reason, .unknownGasMix(chainIndex: 0, isTargetDive: true))
    }

    func testVerifiedGarminFITReplays() {
        let dive = makeDive(at: Date(), depth: 18, seconds: 2400, gasMixJSON: #"{"nitrox":{"fO2":0.33}}"#)
        dive.sourceFormat = "garmin"
        dive.importExtrasJSON = "{\"\(DiveLog.garminGasVerifiedKey)\":\"v0.7.2\"}"
        XCTAssertEqual(dive.replayGasMixConfidence, .confirmed)
    }

    func testAdapterMarksGarminImportsAsVerified() {
        let garmin = makeDiveLog(from: makeTestParsedDiveLog(
            dateTime: Date(), location: "", maxDepth: 18, diveTimeSeconds: 2400,
            roundtripID: nil, sourceFormat: "garmin"))
        XCTAssertEqual(garmin.importExtras[DiveLog.garminGasVerifiedKey], "v0.7.2")
        let uddf = makeDiveLog(from: makeTestParsedDiveLog(
            dateTime: Date(), location: "", maxDepth: 18, diveTimeSeconds: 2400,
            roundtripID: nil, sourceFormat: "uddf"))
        XCTAssertNil(uddf.importExtras[DiveLog.garminGasVerifiedKey])
    }

    /// PM 2026-10-06：DiveImportKit v0.7.3 修正氣體判定的格式，舊版匯入（無標記）一律不可信；UDDF 維持原狀。
    func testLegacyV073FormatsWithoutMarkerAreUnknown_UDDFUnaffected() {
        for format in ["seabear", "divinglog", "shearwater", "csv", "csv-profile"] {
            let dive = makeDive(at: Date(), depth: 18, seconds: 2400)
            dive.sourceFormat = format
            XCTAssertEqual(dive.replayGasMixConfidence, .unknown, format)
            dive.importExtrasJSON = "{\"\(DiveLog.gasVerifiedKey)\":\"v0.7.3\"}"
            XCTAssertEqual(dive.replayGasMixConfidence, .confirmed, "\(format) 新版匯入（有標記、無不可信旗標）照常")
        }
        let uddf = makeDive(at: Date(), depth: 18, seconds: 2400)
        uddf.sourceFormat = "UDDF"
        XCTAssertEqual(uddf.replayGasMixConfidence, .confirmed, "UDDF 舊資料依 PM 裁示維持原狀")
    }

    /// PM 2026-10-07：Subsurface XML 舊匯入（無標記，或 v0.7.6 之前的標記）一律不可信。
    func testLegacySubsurfaceXMLBeforeV076IsUnknown() {
        let dive = makeDive(at: Date(), depth: 18, seconds: 2400)
        dive.sourceFormat = "Subsurface"
        XCTAssertEqual(dive.replayGasMixConfidence, .unknown, "無標記＝舊版匯入")
        dive.importExtrasJSON = "{\"\(DiveLog.gasVerifiedKey)\":\"v0.7.3\"}"
        XCTAssertEqual(dive.replayGasMixConfidence, .unknown, "v0.7.3 還沒有多氣瓶判定")
        dive.importExtrasJSON = "{\"\(DiveLog.gasVerifiedKey)\":\"v0.7.6\"}"
        XCTAssertEqual(dive.replayGasMixConfidence, .confirmed)
        dive.importExtrasJSON = "{\"\(DiveLog.gasVerifiedKey)\":\"v0.7.10\"}"
        XCTAssertEqual(dive.replayGasMixConfidence, .confirmed, "版本以數字比較，不是字串")
    }

    /// PM 2026-10-07：使用者改了氣體 ⇒ 已確認，壓過匯入端的不可信與舊資料判定；沒改氣體不算。
    func testUserGasEditConfirmsGas() {
        let dive = makeDive(at: Date(), depth: 18, seconds: 2400)
        dive.sourceFormat = "Subsurface"
        dive.gasMixJSON = "{\"nitrox\":{\"fO2\":0.30}}"
        dive.importExtrasJSON = "{\"gasMixConfidence\":\"unknown\"}"
        XCTAssertEqual(dive.replayGasMixConfidence, .unknown)

        XCTAssertNil(dive.userEditConfirmations(newDateTime: dive.dateTime, newGasMixJSON: nil),
                     "使用者沒動氣體欄位（nil）不算確認（PM 2026-10-10）")
        XCTAssertEqual(dive.userEditConfirmations(newDateTime: dive.dateTime, newGasMixJSON: "{\"nitrox\":{\"fO2\":0.3}}")?[DiveLog.gasMixConfidenceKey],
                       DiveLog.userConfirmedValue,
                       "氣體不可信時使用者明確選了氣體，即使與佔位值相同也算確認")

        let extras = dive.userEditConfirmations(newDateTime: dive.dateTime, newGasMixJSON: "{\"nitrox\":{\"fO2\":0.32}}")
        XCTAssertEqual(extras?[DiveLog.gasMixConfidenceKey], DiveLog.userConfirmedValue)
        dive.importExtrasJSON = buildImportExtrasJSON((extras ?? [:]).map { ($0.key, $0.value) })
        dive.gasMixJSON = "{\"nitrox\":{\"fO2\":0.32}}"
        XCTAssertEqual(dive.replayGasMixConfidence, .confirmed)
    }

    /// 氣體可信時，選了一樣的氣體（字串格式不同、解碼後相同）不改標記。
    func testUserGasReselectSameTrustedGasNoChange() {
        let dive = makeDive(at: Date(), depth: 18, seconds: 2400)
        dive.sourceFormat = "uddf"
        dive.gasMixJSON = "{\"nitrox\":{\"fO2\":0.30}}"
        XCTAssertEqual(dive.replayGasMixConfidence, .confirmed)
        XCTAssertNil(dive.userEditConfirmations(newDateTime: dive.dateTime, newGasMixJSON: "{\"nitrox\":{\"fO2\":0.3}}"))
    }

    /// PM 2026-10-07：氣體不可信 ⇒ 畫面氣體欄顯示「未知氣體」（displayGasMix＝nil）；使用者確認後恢復。
    func testDisplayGasMixIsNilWhenGasUntrusted() {
        let dive = makeDive(at: Date(), depth: 18, seconds: 2400)
        dive.sourceFormat = "uddf"
        dive.gasMixJSON = "{\"nitrox\":{\"fO2\":0.32}}"
        XCTAssertEqual(dive.displayGasMix, .nitrox(fO2: 0.32))
        dive.importExtrasJSON = "{\"gasMixConfidence\":\"unknown\"}"
        XCTAssertNil(dive.displayGasMix)
        dive.importExtrasJSON = "{\"gasMixConfidence\":\"user\"}"
        XCTAssertEqual(dive.displayGasMix, .nitrox(fO2: 0.32))

        let legacy = makeDive(at: Date(), depth: 18, seconds: 2400)
        legacy.sourceFormat = "seabear"
        XCTAssertNil(legacy.displayGasMix, "舊版匯入（無標記）同樣顯示未知")
    }

    /// PM 2026-10-07：「原始匯入資料」不顯示程式內部標記，只留來源資料。
    func testDisplayableImportExtrasHidesInternalMarkers() {
        let dive = makeDive(at: Date(), depth: 18, seconds: 2400)
        dive.importExtrasJSON = buildImportExtrasJSON([
            ("gasMixConfidence", "unknown"), ("dateTimeConfidence", "unknown"),
            (DiveImportKit.jd2RoundtripIDKey, "ABC"), (DiveImportKit.dateTimeFloatingKey, "true"),
            (DiveLog.gasVerifiedKey, "v0.7.6"), (DiveLog.garminGasVerifiedKey, "v0.7.2"),
            ("buddy", "Ann"), ("cns", "12"),
        ])
        XCTAssertEqual(dive.displayableImportExtras, ["buddy": "Ann", "cns": "12"])
    }

    func testAdapterMarksV073FormatsAsVerified() {
        let seabear = makeDiveLog(from: makeTestParsedDiveLog(
            dateTime: Date(), location: "", maxDepth: 18, diveTimeSeconds: 2400,
            roundtripID: nil, sourceFormat: "seabear"))
        XCTAssertEqual(seabear.importExtras[DiveLog.gasVerifiedKey], DiveLog.gasRuleCurrentKitVersion)
        let subsurface = makeDiveLog(from: makeTestParsedDiveLog(
            dateTime: Date(), location: "", maxDepth: 18, diveTimeSeconds: 2400,
            roundtripID: nil, sourceFormat: "Subsurface"))
        XCTAssertEqual(subsurface.importExtras[DiveLog.gasVerifiedKey], "v0.7.6")
        let dm5 = makeDiveLog(from: makeTestParsedDiveLog(
            dateTime: Date(), location: "", maxDepth: 18, diveTimeSeconds: 2400,
            roundtripID: nil, sourceFormat: "suunto-dm5"))
        XCTAssertNil(dm5.importExtras[DiveLog.gasVerifiedKey])
    }

    /// DiveImportKit v0.7.3：來源標示的自由潛水帶進 `diveMode`（DM5 Mode=3 等）。
    func testAdapterMapsFreediveMode() {
        var parsed = makeTestParsedDiveLog(dateTime: Date(), location: "", maxDepth: 12, diveTimeSeconds: 60,
                                           roundtripID: nil, sourceFormat: "suunto-dm5")
        parsed.diveMode = "free"
        XCTAssertEqual(makeDiveLog(from: parsed).diveModeValue, .free)
        parsed.diveMode = nil
        XCTAssertEqual(makeDiveLog(from: parsed).diveModeValue, .scuba)
    }

    /// PM 2026-10-06 裁示 B：剖面 CSV 的日期是代填值，不參與殘氮鏈；使用者改過日期後恢復。
    func testProfileCSVWithUnknownDateIsExcludedFromChain() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DiveLog.self, configurations: config)
        let context = ModelContext(container)
        let target = makeDive(at: Date(timeIntervalSince1970: 1_700_000_000))
        let csv = makeDive(at: target.dateTime.addingTimeInterval(-3 * 3600))
        csv.sourceFormat = "csv-profile"
        csv.importExtrasJSON = #"{"dateTimeConfidence":"unknown"}"#
        let real = makeDive(at: target.dateTime.addingTimeInterval(-5 * 3600))
        for d in [target, csv, real] { context.insert(d) }

        var preceding = DiveReplayChainQuery.precedingDives(of: target, in: context)
        XCTAssertEqual(preceding.map(\.dateTime), [real.dateTime], "代填日期的紀錄不得進入殘氮鏈")

        csv.importExtrasJSON = #"{"dateTimeConfidence":"user"}"#
        preceding = DiveReplayChainQuery.precedingDives(of: target, in: context)
        XCTAssertEqual(preceding.count, 2, "使用者核對過日期後恢復參與")

        csv.importExtrasJSON = "{}"
        XCTAssertTrue(csv.hasUnknownDateTime, "舊版匯入沒有標記，但此格式本來就沒有日期")
    }

    // MARK: - ③ 前導潛水查詢（96h 窗口）

    func testPrecedingDivesQueryWindow() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DiveLog.self, configurations: config)
        let context = ModelContext(container)

        let target = makeDive(at: Date(timeIntervalSince1970: 1_700_000_000))
        let sameDay = makeDive(at: target.dateTime.addingTimeInterval(-4 * 3600))
        // ⚠️ 這個 48 是「兩天前」的時間算術，與 `algorithmLockHours` 無關（2026-09-21 註）。
        let twoDaysAgo = makeDive(at: target.dateTime.addingTimeInterval(-48 * 3600))
        let ancient = makeDive(at: target.dateTime.addingTimeInterval(-200 * 3600))
        let later = makeDive(at: target.dateTime.addingTimeInterval(3 * 3600))
        for d in [target, sameDay, twoDaysAgo, ancient, later] { context.insert(d) }

        let preceding = DiveReplayChainQuery.precedingDives(of: target, in: context)
        let dates = Set(preceding.map(\.dateTime))
        XCTAssertEqual(preceding.count, 2, "只應取回 96h 內、目標之前的兩筆")
        XCTAssertTrue(dates.contains(sameDay.dateTime))
        XCTAssertTrue(dates.contains(twoDaysAgo.dateTime))
        XCTAssertFalse(dates.contains(ancient.dateTime), "96h 硬上界之外不得取回")
        XCTAssertFalse(dates.contains(later.dateTime), "目標之後的紀錄不是前導潛水")
        XCTAssertFalse(dates.contains(target.dateTime), "目標潛水自己不得出現在候選集合")
    }

    /// PM 2026-10-10：自由潛水或短於 4 分鐘 ⇒ 剖面 X 軸用秒。
    func testProfileTimeAxisInSeconds() {
        let shortScuba = makeDive(at: Date(), depth: 20, seconds: 70)
        XCTAssertTrue(shortScuba.profileTimeAxisInSeconds, "70 s 水肺（讀不到模式的自由潛水）")
        let boundary = makeDive(at: Date(), depth: 20, seconds: 240)
        XCTAssertFalse(boundary.profileTimeAxisInSeconds, "剛好 4 分鐘用分鐘")
        let longFree = makeDive(at: Date(), depth: 20, seconds: 400)
        longFree.diveModeValue = .free
        XCTAssertTrue(longFree.profileTimeAxisInSeconds)
        XCTAssertFalse(makeDive(at: Date(), depth: 20, seconds: 2400).profileTimeAxisInSeconds)
    }
}
