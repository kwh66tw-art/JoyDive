// EnvironmentEdgeCaseTests.swift — JD2-LogbookTests
// v1.4 稽核（`docs/V1_4_AUDIT_TEST_PLAN.md`）T9、T20。
//
// T9：環境值 × 水面氣壓組合表——水域只認 seawater／freshwater；徽章只看「< 0.95」；閘門只認 altitude＋恰為 1.0。
//     0／負數／NaN **只記錄現況**（D-C 待 PM 裁示）：斷言鎖的是 2026-10-27 的行為，裁示後改行為時相應斷言會紅——那是預期的。
// T20：原因句接在通用句前，18 種 App 語言（含回退英文者）都只會是「全形句末直接接」或「補一個半形空格」。

import XCTest
import Foundation
import DiveKit
@testable import JoyDive_

@MainActor
final class EnvironmentEdgeCaseTests: XCTestCase {

    /// 刻意不釋放（`AppLanguageManager` 在測試中釋放會 SIGABRT，見 `EnvironmentUnrecordedTests`）。
    private static let languageManager = AppLanguageManager(defaults: UserDefaults(suiteName: "EnvironmentEdgeCaseTests")!)

    private static let environments: [String?] = [nil, "seawater", "freshwater", "altitude", "brackish", ""]
    private static let pressures: [Double] = [1.0, 0.95, 0.9499, 0.8, 0, -1, .nan]

    private func makeDive(environment: String?, surfacePressure: Double, withProfile: Bool = false) -> DiveLog {
        let dive = DiveLog(dateTime: Date(timeIntervalSince1970: 1_700_000_000), location: "T9",
                           maxDepth: 20, diveTimeSeconds: 2400)
        dive.environmentType = environment
        dive.surfacePressureBar = surfacePressure
        if withProfile {
            let samples = [
                JoyDive_.DiveProfileSample(timeSeconds: 0, depthMeters: 0),
                JoyDive_.DiveProfileSample(timeSeconds: 120, depthMeters: 20),
                JoyDive_.DiveProfileSample(timeSeconds: 2280, depthMeters: 20),
                JoyDive_.DiveProfileSample(timeSeconds: 2400, depthMeters: 0),
            ]
            dive.profileSamplesJSON = String(data: try! JSONEncoder().encode(samples), encoding: .utf8)!
        }
        return dive
    }

    // MARK: - T9 組合表

    /// 42 格逐一檢查水域、徽章、閘門三個推導。
    func testEnvironmentPressureMatrix() {
        let lm = Self.languageManager
        let none = lm.localized("Not Recorded"), alt = lm.localized("Altitude")
        for env in Self.environments {
            for pressure in Self.pressures {
                let dive = makeDive(environment: env, surfacePressure: pressure)
                let label = "env=\(env ?? "nil") p=\(pressure)"

                let expectedWater: DiveLog.WaterType? = env.flatMap(DiveLog.WaterType.init(rawValue:))
                XCTAssertEqual(dive.waterType, expectedWater, label)
                if env == nil || env == "altitude" || env == "brackish" || env == "" {
                    XCTAssertNil(dive.waterType, "\(label)：只有 seawater／freshwater 有名稱（空字串、未知值都不得落到海水）")
                }

                // 徽章：嚴格「< 0.95」；NaN 比較恆 false ⇒ 不判高海拔。
                let expectedBadge = pressure < 0.95
                XCTAssertEqual(dive.isHighAltitude, expectedBadge, label)
                if pressure.isNaN { XCTAssertFalse(dive.isHighAltitude, "\(label)：NaN 不判高海拔") }

                // 閘門：只有 altitude 且恰為 1.0。
                XCTAssertEqual(dive.isReplayBlockedByLegacyAltitude, env == "altitude" && pressure == 1.0, label)
                XCTAssertEqual(dive.replayInput.environmentUntrusted, dive.isReplayBlockedByLegacyAltitude, label)

                // 顯示字串只由上面兩個推導組成。
                let water = dive.environmentDisplayText(lm).components(separatedBy: " · ").first!
                if expectedWater == nil { XCTAssertEqual(water, none, label) }
                XCTAssertEqual(dive.environmentDisplayText(lm).hasSuffix(" · " + alt), expectedBadge, label)
            }
        }
    }

