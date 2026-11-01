// DiveListFilterTests.swift — JD2-LogbookTests
// v1.4 A3 列表篩選：選項判定、組合規則、只列存在的值（`docs/decisions/D-2026-11-01-A3-列表篩選規格.md` §二、§三）。

import XCTest
import Foundation
import SwiftData
import DiveKit
@testable import JoyDive_

@MainActor
final class DiveListFilterTests: XCTestCase {

    private func makeDive(gasJSON: String = "\"air\"", mode: DiveLogMode = .scuba,
                          extras: [String: String] = [:]) -> DiveLog {
        let dive = DiveLog(dateTime: Date(timeIntervalSince1970: 1_700_000_000), location: "A3",
                           maxDepth: 18, diveTimeSeconds: 2400)
        dive.gasMixJSON = gasJSON
        dive.diveModeValue = mode
        if !extras.isEmpty {
            dive.importExtrasJSON = String(data: try! JSONEncoder().encode(extras), encoding: .utf8)!
        }
        return dive
    }

    // MARK: 氣體分類（與列表標籤同源）

    func testGasCategoryFollowsDisplayedGas() {
        XCTAssertEqual(makeDive().gasCategory, .air)
        XCTAssertEqual(makeDive(gasJSON: "{\"nitrox\":{\"fO2\":0.32}}").gasCategory, .nitrox)
        XCTAssertEqual(makeDive(gasJSON: "{\"trimix\":{\"fO2\":0.18,\"fHe\":0.45}}").gasCategory, .trimix)
        XCTAssertEqual(makeDive(gasJSON: "garbage").gasCategory, .unknown, "解不出來 ⇒ 未知氣體")
        XCTAssertEqual(makeDive(extras: ["gasMixConfidence": "unknown"]).gasCategory, .unknown, "匯入判定不可信 ⇒ 未知氣體")
        XCTAssertEqual(makeDive(extras: ["gasMixConfidence": "unknown"]).displayGasMix, nil, "與列表標籤同源")
        XCTAssertNil(makeDive(mode: .free).gasCategory, "閉氣潛水不屬於任何氣體選項")
        XCTAssertNil(makeDive(mode: .snorkel).gasCategory)
    }

    func testUnknownDiveModeValueCountsAsScuba() {
        let dive = makeDive()
        dive.diveMode = "gauge"
        XCTAssertEqual(dive.diveModeValue, .scuba)
        XCTAssertTrue(DiveListFilter(modes: [.scuba]).matches(dive, tissueSupported: nil))
    }

    // MARK: 組合規則

    func testSameCategoryIsOrAcrossCategoriesIsAnd() {
        let air = makeDive(), nitrox = makeDive(gasJSON: "{\"nitrox\":{\"fO2\":0.32}}"), free = makeDive(mode: .free)
        let gasOr = DiveListFilter(gases: [.air, .nitrox])
        XCTAssertTrue(gasOr.matches(air, tissueSupported: nil))
        XCTAssertTrue(gasOr.matches(nitrox, tissueSupported: nil))
        XCTAssertFalse(gasOr.matches(free, tissueSupported: nil))

        let gasAndMode = DiveListFilter(gases: [.air], modes: [.free])
        XCTAssertFalse(gasAndMode.matches(air, tissueSupported: nil), "跨類 AND：空氣但不是自由潛水")
        XCTAssertFalse(gasAndMode.matches(free, tissueSupported: nil), "跨類 AND：自由潛水沒有氣體")

        XCTAssertTrue(DiveListFilter().matches(free, tissueSupported: nil), "沒有條件 ⇒ 全部")
        XCTAssertFalse(DiveListFilter().isActive)
    }

