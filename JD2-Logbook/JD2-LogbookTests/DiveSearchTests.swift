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
}
