// TissueLoadingSupportPerformanceTests.swift — JD2-LogbookTests
// v1.4 A3 條件 3（`docs/V1_4_WORK_PLAN.md`）：先量再優化。2,000 筆 × 300 個剖面樣本，
// 一天三潛（每筆的 96h 窗口內約 11 筆前導候選），量「篩選開啟時判定全部紀錄」的耗時。
// 這段跑在 `@MainActor`（Kit `precheck` 是 `@MainActor`）⇒ 耗時就是 UI 卡住的時間。
//
// 本測試**只記錄數字、不以門檻判紅綠**（同 T26）；可接受與否交 PM。不夠快才考慮請 Kit 加摘要版 precheck
// （Kit 改動，走鐵律 3／8），不得在 App 內繞道。
// 取數：以 `TEST_RUNNER_JD2_A3_OUT=<主機路徑>` 執行時另寫一份報告。
// ⚠️ 量的是 Debug build（測試預設），Release 通常更快 ⇒ 偏保守的數字。

import XCTest
import Foundation
import SwiftData
import DiveKit
@testable import JoyDive_

@MainActor
final class TissueLoadingSupportPerformanceTests: XCTestCase {

    func testJudgingAllDivesWith2000DivesAnd300Samples() throws {
        let container = try ModelContainer(for: DiveLog.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let sampleCount = 300
        let seconds = 2700
        let start = Date(timeIntervalSince1970: 1_600_000_000)
        for i in 0..<2000 {
            let day = Double(i / 3), slot = Double(i % 3)
            let depth = 12.0 + Double(i % 7) * 3
            let dive = DiveLog(dateTime: start.addingTimeInterval(day * 86_400 + slot * 4 * 3600),
                               location: "Perf #\(i)", maxDepth: depth, diveTimeSeconds: seconds)
            let profile = (0..<sampleCount).map { k -> JoyDive_.DiveProfileSample in
                let t = Double(k) * Double(seconds) / Double(sampleCount - 1)
                let d = min(depth, t / 60 * 18, (Double(seconds) - t) / 60 * 9)
                return JoyDive_.DiveProfileSample(timeSeconds: t, depthMeters: max(0, d))
            }
            dive.profileSamplesJSON = String(data: try JSONEncoder().encode(profile), encoding: .utf8)!
            dive.gasMixJSON = i % 4 == 0 ? "{\"nitrox\":{\"fO2\":0.32}}" : "\"air\""
            dive.environmentType = "seawater"
            context.insert(dive)
        }
        try context.save()

        let clock = ContinuousClock()
        let msOf = { (d: Duration) in Double(d.components.attoseconds) / 1e15 + Double(d.components.seconds) * 1000 }

        var sorted: [DiveLog] = []
        let fetch = clock.measure {
            sorted = (try? context.fetch(FetchDescriptor<DiveLog>(sortBy: [SortDescriptor(\.dateTime, order: .forward)]))) ?? []
        }
        XCTAssertEqual(sorted.count, 2000)

        var supported = Set<PersistentIdentifier>()
        let judge = clock.measure { supported = TissueLoadingSupport.supportedIDs(in: sorted) }
        let judgeAgain = clock.measure { _ = TissueLoadingSupport.supportedIDs(in: sorted) }

        // 拆成本：剖面 JSON 解碼、輸入映射、前導挑選——分出 Kit `precheck` 以外的部分。
        let decode = clock.measure { _ = sorted.reduce(0) { $0 + $1.profileSamples.count } }
        let mapping = clock.measure { _ = sorted.map(\.replayInput).count }
        let picking = clock.measure {
            _ = sorted.reduce(0) { $0 + DiveReplayChainQuery.precedingDives(of: $1, inAscending: sorted).count }
        }
        let inputs = sorted.map(\.replayInput)
        let precedingIndices = sorted.map { DiveReplayChainQuery.precedingIndices(of: $0, inAscending: sorted) }
        let precheckOnly = clock.measure {
            for index in inputs.indices {
                _ = DiveReplayEngine.precheck(target: inputs[index], precedingDives: precedingIndices[index].map { inputs[$0] })
            }
        }
        let avgCandidates = Double(sorted.reduce(0) {
            $0 + DiveReplayChainQuery.precedingDives(of: $1, inAscending: sorted).count
        }) / Double(sorted.count)

        var report = "A3 tissue-loading judgement (2000 dives x \(sampleCount) samples, 3 dives/day, Debug)\n"
        report += String(format: "  fetch sorted              = %8.1f ms\n", msOf(fetch))
        report += String(format: "  judge all (1st)           = %8.1f ms\n", msOf(judge))
        report += String(format: "  judge all (2nd)           = %8.1f ms\n", msOf(judgeAgain))
        report += String(format: "  profile JSON decode x2000 = %8.1f ms\n", msOf(decode))
        report += String(format: "  replayInput map x2000     = %8.1f ms\n", msOf(mapping))
        report += String(format: "  preceding pick x2000      = %8.1f ms\n", msOf(picking))
        report += String(format: "  Kit precheck only x2000   = %8.1f ms\n", msOf(precheckOnly))
        report += String(format: "  avg preceding candidates  = %8.1f\n", avgCandidates)
        report += "  supported = \(supported.count) / \(sorted.count)\n"
        print(report)
        // 一天三潛、每潛 45 分鐘、間隔約 3 小時：全部可算才代表量到的是完整 precheck 路徑（沒有提早拒算）。
        XCTAssertEqual(supported.count, sorted.count, "效能 fixture 應全部可算")
        if let out = ProcessInfo.processInfo.environment["JD2_A3_OUT"], !out.isEmpty {
            try? report.write(toFile: out, atomically: true, encoding: .utf8)
        }
    }
}