    /// 組織負荷：還沒算出來的紀錄不顯示（只顯示算好的正確結果）；兩項都勾 ⇒ 算好的都顯示。
    func testTissueConditionHidesUnjudgedDives() {
        let dive = makeDive()
        let available = DiveListFilter(tissue: [.available])
        XCTAssertFalse(available.matches(dive, tissueSupported: nil))
        XCTAssertTrue(available.matches(dive, tissueSupported: true))
        XCTAssertFalse(available.matches(dive, tissueSupported: false))
        XCTAssertTrue(DiveListFilter(tissue: [.unavailable]).matches(dive, tissueSupported: false))
        let both = DiveListFilter(tissue: [.available, .unavailable])
        XCTAssertTrue(both.matches(dive, tissueSupported: false))
        XCTAssertFalse(both.matches(dive, tissueSupported: nil))
        XCTAssertTrue(available.needsTissueJudgement)
        XCTAssertFalse(DiveListFilter(gases: [.air]).needsTissueJudgement)
    }

    // MARK: 只列存在的值

    func testOnlyPresentOptionsAreListedInFixedOrder() {
        let dives = [makeDive(gasJSON: "{\"nitrox\":{\"fO2\":0.32}}"), makeDive(), makeDive(mode: .snorkel)]
        XCTAssertEqual(DiveListFilter.availableGases(in: dives), [.air, .nitrox], "沒有 trimix／未知氣體 ⇒ 不列")
        XCTAssertEqual(DiveListFilter.availableModes(in: dives), [.scuba, .snorkel])
        XCTAssertEqual(DiveListFilter.availableGases(in: []), [])
    }

    func testSelectedOptionThatNoLongerExistsIsPruned() {
        let filter = DiveListFilter(gases: [.trimix, .air], modes: [.free], tissue: [.available])
        let pruned = filter.pruned(gases: [.air], modes: [.scuba])
        XCTAssertEqual(pruned.gases, [.air])
        XCTAssertEqual(pruned.modes, [])
        XCTAssertEqual(pruned.tissue, [.available], "組織負荷兩項恆列，不剪")
    }

    // MARK: 文案（英／繁中／日草稿；取代逐語截圖）

    /// 測試中不得釋放 `AppLanguageManager`（SIGABRT）⇒ static 共用實例（同 `EnvironmentEdgeCaseTests`）。
    private static let languageManager = AppLanguageManager(defaults: UserDefaults(suiteName: "DiveListFilterTests")!)

    func testNewFilterStringsAreLocalizedInDraftLanguages() {
        let lm = Self.languageManager
        let original = lm.appLanguage
        defer { lm.appLanguage = original }
        let expected: [String: [String: String]] = [
            "en": ["Filter": "Filter", "With Tissue Loading": "With Tissue Loading", "No Tissue Loading": "No Tissue Loading",
                   "No matching dives": "No matching dives", "Clear Filters": "Clear Filters", "Calculating…": "Calculating…",
                   "Trimix": "Trimix"],
            "zh-Hant": ["Filter": "篩選", "With Tissue Loading": "有組織負荷", "No Tissue Loading": "無組織負荷",
                        "No matching dives": "沒有符合的潛水", "Clear Filters": "清除篩選", "Calculating…": "計算中…",
                        "Trimix": "Trimix"],
            "ja": ["Filter": "フィルタ", "With Tissue Loading": "組織負荷あり", "No Tissue Loading": "組織負荷なし",
                   "No matching dives": "該当するダイビングはありません", "Clear Filters": "フィルタをクリア",
                   "Calculating…": "計算中…", "Trimix": "トライミックス"],
        ]
        for (code, strings) in expected {
            lm.appLanguage = code
            for (key, value) in strings {
                XCTAssertEqual(lm.localized(key), value, "\(code): \(key)")
            }
        }
        // Trimix 取 F-10 術語表譯文：其餘語言也要有（不能回退成鍵名以外的空字串）
        lm.appLanguage = "de"
        XCTAssertEqual(lm.localized("Trimix"), "Trimix")
    }

    // MARK: 文案鍵（規格 §四；App-u 用同一批鍵）

    func testLabelKeysMatchSpec() {
        XCTAssertEqual(DiveGasCategory.allCases.map(\.labelKey), ["Air", "Nitrox", "Trimix", "Unknown Gas"])
        XCTAssertEqual(DiveLogMode.allCases.map(\.labelKey), ["Scuba", "Freedive", "Snorkel"])
        XCTAssertEqual(TissueLoadingCategory.allCases.map(\.labelKey), ["With Tissue Loading", "No Tissue Loading"])
    }
}
