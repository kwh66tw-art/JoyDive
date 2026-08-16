// F5DiveKitMigrationE2ETests.swift — JD2-LogbookTests
// F5（2026-07-18）：Logbook 改用統一 DiveKit 後的端對端整合驗證。
//
// 用 00_Import_samples/ 的真實樣本走完整流程：
// DiveLogImporterFactory（Logbook 自有）→ DiveLog（Logbook 自有）→
// DiveReplayEngine.replay（吃 DiveKit 的 Buhlmann/GasMix/DiveEnvironment）。
// 目的：證明 DiveKit 遷移後匯入＋剖面分析這條路徑真的接通，不只是「編譯通過」。
//
// ⚠️ 2026-07-30：trimix 繞過已解除（家族決策
// `_JD2-family/decisions/2026-07-18_trimix減壓計算缺口.md`——DiveKit 自 v1.5.0
// 起 Buhlmann 已支援雙氣體 N₂/He 計算，v1.6.0 起 DecoCalculator ASC TIME 亦已
// 正式修復，v1.7.0 修正 N2 隔室常數）。trimix 現在與 air/nitrox 走完全相同的
// `DiveReplayEngine.replay()` 路徑，此處驗證的是「trimix 走完整路徑、不崩潰、
// 產出合理數字」，不再驗證短路行為（短路邏輯已移除）。

import XCTest
import DiveKit
@testable import JoyDive_

@MainActor
final class F5DiveKitMigrationE2ETests: XCTestCase {

