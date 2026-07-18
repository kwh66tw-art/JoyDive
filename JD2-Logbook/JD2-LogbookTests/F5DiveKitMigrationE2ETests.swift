// F5DiveKitMigrationE2ETests.swift — JD2-LogbookTests
// F5（2026-07-18）：Logbook 改用統一 DiveKit 後的端對端整合驗證。
//
// 用 00_Import_samples/ 的真實樣本走完整流程：
// DiveLogImporterFactory（Logbook 自有）→ DiveLog（Logbook 自有）→
// DiveReplayEngine.replay（吃 DiveKit 的 Buhlmann/GasMix/DiveEnvironment）。
// 目的：證明 DiveKit 遷移後匯入＋剖面分析這條路徑真的接通，不只是「編譯通過」。
//
// ⚠️ trimix 已知限制（2026-07-18 發現，PM 決策：F5 繞過，DiveKit 修復另排）：
// DiveKit 的 Buhlmann 只追蹤氮氣（Compartment 無 pHe 欄位），trimix 的
// ndlSeconds() 會 assertionFailure。DiveReplayEngine.replay() 已加 trimix 短路
// （decoDataUnavailable=true，只給深度/時間/溫度），此處驗證短路行為正確。

import XCTest
import DiveKit
@testable import JoyDive_

@MainActor
final class F5DiveKitMigrationE2ETests: XCTestCase {

    private var samplesDir: String {
        let here = (#filePath as NSString).deletingLastPathComponent
        let repoRoot = (((here as NSString).deletingLastPathComponent) as NSString).deletingLastPathComponent
        return (((repoRoot as NSString).deletingLastPathComponent) as NSString)
            .appendingPathComponent("00_Import_samples/UDDF")
    }

    private var trimixSamplePath: String {
        (samplesDir as NSString).appendingPathComponent("dive_2026-06-20.uddf")
    }

    /// 真實 trimix 樣本（test42.uddf 改期版）：匯入 → 解出 trimix GasMix →
    /// 重放走 trimix 短路路徑，不觸發 DiveKit 的 assertionFailure。
    func testRealTrimixSample_ImportsAndSkipsUnsupportedDecoCalc() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: trimixSamplePath),
                          "00_Import_samples/UDDF/dive_2026-06-20.uddf 不存在")

        guard let importer = DiveLogImporterFactory.selectImporter(for: trimixSamplePath) else {
            XCTFail("Factory 未能為真實 UDDF 樣本選出解析器"); return
        }
        XCTAssertTrue(importer is UDDFParser)

        let dives = try importer.parse(from: trimixSamplePath)
        let dive = try XCTUnwrap(dives.first)
        XCTAssertGreaterThan(dive.maxDepth, 0)

        let gasMix: GasMix
        if let data = dive.gasMixJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(GasMix.self, from: data) {
            gasMix = decoded
        } else {
            gasMix = .air
        }
        XCTAssertTrue(gasMix.isTrimix, "此真實樣本應為 trimix（TMx 16/45），若非 trimix 表示樣本已變動")

        let samples = dive.profileSamples
        try XCTSkipIf(samples.count < 2, "剖面樣本不足 2 筆")
        let profileSamples = samples.map {
            DiveProfileSample(timeSeconds: $0.timeSeconds, depthMeters: $0.depthMeters)
        }

        let replay = DiveReplayEngine.replay(samples: profileSamples, gasMix: gasMix)

        XCTAssertTrue(replay.decoDataUnavailable, "trimix 應標記 decoDataUnavailable")
        XCTAssertEqual(replay.points.count, samples.count, "trimix 短路仍應保留全部剖面點供繪圖")
        for p in replay.points {
            XCTAssertEqual(p.ceilingDepth, 0)
            XCTAssertEqual(p.ndlSeconds, 0)
            XCTAssertTrue(p.tissuePressures.isEmpty)
        }
    }

    /// 對照組：合成的空氣潛水應正常跑完整減壓生理重放（證明 DiveKit 整合本身沒問題，
    /// 缺口僅限 trimix）。
    func testSyntheticAirDive_RunsFullDecoReplayThroughDiveKit() {
        let samples = [
            DiveProfileSample(timeSeconds: 0, depthMeters: 0),
            DiveProfileSample(timeSeconds: 60, depthMeters: 18),
            DiveProfileSample(timeSeconds: 1800, depthMeters: 18),
            DiveProfileSample(timeSeconds: 1860, depthMeters: 0),
        ]
        let replay = DiveReplayEngine.replay(samples: samples, gasMix: .air)

        XCTAssertFalse(replay.decoDataUnavailable)
        XCTAssertFalse(replay.points.isEmpty, "DiveReplayEngine（DiveKit Buhlmann 驅動）應產出重放點")
        for p in replay.points {
            XCTAssertGreaterThanOrEqual(p.ndlSeconds, 0)
            XCTAssertEqual(p.tissuePressures.count, 16, "應有 16 組織隔室資料（ZHL-16C）")
        }
        XCTAssertGreaterThan(Buhlmann.ndlUnlimitedMarker, 0, "型別確實來自 DiveKit")
    }
}
