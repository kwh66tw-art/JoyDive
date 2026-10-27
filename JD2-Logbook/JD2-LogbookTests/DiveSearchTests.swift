// DiveSearchTests.swift — JD2-LogbookTests
// v1.4 A2（PM 2026-10-26 裁示 D3）：列表搜尋＝潛點（location）＋備註＋潛伴＋標籤。
// 潛伴／標籤解析 importExtrasJSON、只比對 "buddy"／"tags" 的值，不做原始 JSON 字串搜尋。

import XCTest
import Foundation
@testable import JoyDive_

@MainActor
final class DiveSearchTests: XCTestCase {

    private func makeDive(location: String = "Green Island", notes: String = "",
                          extras: [String: String] = [:]) -> DiveLog {
        let dive = DiveLog(dateTime: Date(), location: location, maxDepth: 18, diveTimeSeconds: 2400)
        dive.notes = notes
        let data = try! JSONEncoder().encode(extras)
        dive.importExtrasJSON = String(data: data, encoding: .utf8)!
        return dive
    }

    func testEmptyOrWhitespaceQueryMatchesAll() {
        XCTAssertTrue(makeDive().matchesSearch(""))
        XCTAssertTrue(makeDive().matchesSearch("   "))
    }

    /// 原有行為不變：地點與備註、不分大小寫。
    func testLocationAndNotesStillMatch() {
        XCTAssertTrue(makeDive(location: "Green Island").matchesSearch("green"))
        XCTAssertTrue(makeDive(notes: "Saw a turtle").matchesSearch("TURTLE"))
        XCTAssertFalse(makeDive(location: "Green Island", notes: "calm").matchesSearch("manta"))
    }

    func testBuddyValueMatches() {
        let dive = makeDive(extras: ["buddy": "Amy Chen", "deviceSerial": "X1"])
        XCTAssertTrue(dive.matchesSearch("amy"))
        XCTAssertTrue(dive.matchesSearch("Chen"))
    }

    func testTagsValueMatches() {
        let dive = makeDive(extras: ["tags": "wreck, night"])
        XCTAssertTrue(dive.matchesSearch("night"))
        XCTAssertTrue(dive.matchesSearch("Wreck"))
    }

    /// 不得命中鍵名：搜「buddy」「tags」不應因為鍵存在就全中。
    func testKeyNamesDoNotMatch() {
        let dive = makeDive(extras: ["buddy": "Amy", "tags": "reef"])
        XCTAssertFalse(dive.matchesSearch("buddy"))
        XCTAssertFalse(dive.matchesSearch("tags"))
    }

    /// 只比對潛伴／標籤：其他 extras（序號、內部標記）不參與搜尋。
    func testOtherExtrasDoNotMatch() {
        let dive = makeDive(extras: ["deviceSerial": "ABC123", "gasMixConfidence": "unknown", "buddy": "Amy"])
        XCTAssertFalse(dive.matchesSearch("ABC123"))
        XCTAssertFalse(dive.matchesSearch("unknown"))
    }

    /// 損毀或空的 importExtrasJSON ⇒ 只是潛伴／標籤不命中，地點照常比對、不崩潰。
    func testMalformedExtrasFallsBackToLocationAndNotes() {
        let dive = makeDive(location: "Kenting")
        dive.importExtrasJSON = "{not json"
        XCTAssertTrue(dive.matchesSearch("kent"))
        XCTAssertFalse(dive.matchesSearch("amy"))
    }

    /// 端到端：真實 Subsurface XML 樣本經 DiveImportKit 匯入後，可用潛伴與標籤搜到。
    /// 驗證本檔的鍵名與 Kit 實際寫入的鍵一致——Kit 改了鍵名時這支會紅。
    /// 樣本 `Subsurface/test42.xml` 含 `<buddy>Michael</buddy>` 與 `tags='ccr_dive'`（2026-10-26 grep）。
    func testImportedSubsurfaceSampleIsSearchableByBuddyAndTags() throws {
        try FixtureRoot.requireRoot()
        let dives = try SubsurfaceXMLParser().parse(from: FixtureRoot.path("Subsurface/test42.xml"))
        XCTAssertFalse(dives.isEmpty, "樣本應解析出潛水")
        XCTAssertTrue(dives.contains { $0.matchesSearch("michael") }, "潛伴應可搜尋")
        XCTAssertTrue(dives.contains { $0.matchesSearch("ccr_dive") }, "標籤應可搜尋")
        XCTAssertFalse(dives.contains { $0.matchesSearch("buddy") }, "不得命中鍵名")
    }

    // MARK: - v1.4 稽核 T22–T25（`docs/V1_4_AUDIT_TEST_PLAN.md`）

    /// T22：真實 Subsurface CSV 樣本（`CSV/test41.csv`，4 筆、潛伴 "Dirk, Linus"／"Linus"／"Tomaz"／"Don"，2026-10-27 實測）。
    /// 多位潛伴寫在同一個值裡 ⇒ 任一名字都搜得到。
    func testImportedSubsurfaceCSVIsSearchableByEachBuddy() throws {
        try FixtureRoot.requireRoot()
        let dives = try SubsurfaceCSVParser().parse(from: FixtureRoot.path("CSV/test41.csv"))
        XCTAssertEqual(dives.count, 4)
        for name in ["dirk", "Linus", "TOMAZ", "don"] {
            XCTAssertTrue(dives.contains { $0.matchesSearch(name) }, "潛伴 \(name) 應可搜尋")
        }
        XCTAssertEqual(dives.filter { $0.matchesSearch("linus") }.count, 2, "Linus 出現在兩筆（含多位潛伴那筆）")
    }