    private var samplesDir: String {
        let here = (#filePath as NSString).deletingLastPathComponent
        let repoRoot = (((here as NSString).deletingLastPathComponent) as NSString).deletingLastPathComponent
        return (((repoRoot as NSString).deletingLastPathComponent) as NSString)
            .appendingPathComponent("_JD2-family/00_Import_samples/UDDF")
    }

    private var trimixSamplePath: String {
        (samplesDir as NSString).appendingPathComponent("dive_2026-06-20.uddf")
    }

    private var subsurfaceSamplePath: String {
        let here = (#filePath as NSString).deletingLastPathComponent
        let repoRoot = (((here as NSString).deletingLastPathComponent) as NSString).deletingLastPathComponent
        let familyRoot = (((repoRoot as NSString).deletingLastPathComponent) as NSString)
            .appendingPathComponent("_JD2-family/dive-log-samples/Subsurface")
        return (familyRoot as NSString).appendingPathComponent("abitofeverything.ssrf")
    }

    /// 真實 trimix 樣本（TMx 16/45，Lake Coleridge，max depth ≈39m，時長 ≈83min）：
    /// 匯入 → 解出 trimix GasMix → 重放走完整 Buhlmann 雙氣體路徑，不崩潰、
    /// 產出合理的 ceiling／NDL／組織艙（N2+He）數字。黑盒對照量級見
    /// `_JD2-family/decisions/2026-07-18_trimix減壓計算缺口.md`
    /// 「2026-08-15 追加：Buhlmann 雙氣體修復完成」段落記錄的 DiveKit 自有黑盒
    /// 交叉驗證（OVM Dive Planner）；此測試不重複跑黑盒工具，只驗證 App 層
    /// 呼叫 DiveKit 之後的資料完整性與物理合理性（不崩潰、單調性、範圍）。
    func testRealTrimixSample_RunsFullDecoReplayThroughDiveKit() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: trimixSamplePath),
                          "_JD2-family/00_Import_samples/UDDF/dive_2026-06-20.uddf 不存在")

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
            JoyDive_.DiveProfileSample(timeSeconds: $0.timeSeconds, depthMeters: $0.depthMeters)
        }

        let replay = DiveReplayEngine.replay(samples: profileSamples, gasMix: gasMix)

        XCTAssertEqual(replay.points.count, samples.count, "應保留全部剖面點供繪圖")
        XCTAssertFalse(replay.points.isEmpty)

        var sawNonZeroHe = false
        var maxCeilingSeen = 0.0
        for p in replay.points {
            // 健全性：不得為負值、不得為 NaN/Inf（靜默錯誤數字比崩潰更危險，
            // 見決策文件記載的「Debug 崩潰 vs Release 靜默顯示錯誤數字」教訓）。
            XCTAssertGreaterThanOrEqual(p.ceilingDepth, 0)
            XCTAssertFalse(p.ceilingDepth.isNaN)
            XCTAssertFalse(p.ceilingDepth.isInfinite)
            XCTAssertGreaterThanOrEqual(p.ndlSeconds, 0)
            XCTAssertEqual(p.tissuePressures.count, 16, "應有 16 組織隔室 N2 資料（ZHL-16C）")
            XCTAssertEqual(p.tissueHePressures.count, 16, "應有 16 組織隔室 He 資料（trimix 雙氣體）")
            for pHe in p.tissueHePressures {
                XCTAssertFalse(pHe.isNaN)
                XCTAssertGreaterThanOrEqual(pHe, 0)
                if pHe > 0 { sawNonZeroHe = true }
            }
            maxCeilingSeen = max(maxCeilingSeen, p.ceilingDepth)

            // 組織艙飽和度（含 He 貢獻）同樣不得為 NaN/負值。
            let loads = DiveReplayEngine.tissueLoadPercent(pN2: p.tissuePressures, pHe: p.tissueHePressures)
            XCTAssertEqual(loads.count, 16)
            for l in loads {
                XCTAssertFalse(l.isNaN)
                XCTAssertGreaterThanOrEqual(l, 0)
            }
        }

        XCTAssertTrue(sawNonZeroHe, "trimix 潛水的組織隔室應出現非零 He 分壓（否則等同繞過氦氣計算）")
        // ≈39m/≈83min 的 trimix 潛水，依決策文件黑盒對照（合成 Tx 21/35, 40m/25min
        // ceiling ≈16m 量級），本樣本更深更長，出現數公尺等級的 ceiling 屬合理量級；
        // 用寬鬆上界（100m）只排除明顯失控的計算結果，不鎖定精確值（精確值的黑盒
        // 交叉驗證屬於 DiveKit repo 職責，已於決策文件記錄，App 層不重複驗證公式本身）。
        XCTAssertLessThan(maxCeilingSeen, 100, "ceiling 深度應在物理合理範圍內")
    }

    /// DiveImportKit v0.4.2：`SubsurfaceXMLParser` 修復 `<cylinder he='...'>` 與
    /// `<event name='gaschange'>` 完全未解析的安全攸關 bug（trimix 潛水的氦氣分率
    /// 先前會被靜默丟棄、誤判為 nitrox/air，減壓分析因此偏樂觀）。此測試走 Logbook
    /// 自己的完整鏈路——`DiveLogImporterFactory` → `SubsurfaceXMLParser`（本地薄
    /// 包裝）→ `makeDiveLog`（gasMixJSON 逐位元透傳）→ `JSONDecoder` 解碼
    /// `GasMix`（`DiveLogDetailView.diveGasMix` 用的同一套解碼）→
    /// `DiveReplayEngine.replay`——證明修復後的氦氣分率真的能從真實 Subsurface XML
    /// 樣本一路傳到分析結果，不只是 DiveImportKit repo 自己的單元測試通過。
    /// 樣本 dive333（Trimix 18/28→EAN46）與驗證方法見 DiveImportKit
    /// `SubsurfaceXMLParserTests.testParseRealSample_AbitOfEverything_Dive333_Trimix1828ToEAN46`。
    func testRealSubsurfaceXMLSample_TrimixHeliumSurvivesToAnalysis() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: subsurfaceSamplePath),
                          "_JD2-family/dive-log-samples/Subsurface/abitofeverything.ssrf 不存在")

        guard let importer = DiveLogImporterFactory.selectImporter(for: subsurfaceSamplePath) else {
            XCTFail("Factory 未能為真實 Subsurface XML 樣本選出解析器"); return
        }
        XCTAssertTrue(importer is SubsurfaceXMLParser)

        let dives = try importer.parse(from: subsurfaceSamplePath)
        guard let dive333 = dives.first(where: { $0.importExtras["diveNumber"] == "333" }) else {
            XCTFail("找不到 dive number=333"); return
        }

        let gasMix: GasMix
        if let data = dive333.gasMixJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(GasMix.self, from: data) {
            gasMix = decoded
        } else {
            gasMix = .air
        }
        XCTAssertTrue(gasMix.isTrimix, "dive333 起始氣體應為 trimix（修復前的 bug 會誤判為 nitrox 18%）")
        XCTAssertEqual(gasMix.fO2, 0.18, accuracy: 0.001)
        XCTAssertEqual(gasMix.fHe, 0.28, accuracy: 0.001,
                       "fHe 應為 0.28；修復前 he 屬性完全未解析，這裡會是 0（等同氦氣被靜默丟棄）")

        // 走一段合成的深度剖面（真實樣本的 profileSamples 對這支合併雙電腦紀錄的潛水
        // 較複雜，這裡只需證明「解碼出的 GasMix 能餵進 DiveReplayEngine 並產生非零 He
        // 組織負荷」，不重複驗證真實剖面數字——那部分已由 UDDF trimix 樣本測試涵蓋）。
        let samples = [
            JoyDive_.DiveProfileSample(timeSeconds: 0, depthMeters: 0),
            JoyDive_.DiveProfileSample(timeSeconds: 60, depthMeters: 30),
            JoyDive_.DiveProfileSample(timeSeconds: 1200, depthMeters: 30),
            JoyDive_.DiveProfileSample(timeSeconds: 1260, depthMeters: 0),
        ]
        let replay = DiveReplayEngine.replay(samples: samples, gasMix: gasMix)
        XCTAssertFalse(replay.points.isEmpty)

        var sawNonZeroHe = false
        for p in replay.points {
            XCTAssertEqual(p.tissueHePressures.count, 16)
            for pHe in p.tissueHePressures where pHe > 0 { sawNonZeroHe = true }
        }
        XCTAssertTrue(sawNonZeroHe,
                      "從真實 Subsurface XML 樣本解出的 trimix GasMix 應驅動出非零 He 組織負荷——" +
                      "若為零，代表 v0.4.2 的 he 屬性修復沒有真的傳到 Logbook 分析這一端")
    }

    /// 對照組：合成的空氣潛水應正常跑完整減壓生理重放，且 He 全程為 0（air 路徑
    /// 不受 trimix 雙氣體改動影響，回歸驗證）。
    func testSyntheticAirDive_RunsFullDecoReplayThroughDiveKit() {
        let samples = [
            JoyDive_.DiveProfileSample(timeSeconds: 0, depthMeters: 0),
            JoyDive_.DiveProfileSample(timeSeconds: 60, depthMeters: 18),
            JoyDive_.DiveProfileSample(timeSeconds: 1800, depthMeters: 18),
            JoyDive_.DiveProfileSample(timeSeconds: 1860, depthMeters: 0),
        ]
        let replay = DiveReplayEngine.replay(samples: samples, gasMix: .air)

        XCTAssertFalse(replay.points.isEmpty, "DiveReplayEngine（DiveKit Buhlmann 驅動）應產出重放點")
        for p in replay.points {
            XCTAssertGreaterThanOrEqual(p.ndlSeconds, 0)
            XCTAssertEqual(p.tissuePressures.count, 16, "應有 16 組織隔室資料（ZHL-16C）")
            XCTAssertEqual(p.tissueHePressures.count, 16)
            XCTAssertTrue(p.tissueHePressures.allSatisfy { $0 == 0 }, "air 潛水 He 分壓全程應為 0")
        }
        XCTAssertGreaterThan(Buhlmann.ndlUnlimitedMarker, 0, "型別確實來自 DiveKit")
    }
}