    /// ⚠️ 現況紀錄（D-C 待 PM；2026-10-27 已回報總指揮）：水面氣壓 0／負數／NaN 時，
    /// App 層把 0 與負數顯示成「高海拔」，而 **DiveKit v9.7.0 照常重放、不回異常**——NaN 時組織負荷為 NaN。
    /// 本 App 不另寫判定（D4：判定在 Kit）；Kit 或 PM 改行為後，這支會紅，屆時照新裁示更新。
    func testImplausibleSurfacePressureCurrentBehavior() {
        XCTAssertTrue(makeDive(environment: nil, surfacePressure: 0).isHighAltitude, "現況：0 bar 顯示高海拔")
        XCTAssertTrue(makeDive(environment: nil, surfacePressure: -1).isHighAltitude, "現況：負數顯示高海拔")
        XCTAssertFalse(makeDive(environment: nil, surfacePressure: .nan).isHighAltitude)

        for pressure in [0.0, -1.0, .nan] {
            let dive = makeDive(environment: "seawater", surfacePressure: pressure, withProfile: true)
            let outcome = DiveReplayEngine.replayChain(target: dive.replayInput, precedingDives: [])
            guard case .replayed(let result) = outcome, let last = result.points.last else {
                return XCTFail("現況：Kit 照常重放（p=\(pressure)）；若已改為異常，請依 D-C 裁示更新本測試。實際：\(outcome)")
            }
            let loads = DiveReplayEngine.tissueLoadPercent(pN2: last.tissuePN2, pHe: last.tissuePHe,
                                                          environment: dive.replayEnvironment)
            if pressure.isNaN {
                XCTAssertTrue(loads.contains { $0.isNaN }, "現況：NaN 氣壓 ⇒ 組織負荷 NaN")
            }
        }
        XCTAssertFalse(DiveEnvironment.plausibleSurfacePressureRangeBar.contains(0),
                       "Kit 已有合理範圍常數（0.60...1.10），但重放前置判斷未使用")
    }

    /// 匯入路徑：Subsurface XML 的 `<surface pressure>` 不經 DiveImportKit 的合理範圍檢查
    /// （`SurfacePressureParsing`；其他解析器有用），0 bar 原樣進資料庫（2026-10-27 讀碼：
    /// `SubsurfaceXMLParser.swift:222` `parseBar` 只做 `Double(…)`）。⚠️ 現況紀錄，已回報總指揮。
    func testSubsurfaceXMLZeroSurfacePressureIsStoredVerbatim() throws {
        let xml = """
        <divelog program='subsurface' version='3'>
        <dives>
        <dive number='1' date='2023-11-14' time='10:00:00' duration='40:00 min'>
          <surface pressure='0.0 bar' />
          <divecomputer model='Test'>
          <depth max='20.0 m' mean='15.0 m' />
          <sample time='0:00 min' depth='0.0 m' />
          <sample time='2:00 min' depth='20.0 m' />
          <sample time='38:00 min' depth='20.0 m' />
          <sample time='40:00 min' depth='0.0 m' />
          </divecomputer>
        </dive>
        </dives>
        </divelog>
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("T9-\(UUID().uuidString).ssrf")
        try xml.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let dives = try SubsurfaceXMLParser().parse(from: url.path)
        let dive = try XCTUnwrap(dives.first, "合成樣本應解析出一筆")
        XCTAssertEqual(dive.surfacePressureBar, 0, "現況：0 bar 原樣寫入；Kit 改為套用合理範圍後應回到預設 1.0")
    }

    // MARK: - T20 原因句接法（18 語）

    /// 每種 App 語言：原因句（兩種）接在通用句前，只會是「全形句末直接接」或「原句＋一個半形空格」，
    /// 不會出現「。 」或兩句黏在一起。尚未翻譯的語言回退英文 ⇒ 補空格。
    func testReasonSentenceJoiningAcrossAllAppLanguages() {
        let lm = Self.languageManager
        let original = lm.appLanguage
        defer { lm.appLanguage = original }
        let keys = [DiveAnalysisView.legacyAltitudeReasonKey(.target),
                    DiveAnalysisView.legacyAltitudeReasonKey(.precedingDive)]
        let generic = "Interactive tissue loading is not available for this dive — see detail"

        XCTAssertEqual(AppLanguageManager.supportedLanguages.count, 18)
        for (code, _) in AppLanguageManager.supportedLanguages {
            lm.appLanguage = code
            for key in keys {
                let sentence = lm.localized(key)
                XCTAssertFalse(sentence.isEmpty, "\(code)")
                let joined = DiveAnalysisView.sentencePrefix(sentence) + lm.localized(generic)
                let prefix = DiveAnalysisView.sentencePrefix(sentence)
                if "。！？".contains(sentence.last!) {
                    XCTAssertEqual(prefix, sentence, "\(code)：全形句末直接相接")
                } else {
                    XCTAssertEqual(prefix, sentence + " ", "\(code)：其他語言補一個半形空格")
                }
                XCTAssertFalse(joined.contains("。 ") || joined.contains("！ ") || joined.contains("？ "), "\(code)")
                XCTAssertFalse(joined.contains("  "), "\(code)：不得有兩個空格")
            }
        }

        // 中日文有譯文、句末全形；尚未翻譯者回退英文原句（14 語待上架前收尾，PM 10/26）。
        lm.appLanguage = "zh-Hant"
        XCTAssertEqual(lm.localized(keys[0]).last, "。")
        lm.appLanguage = "ja"
        XCTAssertEqual(lm.localized(keys[0]).last, "。")
        lm.appLanguage = "ko"
        XCTAssertEqual(lm.localized(keys[0]), keys[0], "現況：韓文尚未翻譯 ⇒ 回退英文")
    }
}