    /// T22 多位潛伴（UDDF 由 DiveImportKit 以空白串接；CSV 原樣逗號）：值裡任一名字、名字片段都命中。
    func testMultipleBuddiesInOneValueEachMatch() {
        let spaced = makeDive(extras: ["buddy": "Amy Ben"])
        XCTAssertTrue(spaced.matchesSearch("amy"))
        XCTAssertTrue(spaced.matchesSearch("ben"))
        let comma = makeDive(extras: ["buddy": "Dirk, Linus"])
        XCTAssertTrue(comma.matchesSearch("linus"))
        XCTAssertTrue(comma.matchesSearch("Dirk, L"), "子字串比對，不切詞")
    }

    /// ⚠️ T22 現況紀錄（2026-10-27，已回報總指揮；DiveImportKit 範圍，本 repo 不修）：
    /// 真實 UDDF 樣本 `UDDF/test42.uddf` 的潛伴是標準寫法——`<diver><buddy id=…><personal><firstname>Michael`
    /// 定義在檔頭、潛水內以 `<link ref="testbuddyid1"/>` 引用；DiveImportKit v0.8.1 只讀
    /// `informationbeforedive` 內直接寫的 `firstname`（`UDDFParser.swift:483-489`），不解析 link ⇒ 沒寫入 `buddy`。
    /// Kit 補上後這支會紅，屆時改成「可搜到 Michael」。
    func testUDDFLinkedBuddyIsNotImportedYet() throws {
        try FixtureRoot.requireRoot()
        let dives = try UDDFParser().parse(from: FixtureRoot.path("UDDF/test42.uddf"))
        let dive = try XCTUnwrap(dives.first)
        XCTAssertNil(dive.importExtras["buddy"], "現況：link 引用的潛伴未匯入")
        XCTAssertFalse(dive.matchesSearch("michael"))
        XCTAssertTrue(dive.matchesSearch("coleridge"), "地點照常可搜")
    }

    /// T23：輸入邊界——前後空白去掉、大小寫不分、中文、emoji、特殊字元皆為字面子字串（不是 regex／萬用字元）。
    func testQueryInputBoundaries() {
        let dive = makeDive(location: "綠島 Green Island 🐢", notes: "100% vis, a*b a.b a\\b")
        XCTAssertTrue(dive.matchesSearch("  green  "), "前後空白去掉")
        XCTAssertTrue(dive.matchesSearch("\ngreen\t"), "換行／tab 也去掉")
        XCTAssertTrue(dive.matchesSearch("ISLAND"))
        XCTAssertTrue(dive.matchesSearch("綠"), "單一中文字")
        XCTAssertTrue(dive.matchesSearch("g"), "單字元")
        XCTAssertTrue(dive.matchesSearch("🐢"))
        XCTAssertTrue(dive.matchesSearch("%"))
        XCTAssertTrue(dive.matchesSearch("a*b"))
        XCTAssertTrue(dive.matchesSearch("a\\b"))
        XCTAssertFalse(dive.matchesSearch("a.c"), "「.」不是萬用字元")
        XCTAssertFalse(makeDive(location: "abc").matchesSearch("*"), "「*」不是萬用字元")
        XCTAssertFalse(dive.matchesSearch("gr een"), "中間空白保留、不拆詞")
    }

    /// T24 現況紀錄（F12）：只不分大小寫——**分**重音、**分**全形半形、**分**半形片假名（`localizedCaseInsensitiveContains`）。
    /// 與 A2 前的地點／備註搜尋同一個比對函式 ⇒ 行為一致；要改需 PM 裁示。
    func testAccentAndWidthSensitivityCurrentBehavior() {
        XCTAssertFalse(makeDive(location: "Café Reef").matchesSearch("cafe"))
        XCTAssertFalse(makeDive(location: "Cafe Reef").matchesSearch("café"))
        XCTAssertFalse(makeDive(location: "ＡＭＹ Reef").matchesSearch("amy"))
        XCTAssertFalse(makeDive(location: "Amy Reef").matchesSearch("ＡＭＹ"))
        XCTAssertFalse(makeDive(location: "ﾀﾞｲﾋﾞﾝｸﾞ").matchesSearch("ダイビング"))
        XCTAssertTrue(makeDive(location: "Café Reef").matchesSearch("CAFÉ"), "大小寫仍不分")
        // 潛伴與地點走同一個比對
        XCTAssertFalse(makeDive(extras: ["buddy": "José"]).matchesSearch("jose"))
    }

    /// T25（F10）：`importExtrasJSON` 空字串、或含非字串值 ⇒ 不崩潰、地點照常命中。
    /// ⚠️ 現況：只要有一個值不是字串，整包解碼失敗 ⇒ 潛伴／標籤**全部**搜不到（`importExtras` 以 `[String: String]` 解碼）。
    /// Kit 匯入只寫字串（`ImportExtra.value: String`），此情況只會來自手改或外部產生的備份。
    func testExtrasEmptyOrNonStringValues() {
        let empty = makeDive(location: "Kenting")
        empty.importExtrasJSON = ""
        XCTAssertTrue(empty.matchesSearch("kent"))

        let mixed = makeDive(location: "Kenting")
        mixed.importExtrasJSON = #"{"buddy":"Amy","diveNumber":5}"#
        XCTAssertTrue(mixed.matchesSearch("kent"))
        XCTAssertTrue(mixed.importExtras.isEmpty, "現況：非字串值 ⇒ 整包解碼失敗")
        XCTAssertFalse(mixed.matchesSearch("amy"), "現況：同包的潛伴也搜不到")

        let nullValue = makeDive(location: "Kenting")
        nullValue.importExtrasJSON = #"{"buddy":null}"#
        XCTAssertTrue(nullValue.matchesSearch("kent"))
        XCTAssertFalse(nullValue.matchesSearch("null"))
    }
}

