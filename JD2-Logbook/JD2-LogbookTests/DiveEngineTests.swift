// DiveEngineTests.swift — JD2-LogbookTests
// 稽核報告（audit_report-0717.md）風險 #1 / #4 的回歸測試。
// AI-generated (Claude)

import XCTest
@testable import JoyDive_

@MainActor
final class DiveEngineTests: XCTestCase {

    // MARK: - 稽核修復 #1：chunking 迴圈 pRate 歸零 bug

    /// 30m/30s 補算（10s ≤ deltaT < maxCompensateTotalSec=120s，會進入 chunking 迴圈，
    /// 每步 tickChunkSizeSec=10s）。比較：
    ///   (a) coarse — 透過 DiveEngine 真實生產路徑，單一 30s tick 觸發補算 chunking（命中修復）
    ///   (b) fine   — 逐秒細緻 tick，線性下潛 0→30m，視為連續真值的參考基準
    ///   (c) buggy  — 獨立重建「修復前」邏輯：每個 chunk 都傳最終深度（不插值），
    ///                證明舊版行為會明顯偏離真值，修復後不會。
    /// 用最快隔室（index 0, halfTime=4min）比較——對短時間尺度的速率分布最敏感。
    func testCompensatedChunkingMatchesFineGrainedDescent() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)

        // (a) 修復後：DiveEngine 真實路徑
        let coarseEngine = DiveEngine()
        _ = coarseEngine.tick(depth: 0, now: t0)
        _ = coarseEngine.tick(depth: 30, now: t0.addingTimeInterval(30))
        let coarsePN2 = coarseEngine.snapshot(now: t0.addingTimeInterval(30)).tissuePN2

        // (b) 參考真值：逐秒細緻 tick
        let fineEngine = DiveEngine()
        _ = fineEngine.tick(depth: 0, now: t0)
        for i in 1...30 {
            let d = 30.0 * Double(i) / 30.0
            _ = fineEngine.tick(depth: d, now: t0.addingTimeInterval(Double(i)))
        }
        let finePN2 = fineEngine.snapshot(now: t0.addingTimeInterval(30)).tissuePN2

        // (c) 修復前邏輯重建：每個 chunk 都用最終深度 30m（不插值），deltaT=10 x3
        let buggy = Buhlmann()
        buggy.updateSurface(deltaT: 1.0)
        buggy.update(depth: 30, gasMix: .air, deltaT: 10)
        buggy.update(depth: 30, gasMix: .air, deltaT: 10)
        buggy.update(depth: 30, gasMix: .air, deltaT: 10)
        let buggyPN2 = buggy.tissuePressures

        let coarseErr = abs(coarsePN2[0] - finePN2[0])
        let buggyErr  = abs(buggyPN2[0]  - finePN2[0])

        // 0.02 bar：10s 步長分段線性插值 vs 1s 步長本身就有離散化誤差（非 bug），
        // 門檻只需確認修復後的誤差維持在合理小範圍，而非要求與逐秒模擬完全相等。
        XCTAssertLessThan(coarseErr, 0.02,
            "修復後：30s 補算 tick 的最快隔室壓力應與逐秒細緻模擬接近（誤差 \(coarseErr) bar）")
        XCTAssertGreaterThan(buggyErr, coarseErr * 2,
            "修復前邏輯（每個 chunk 都用最終深度）應明顯偏離真值，證明修復確實改變了行為（buggy 誤差 \(buggyErr) bar vs coarse 誤差 \(coarseErr) bar）")
    }

    // MARK: - 稽核修復 #4：跨日水面間隔未主動重置 otuUnits

    /// 模擬「上次出水已超過 24 小時、期間 App 未開啟」的情境：
    /// 還原持久化狀態時（restore），應主動把 OTU 歸零，不必等到下一次 beginDive()。
    func testRestoreResetsStaleOTUAfter24Hours() {
        let engine = DiveEngine()

        var oxygen = OxygenTracker()
        oxygen.update(po2: 1.4, deltaT: 600, isUnderwater: true)   // 累積一段 OTU
        XCTAssertGreaterThan(oxygen.otuUnits, 0, "前置條件：應已累積 OTU")

        var surface = SurfaceStatus()
        let last = Date(timeIntervalSince1970: 1_700_000_000)
        surface.diveEnded(at: last, decoViolated: false, desaturationSeconds: 0)

        let snapshot = DiveComputerState(
            tissuePN2: Buhlmann().tissuePressures,
            environment: .seaLevel,
            oxygen: oxygen,
            surface: surface,
            savedAt: last
        )

        let now = last.addingTimeInterval(25 * 3600)   // 25 小時後才重啟 App
        engine.restore(from: snapshot, now: now)

        XCTAssertEqual(engine.oxygen.otuUnits, 0,
            "距離上次出水已超過 24 小時，restore 還原時應主動把 OTU 歸零")
    }

    /// 對照組：距離上次出水不到 24 小時，OTU 不應被重置（避免修復矯枉過正）
    func testRestoreDoesNotResetOTUWithin24Hours() {
        let engine = DiveEngine()

        var oxygen = OxygenTracker()
        oxygen.update(po2: 1.4, deltaT: 600, isUnderwater: true)
        let expectedOTU = oxygen.otuUnits
        XCTAssertGreaterThan(expectedOTU, 0, "前置條件：應已累積 OTU")

        var surface = SurfaceStatus()
        let last = Date(timeIntervalSince1970: 1_700_000_000)
        surface.diveEnded(at: last, decoViolated: false, desaturationSeconds: 0)

        let snapshot = DiveComputerState(
            tissuePN2: Buhlmann().tissuePressures,
            environment: .seaLevel,
            oxygen: oxygen,
            surface: surface,
            savedAt: last
        )

        let now = last.addingTimeInterval(2 * 3600)   // 2 小時後
        engine.restore(from: snapshot, now: now)

        XCTAssertEqual(engine.oxygen.otuUnits, expectedOTU, accuracy: 0.0001,
            "距離上次出水未滿 24 小時，OTU 不應被重置")
    }

    /// 停留水面超過 24 小時（未重啟 App，持續 tick）也應歸零，不必等下一次 beginDive()
    func testSurfaceTickResetsStaleOTUAfter24Hours() {
        let engine = DiveEngine()
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)

        // 先做一次短潛水，讓 OTU 有東西可以歸零，並設定 lastSurfacedAt
        // ⚠️ OTU 累積需要 PO₂ > 0.5 bar；10m 空氣只有 0.42 bar（(1+10/10)×0.21），
        // 完全不會累積，故用 25m（(1+25/10)×0.21 ≈ 0.735 bar）確保有實際累積。
        _ = engine.tick(depth: 0, now: t0)
        _ = engine.tick(depth: 25, now: t0.addingTimeInterval(1))       // 進入 .diving
        _ = engine.tick(depth: 25, now: t0.addingTimeInterval(300))     // 停留深度累積 OTU/CNS
        XCTAssertGreaterThan(engine.oxygen.otuUnits, 0, "前置條件：潛水應已累積 OTU")

        // 出水、等待 postDive 延遲結束、正式結算（finalizeDive 會設定 lastSurfacedAt）
        var t = 301.0
        while engine.state != .surface && t < 3000 {
            t += 1
            _ = engine.tick(depth: 0, now: t0.addingTimeInterval(t))
        }
        XCTAssertEqual(engine.state, .surface, "應已回到水面狀態")
        let otuBeforeGap = engine.oxygen.otuUnits
        XCTAssertGreaterThan(otuBeforeGap, 0, "出水結算後 OTU 應仍保留（單日累積概念，非潛水結束就歸零）")

        // 之後在水面停留超過 24 小時，不再下潛
        _ = engine.tick(depth: 0, now: t0.addingTimeInterval(t + 25 * 3600))

        XCTAssertEqual(engine.oxygen.otuUnits, 0,
            "在水面停留超過 24 小時未再下潛，OTU 應主動歸零，不必等到下一次 beginDive()")
    }
}
