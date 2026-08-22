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

    // MARK: - ③ 前導潛水查詢（96h 窗口）

    func testPrecedingDivesQueryWindow() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DiveLog.self, configurations: config)
        let context = ModelContext(container)

        let target = makeDive(at: Date(timeIntervalSince1970: 1_700_000_000))
        let sameDay = makeDive(at: target.dateTime.addingTimeInterval(-4 * 3600))
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
}
