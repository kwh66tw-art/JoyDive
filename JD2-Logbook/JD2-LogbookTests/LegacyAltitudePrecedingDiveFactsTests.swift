// LegacyAltitudePrecedingDiveFactsTests.swift — JD2-LogbookTests
// v1.4 稽核 T18（`docs/V1_4_AUDIT_TEST_PLAN.md` F3）→ D-A（`docs/decisions/D-2026-10-26-DA-舊標籤高海拔前導潛水-聯合提案.md`）。
//
// 舊標籤高海拔＋預設 1.0 bar 的紀錄，作為**目標**或**前導**潛水時，重放怎麼處理？
// PM 2026-10-26 主案 a'：DiveKit v9.7.0 `DiveInput.environmentUntrusted`（`DiveLog.replayInput` 映射）。
// 目標被標記一律擋；前導**在殘氮上界截斷之後**仍留在鏈中才擋（`_JD2-family/decisions/2026-08-22_…設計.md` §六之二）。
// 原 v1.4 暫行 a（App 層：96h 候選有一筆就擋）已移除——`testNegligibleLegacyPrecedingDoesNotBlock` 正是它過度觸發的情境。

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

    /// 同一筆輸入、但清掉 `environmentUntrusted`——用來對照「沒有這個旗標時 Kit 會算出什麼」。
    private func clearingUntrusted(_ input: DiveReplayEngine.DiveInput) -> DiveReplayEngine.DiveInput {
        DiveReplayEngine.DiveInput(startedAt: input.startedAt, durationSeconds: input.durationSeconds,
                                   profileSamples: input.profileSamples, maxDepthMeters: input.maxDepthMeters,
                                   gasMix: input.gasMix, environment: input.environment,
                                   recordedSeriesIndex: input.recordedSeriesIndex, isBreathHold: input.isBreathHold,
                                   gasMixConfidence: input.gasMixConfidence)
    }

    /// 目標潛水最後一個重放點的 16 隔室負荷百分比（%，`DiveReplayEngine.tissueLoadPercent`）。
    private func finalLoads(_ outcome: DiveReplayEngine.ChainOutcome, environment: DiveEnvironment) -> [Double]? {
        guard case .replayed(let result) = outcome, let last = result.points.last else { return nil }
        return DiveReplayEngine.tissueLoadPercent(pN2: last.tissuePN2, pHe: last.tissuePHe, environment: environment)
    }

    private func reason(_ outcome: DiveReplayEngine.ChainOutcome) -> LegacyAltitudeReplayGate.Reason? {
        guard case .anomaly(let anomaly) = outcome else { return nil }
        return LegacyAltitudeReplayGate.reason(for: anomaly)
    }

    /// 3 小時前的舊標籤前導：殘氮不可忽略 ⇒ 留在鏈中 ⇒ Kit 回 `untrustedEnvironment`（前導）。
    func testLegacyAltitudeAsRecentPrecedingDiveIsBlockedByKit() throws {
        let container = try ModelContainer(for: DiveLog.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let legacy = makeDive(at: base, environment: "altitude", surfacePressure: 1.0)
        let target = makeDive(at: base.addingTimeInterval(3 * 3600), environment: "seawater", surfacePressure: 1.0)
        for d in [legacy, target] { context.insert(d) }

        // 前導查詢不過濾舊標籤（判定交給 Kit）；映射時標記為不可信。
        let preceding = DiveReplayChainQuery.precedingDives(of: target, in: context)
        XCTAssertEqual(preceding.map(\.dateTime), [legacy.dateTime])
        XCTAssertTrue(legacy.replayInput.environmentUntrusted)
        XCTAssertFalse(target.replayInput.environmentUntrusted)

        let outcome = DiveReplayEngine.replayChain(target: target.replayInput,
                                                   precedingDives: preceding.map(\.replayInput))
        guard case .anomaly(.untrustedEnvironment(chainIndex: 0, isTargetDive: false)) = outcome else {
            return XCTFail("預期前導 untrustedEnvironment，實際：\(outcome)")
        }
        XCTAssertEqual(reason(outcome), .precedingDive)

        // 對照（T18 原始事實）：沒有旗標時 Kit 會照算，且前一支的殘氮有算進去（後一支負荷較高）。
        let env = target.replayEnvironment
        let unflagged = DiveReplayEngine.replayChain(target: target.replayInput,
                                                     precedingDives: preceding.map { clearingUntrusted($0.replayInput) })
        let alone = DiveReplayEngine.replayChain(target: target.replayInput, precedingDives: [])
        let loadsWith = try XCTUnwrap(finalLoads(unflagged, environment: env))
        let loadsAlone = try XCTUnwrap(finalLoads(alone, environment: env))
        XCTAssertGreaterThan(loadsWith.max()!, loadsAlone.max()!)

        // 對照：前一支若存的是真實高海拔氣壓（0.8），Kit 判環境不一致而拒算（容差 0.05 bar）——非本旗標。
        let honest = makeDive(at: base, environment: "altitude", surfacePressure: 0.8)
        XCTAssertFalse(honest.replayInput.environmentUntrusted)
        let honestOutcome = DiveReplayEngine.replayChain(target: target.replayInput,
                                                         precedingDives: [honest.replayInput])
        guard case .anomaly(.inconsistentEnvironment) = honestOutcome else {
            return XCTFail("預期 inconsistentEnvironment，實際：\(honestOutcome)")
        }
        XCTAssertNil(reason(honestOutcome), "環境不一致維持通用句，不顯示舊標籤原因")

        // 數字（寫進稽核計劃 T18）：以 `TEST_RUNNER_JD2_T18_OUT=<主機路徑>` 執行時另寫一份。
        let fmt = { (xs: [Double]) in xs.map { String(format: "%.1f", $0) }.joined(separator: ",") }
        let report = """
        T18 FACT (unflagged) max load with legacy preceding = \(String(format: "%.1f", loadsWith.max()!))%, alone = \(String(format: "%.1f", loadsAlone.max()!))%
        T18 FACT loads with legacy = [\(fmt(loadsWith))]
        T18 FACT loads alone       = [\(fmt(loadsAlone))]
        """
        if let out = ProcessInfo.processInfo.environment["JD2_T18_OUT"], !out.isEmpty {
            try? report.write(toFile: out, atomically: true, encoding: .utf8)
        }
    }

    /// 90 小時前、殘氮可忽略的舊標籤前導：Kit 先截斷 ⇒ 不進鏈 ⇒ 目標照常重放（暫行 a 會在這裡誤擋）。
    func testNegligibleLegacyPrecedingDoesNotBlock() throws {
        let container = try ModelContainer(for: DiveLog.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let legacy = makeDive(at: base, environment: "altitude", surfacePressure: 1.0)
        let target = makeDive(at: base.addingTimeInterval(90 * 3600), environment: "seawater", surfacePressure: 1.0)
        for d in [legacy, target] { context.insert(d) }

        let preceding = DiveReplayChainQuery.precedingDives(of: target, in: context)
        XCTAssertEqual(preceding.map(\.dateTime), [legacy.dateTime], "仍在 96h 候選內")
        XCTAssertTrue(legacy.replayInput.environmentUntrusted)

        let outcome = DiveReplayEngine.replayChain(target: target.replayInput,
                                                   precedingDives: preceding.map(\.replayInput))
        guard case .replayed(let result) = outcome else {
            return XCTFail("預期照常重放（前導已截斷），實際：\(outcome)")
        }
        XCTAssertEqual(result.chainDiveCount, 1, "舊標籤前導被截斷，鏈中只剩目標")
    }

    /// 目標本身是舊標籤高海拔＋預設氣壓：Kit 回 `untrustedEnvironment`（目標）。
    func testLegacyAltitudeTargetIsBlockedByKit() {
        let target = makeDive(at: base, environment: "altitude", surfacePressure: 1.0)
        let outcome = DiveReplayEngine.replayChain(target: target.replayInput, precedingDives: [])
        guard case .anomaly(.untrustedEnvironment(_, isTargetDive: true)) = outcome else {
            return XCTFail("預期目標 untrustedEnvironment，實際：\(outcome)")
        }
        XCTAssertEqual(reason(outcome), .target)

        // 有實測氣壓的高海拔、或未記錄環境：不標記、照常重放（同環境，無前導）。
        for honest in [makeDive(at: base, environment: "altitude", surfacePressure: 0.8),
                       makeDive(at: base, environment: nil, surfacePressure: 1.0)] {
            XCTAssertFalse(honest.replayInput.environmentUntrusted)
            guard case .replayed = DiveReplayEngine.replayChain(target: honest.replayInput, precedingDives: []) else {
                return XCTFail("未標記的紀錄應照常重放")
            }
        }
    }

    /// 閉氣的舊標籤前導：Kit 建鏈時就濾掉，不擋。
    func testBreathHoldLegacyPrecedingDoesNotBlock() {
        let legacyFree = makeDive(at: base, environment: "altitude", surfacePressure: 1.0)
        legacyFree.diveModeValue = .free
        let target = makeDive(at: base.addingTimeInterval(3 * 3600), environment: "seawater", surfacePressure: 1.0)
        let outcome = DiveReplayEngine.replayChain(target: target.replayInput,
                                                   precedingDives: [legacyFree.replayInput])
        guard case .replayed = outcome else {
            return XCTFail("閉氣前導不進鏈，應照常重放，實際：\(outcome)")
        }
    }

    /// 只有 `untrustedEnvironment` 對應舊標籤原因句；其他拒算維持通用句。
    func testReasonMappingOnlyForUntrustedEnvironment() {
        XCTAssertEqual(LegacyAltitudeReplayGate.reason(for: .untrustedEnvironment(chainIndex: 1, isTargetDive: true)), .target)
        XCTAssertEqual(LegacyAltitudeReplayGate.reason(for: .untrustedEnvironment(chainIndex: 0, isTargetDive: false)), .precedingDive)
        XCTAssertNil(LegacyAltitudeReplayGate.reason(for: .inconsistentEnvironment(chainIndex: 0)))
        XCTAssertNil(LegacyAltitudeReplayGate.reason(for: .breathHoldTarget))
    }

    /// 兩種原因的字串鍵不同（其餘語言待上架前收尾）。
    func testReasonKeysAreDistinct() {
        XCTAssertNotEqual(DiveAnalysisView.legacyAltitudeReasonKey(.target),
                          DiveAnalysisView.legacyAltitudeReasonKey(.precedingDive))
    }
}
