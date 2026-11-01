// TissueLoadingSupportTests.swift — JD2-LogbookTests
// v1.4 A3 列表篩選「組織負荷：支援／不支援」（`docs/V1_4_WORK_PLAN.md` A3 三個條件）。
//
// 條件 1：前導候選挑法只有一份——資料庫路徑（詳細頁）與陣列路徑（列表）挑出同一批。
// 條件 2：一致性——每一筆的篩選判定 == 詳細頁的結果（樣本 ≥ 2 且 `replayChain` 為 `.replayed`）。
// fixture 涵蓋本 App 資料會觸發的每一種拒算原因，再加上「沒有剖面」與正常可算的對照。

import XCTest
import Foundation
import SwiftData
import DiveKit
@testable import JoyDive_

@MainActor
final class TissueLoadingSupportTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDive(_ label: String, hoursAfterBase hours: Double, depth: Double = 25, seconds: Int = 2400,
                          samples: Bool = true, gasJSON: String = "\"air\"") -> DiveLog {
        let dive = DiveLog(dateTime: base.addingTimeInterval(hours * 3600), location: label,
                           maxDepth: depth, diveTimeSeconds: seconds)
        if samples {
            let profile = [
                JoyDive_.DiveProfileSample(timeSeconds: 0, depthMeters: 0),
                JoyDive_.DiveProfileSample(timeSeconds: 120, depthMeters: depth),
                JoyDive_.DiveProfileSample(timeSeconds: Double(seconds) - 120, depthMeters: depth),
                JoyDive_.DiveProfileSample(timeSeconds: Double(seconds), depthMeters: 0),
            ]
            dive.profileSamplesJSON = String(data: try! JSONEncoder().encode(profile), encoding: .utf8)!
        }
        dive.gasMixJSON = gasJSON
        dive.environmentType = "seawater"
        return dive
    }

    private func setExtras(_ dive: DiveLog, _ extras: [String: String]) {
        dive.importExtrasJSON = String(data: try! JSONEncoder().encode(extras), encoding: .utf8)!
    }

    /// 每組相隔 10 天（> 96h）互不影響；組內用小時偏移排出前導關係。
    private func fixture() -> [(DiveLog, expectSupported: Bool)] {
        var rows: [(DiveLog, Bool)] = []
        var day = 0.0
        func group(_ build: (Double) -> [(DiveLog, Bool)]) { rows += build(day * 24); day += 10 }

        group { h in [(makeDive("ok-single", hoursAfterBase: h), true)] }
        group { h in [(makeDive("ok-chain-1", hoursAfterBase: h), true),
                      (makeDive("ok-chain-2", hoursAfterBase: h + 3), true)] }
        group { h in [(makeDive("no-samples", hoursAfterBase: h, samples: false), false)] }
        group { h in
            let one = makeDive("one-sample", hoursAfterBase: h)
            one.profileSamplesJSON = "[{\"t\":0,\"d\":10}]"
            return [(one, false)]
        }
        group { h in [(makeDive("nitrox", hoursAfterBase: h, gasJSON: "{\"nitrox\":{\"fO2\":0.32}}"), true)] }
        group { h in [(makeDive("trimix", hoursAfterBase: h, gasJSON: "{\"trimix\":{\"fO2\":0.18,\"fHe\":0.45}}"), false)] }
        group { h in
            let unknownGas = makeDive("unknown-gas", hoursAfterBase: h)
            setExtras(unknownGas, ["gasMixConfidence": "unknown"])
            return [(unknownGas, false)]
        }
        group { h in [(makeDive("undecodable-gas", hoursAfterBase: h, gasJSON: "garbage"), false)] }
        group { h in
            let free = makeDive("freedive", hoursAfterBase: h, depth: 10, seconds: 90)
            free.diveMode = DiveLogMode.free.rawValue
            return [(free, false)]
        }
        group { h in
            let legacy = makeDive("legacy-altitude", hoursAfterBase: h)
            legacy.environmentType = DiveLog.legacyAltitudeEnvironmentType
            return [(legacy, false)]
        }
        group { h in
            let legacy = makeDive("legacy-preceding", hoursAfterBase: h)
            legacy.environmentType = DiveLog.legacyAltitudeEnvironmentType
            return [(legacy, false), (makeDive("after-legacy", hoursAfterBase: h + 3), false)]
        }
        group { h in
            let bad = makeDive("implausible-pressure", hoursAfterBase: h)
            bad.surfacePressureBar = 0
            return [(bad, false)]
        }
        group { h in
            let lake = makeDive("altitude-lake", hoursAfterBase: h)
            lake.surfacePressureBar = 0.80
            return [(lake, true), (makeDive("sea-after-lake", hoursAfterBase: h + 3), false)]   // 不同環境不可同鏈
        }
        group { h in [(makeDive("preceding-no-samples", hoursAfterBase: h, samples: false), false),
                      (makeDive("after-no-samples", hoursAfterBase: h + 3), false)] }
        group { h in [(makeDive("overlap-a", hoursAfterBase: h), true),
                      (makeDive("overlap-b", hoursAfterBase: h + 0.25), false)] }
        group { h in
            let csv = makeDive("csv-profile-date", hoursAfterBase: h + 1, samples: false)
            csv.sourceFormat = "csv-profile"   // 日期代填 ⇒ 不參與殘氮鏈 ⇒ 不會擋到後面那筆
            return [(csv, false), (makeDive("after-csv", hoursAfterBase: h + 3), true)]
        }
        group { h in [(makeDive("negligible-preceding", hoursAfterBase: h, samples: false), false),
                      (makeDive("90h-later", hoursAfterBase: h + 90), true)] }   // 截斷後不在鏈中
        return rows
    }

    private func insertFixture() throws -> (ModelContext, [(DiveLog, Bool)], [DiveLog]) {
        let container = try ModelContainer(for: DiveLog.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let rows = fixture()
        for (dive, _) in rows { context.insert(dive) }
        try context.save()
        let sorted = try context.fetch(FetchDescriptor<DiveLog>(sortBy: [SortDescriptor(\.dateTime, order: .forward)]))
        return (context, rows, sorted)
    }

    /// 詳細頁的結果：樣本 ≥ 2 才進重放畫面，`replayChain` 不是 `.anomaly` 才畫組織負荷。
    private func detailPageShowsTissueLoading(_ dive: DiveLog, context: ModelContext) -> Bool {
        guard dive.profileSamples.count >= 2 else { return false }
        let preceding = DiveReplayChainQuery.precedingDives(of: dive, in: context)
        if case .replayed = DiveReplayEngine.replayChain(target: dive.replayInput,
                                                        precedingDives: preceding.map(\.replayInput)) {
            return true
        }
        return false
    }

    // MARK: - 條件 1

    func testArrayAndDatabasePathsPickTheSamePrecedingDives() throws {
        let (context, rows, sorted) = try insertFixture()
        for (dive, _) in rows {
            let fromDatabase = DiveReplayChainQuery.precedingDives(of: dive, in: context).map(\.persistentModelID)
            let fromArray = DiveReplayChainQuery.precedingDives(of: dive, inAscending: sorted).map(\.persistentModelID)
            XCTAssertEqual(fromArray, fromDatabase, dive.location)
        }
    }

    /// 窗口邊界：剛好 96h 前算在內、同一時刻與之後不算；日期代填排除；超過上限只取最早的 64 筆。
    func testWindowBoundariesAndCandidateLimit() throws {
        let container = try ModelContainer(for: DiveLog.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let target = makeDive("target", hoursAfterBase: 200)
        let atEdge = makeDive("edge", hoursAfterBase: 200 - 96)
        let justOutside = makeDive("outside", hoursAfterBase: 200 - 96 - 0.001)
        let sameTime = makeDive("same-time", hoursAfterBase: 200)
        let after = makeDive("after", hoursAfterBase: 201)
        let csv = makeDive("csv", hoursAfterBase: 150)
        csv.sourceFormat = "csv-profile"
        var many: [DiveLog] = []
        for i in 0..<70 { many.append(makeDive("many-\(i)", hoursAfterBase: 120 + Double(i) * 0.5, samples: false)) }
        for d in [target, atEdge, justOutside, sameTime, after, csv] + many { context.insert(d) }
        try context.save()
        let sorted = try context.fetch(FetchDescriptor<DiveLog>(sortBy: [SortDescriptor(\.dateTime, order: .forward)]))

        let picked = DiveReplayChainQuery.precedingDives(of: target, inAscending: sorted)
        XCTAssertEqual(picked.first?.location, "edge", "剛好 96h 前算在窗口內")
        XCTAssertFalse(picked.contains { ["outside", "same-time", "after", "target", "csv"].contains($0.location) })
        // 窗口內共 1(edge)+1(csv)+70 = 72 筆 ⇒ 取最早 64 筆，再排除 csv ⇒ 63 筆
        XCTAssertEqual(picked.count, DiveReplayChainQuery.candidateLimit - 1)
        XCTAssertEqual(picked.map(\.persistentModelID),
                       DiveReplayChainQuery.precedingDives(of: target, in: context).map(\.persistentModelID))
    }

    // MARK: - 條件 2

    func testListJudgementMatchesDetailPageForEveryFixtureDive() throws {
        let (context, rows, sorted) = try insertFixture()
        let supported = TissueLoadingSupport.supportedIDs(in: sorted)
        for (dive, expected) in rows {
            let detail = detailPageShowsTissueLoading(dive, context: context)
            XCTAssertEqual(supported.contains(dive.persistentModelID), detail, "列表與詳細頁不一致：\(dive.location)")
            XCTAssertEqual(detail, expected, "fixture 預期：\(dive.location)")
        }
        // fixture 兩種結果都要有，否則這支測試分不出「全部判支援」或「全部判不支援」的錯。
        XCTAssertTrue(rows.contains { $0.1 } && rows.contains { !$0.1 })
    }

    // MARK: - 逐步判定（列表實際用的路徑）

    /// `TissueLoadingJudge`（由新到舊、分段、快取）與一次判定全部的結果逐筆相同。
    func testProgressiveJudgeMatchesBatchJudgement() async throws {
        let (_, rows, sorted) = try insertFixture()
        let judge = TissueLoadingJudge()
        await judge.update(sortedAscending: sorted)
        let batch = TissueLoadingSupport.supportedIDs(in: sorted)
        XCTAssertEqual(judge.results.count, rows.count, "每一筆都要有結果")
        for (dive, _) in rows {
            XCTAssertEqual(judge.results[dive.persistentModelID], batch.contains(dive.persistentModelID), dive.location)
        }
        XCTAssertFalse(judge.isComputing)
    }

    /// 快取失效：前導那筆被編輯（改成舊標籤高海拔）⇒ 後面那筆的結果跟著更新；刪除 ⇒ 結果移除且後面那筆恢復。
    func testProgressiveJudgeInvalidatesWhenPrecedingDiveChanges() async throws {
        let container = try ModelContainer(for: DiveLog.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let first = makeDive("first", hoursAfterBase: 0)
        let second = makeDive("second", hoursAfterBase: 3)
        for d in [first, second] { context.insert(d) }
        try context.save()
        func sorted() throws -> [DiveLog] {
            try context.fetch(FetchDescriptor<DiveLog>(sortBy: [SortDescriptor(\.dateTime, order: .forward)]))
        }

        let judge = TissueLoadingJudge()
        await judge.update(sortedAscending: try sorted())
        XCTAssertEqual(judge.results[second.persistentModelID], true)

        first.environmentType = DiveLog.legacyAltitudeEnvironmentType   // 前導變成不可信 ⇒ 擋到後面那筆
        await judge.update(sortedAscending: try sorted())
        XCTAssertEqual(judge.results[first.persistentModelID], false)
        XCTAssertEqual(judge.results[second.persistentModelID], false, "前導變動要讓後面那筆重算")

        let firstID = first.persistentModelID
        context.delete(first)
        try context.save()
        await judge.update(sortedAscending: try sorted())
        XCTAssertNil(judge.results[firstID])
        XCTAssertEqual(judge.results[second.persistentModelID], true, "前導刪除 ⇒ 候選集合變了 ⇒ 重算")
    }
}
