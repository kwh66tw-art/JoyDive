// LegacyAltitudePrecedingDiveFactsTests.swift — JD2-LogbookTests
// v1.4 稽核 T18（`docs/V1_4_AUDIT_TEST_PLAN.md` F3）：記錄事實，交 PM 裁示 D-A。
// PM 2026-10-26 裁示：主案 a'（Kit 加 `environmentUntrusted`）、v1.4 暫行 a（App 層：96h 候選有一筆被擋 ⇒ 目標不支援）。
// 事實 2–4 是 **Kit 層**的行為（不受暫行 a 影響）；App 層閘門的行為另見下方 `testInterimGate…`。
//
// 問題：A1 的 App 層閘門（`DiveLog.isReplayBlockedByLegacyAltitude`）只擋**目標潛水**。
// 舊標籤高海拔＋預設 1.0 bar 的紀錄若是**前導潛水**，會不會進殘氮鏈、影響後一支潛水的組織負荷？
// 這裡的斷言鎖的是「現況」；PM 裁示後若要改行為，相應斷言會紅——那是預期的。

import XCTest
import Foundation
import SwiftData
import DiveKit
@testable import JoyDive_

@MainActor
final class LegacyAltitudePrecedingDiveFactsTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDive(at date: Date, depth: Double = 25, seconds: Int = 2400,
                          environment: String?, surfacePressure: Double) -> DiveLog {
        let dive = DiveLog(dateTime: date, location: "T18", maxDepth: depth, diveTimeSeconds: seconds)
        let samples = [
            JoyDive_.DiveProfileSample(timeSeconds: 0, depthMeters: 0),
            JoyDive_.DiveProfileSample(timeSeconds: 120, depthMeters: depth),
            JoyDive_.DiveProfileSample(timeSeconds: Double(seconds) - 120, depthMeters: depth),
            JoyDive_.DiveProfileSample(timeSeconds: Double(seconds), depthMeters: 0),
        ]
        dive.profileSamplesJSON = String(data: try! JSONEncoder().encode(samples), encoding: .utf8)!
        dive.environmentType = environment
        dive.surfacePressureBar = surfacePressure
        return dive
    }

    /// 目標潛水最後一個重放點的 16 隔室負荷百分比（%，`DiveReplayEngine.tissueLoadPercent`）。
    private func finalLoads(_ outcome: DiveReplayEngine.ChainOutcome, environment: DiveEnvironment) -> [Double]? {
        guard case .replayed(let result) = outcome, let last = result.points.last else { return nil }
        return DiveReplayEngine.tissueLoadPercent(pN2: last.tissuePN2, pHe: last.tissuePHe, environment: environment)
    }

    func testFactsForLegacyAltitudeAsPrecedingDive() throws {
        let container = try ModelContainer(for: DiveLog.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        // 前一支：舊標籤高海拔、氣壓為預設 1.0（實際應約 0.8）。後一支：3 小時後的海水潛水。
        let legacy = makeDive(at: base, environment: "altitude", surfacePressure: 1.0)
        let target = makeDive(at: base.addingTimeInterval(3 * 3600), environment: "seawater", surfacePressure: 1.0)
        for d in [legacy, target] { context.insert(d) }

        // 事實 1：前導查詢不過濾舊標籤 ⇒ 它在候選集合裡；目標本身不受閘門擋。
        let preceding = DiveReplayChainQuery.precedingDives(of: target, in: context)
        XCTAssertEqual(preceding.map(\.dateTime), [legacy.dateTime], "現況：舊標籤高海拔紀錄會被當作前導潛水")
        XCTAssertTrue(legacy.isReplayBlockedByLegacyAltitude)
        XCTAssertFalse(target.isReplayBlockedByLegacyAltitude)
        // ⏸ 暫行 a（PM 2026-10-26 D-A）：App 層閘門因前導而擋下目標。Kit a' 上線後此斷言改為走 Kit。
        XCTAssertEqual(LegacyAltitudeReplayGate.blockReason(target: target, precedingDives: preceding), .precedingDive)

        // 事實 2：Kit 照算（兩筆都是 1.0 bar，環境一致）。
        let withLegacy = DiveReplayEngine.replayChain(target: target.replayInput,
                                                      precedingDives: preceding.map(\.replayInput))
        let alone = DiveReplayEngine.replayChain(target: target.replayInput, precedingDives: [])
        let env = target.replayEnvironment
        let loadsWith = try XCTUnwrap(finalLoads(withLegacy, environment: env), "現況：Kit 不拒算")
        let loadsAlone = try XCTUnwrap(finalLoads(alone, environment: env))

        // 事實 3：前一支的殘氮有算進去（後一支負荷較高）。
        XCTAssertGreaterThan(loadsWith.max()!, loadsAlone.max()!)

        // 事實 4：若前一支當初存的是真實高海拔氣壓（0.8），Kit 判環境不一致而拒算（容差 0.05 bar）。
        let honest = makeDive(at: base, environment: "altitude", surfacePressure: 0.8)
        let honestOutcome = DiveReplayEngine.replayChain(target: target.replayInput,
                                                         precedingDives: [honest.replayInput])
        guard case .anomaly(.inconsistentEnvironment) = honestOutcome else {
            return XCTFail("預期 inconsistentEnvironment，實際：\(honestOutcome)")
        }

        // 數字（寫進稽核計劃 T18）
        let fmt = { (xs: [Double]) in xs.map { String(format: "%.1f", $0) }.joined(separator: ",") }
        let report = """
        T18 FACT max load with legacy preceding = \(String(format: "%.1f", loadsWith.max()!))%, alone = \(String(format: "%.1f", loadsAlone.max()!))%
        T18 FACT loads with legacy = [\(fmt(loadsWith))]
        T18 FACT loads alone       = [\(fmt(loadsAlone))]
        """
        print(report)
        // 主控台輸出不進 run_tests.sh 的 log ⇒ 稽核取數時以 `TEST_RUNNER_JD2_T18_OUT=<主機路徑>` 執行，另寫一份。
        if let out = ProcessInfo.processInfo.environment["JD2_T18_OUT"], !out.isEmpty {
            try? report.write(toFile: out, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - ⏸ 暫行 a 閘門（PM 2026-10-26 D-A；Kit a' 上線後移除）

    func testInterimGateBlocksOnlyForNonBreathHoldLegacyPreceding() {
        let target = makeDive(at: base.addingTimeInterval(3 * 3600), environment: "seawater", surfacePressure: 1.0)
        let legacy = makeDive(at: base, environment: "altitude", surfacePressure: 1.0)
        let honest = makeDive(at: base, environment: "altitude", surfacePressure: 0.8)
        let sea = makeDive(at: base, environment: nil, surfacePressure: 1.0)
        let legacyFree = makeDive(at: base, environment: "altitude", surfacePressure: 1.0)
        legacyFree.diveModeValue = .free

        XCTAssertNil(LegacyAltitudeReplayGate.blockReason(target: target, precedingDives: []))
        XCTAssertNil(LegacyAltitudeReplayGate.blockReason(target: target, precedingDives: [sea, honest]),
                     "有實測氣壓或非舊標籤的前導不擋（真實氣壓的不一致交給 Kit 判）")
        XCTAssertEqual(LegacyAltitudeReplayGate.blockReason(target: target, precedingDives: [sea, legacy]), .precedingDive)
        XCTAssertNil(LegacyAltitudeReplayGate.blockReason(target: target, precedingDives: [legacyFree]),
                     "閉氣前導不進鏈（Kit 建鏈時濾掉），不擋")
        // 目標本身被擋優先回 .target
        let legacyTarget = makeDive(at: base.addingTimeInterval(3 * 3600), environment: "altitude", surfacePressure: 1.0)
        XCTAssertEqual(LegacyAltitudeReplayGate.blockReason(target: legacyTarget, precedingDives: [legacy]), .target)
    }

    /// 兩種原因的字串鍵不同、且都有 zh-Hant 草稿（其餘語言待上架前收尾）。
    func testInterimGateReasonKeysAreDistinct() {
        XCTAssertNotEqual(DiveAnalysisView.legacyAltitudeReasonKey(.target),
                          DiveAnalysisView.legacyAltitudeReasonKey(.precedingDive))
    }
}
