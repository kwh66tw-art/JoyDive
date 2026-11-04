// DiveClusterLabelTests.swift — JD2-LogbookTests
// v1.4 B1-A（PM 2026-11-04）：聚合點名稱與選取標示的規則 ①–④（`DiveClusterLabeling`）。

import XCTest
@testable import JoyDive_

final class DiveClusterLabelTests: XCTestCase {

    private let unknown = "Unknown Location"
    private let multiple = "Multiple Dive Sites"

    private func label(_ locations: [String], selected: Int? = nil) -> DiveClusterLabel {
        DiveClusterLabeling.label(memberLocations: locations, selectedIndex: selected,
                                  unknownLocationText: unknown, multipleSitesText: multiple)
    }

    // ① 成員含選取 ⇒ 用它的地點並標示選取，即使其他成員地點不同
    func testSelectedMemberNamesTheClusterAndMarksSelection() {
        let result = label(["Crystal Rock", "Castle Rock", "DA 遠前導舊標籤", "Crystal Rock"], selected: 2)
        XCTAssertEqual(result, DiveClusterLabel(title: "DA 遠前導舊標籤", containsSelection: true))
    }

    func testSelectedMemberWithEmptyLocationUsesUnknownText() {
        let result = label(["Crystal Rock", ""], selected: 1)
        XCTAssertEqual(result, DiveClusterLabel(title: unknown, containsSelection: true))
    }

    /// 選取不在這個聚合點（index 超出範圍時視同不在）⇒ 不標示選取。
    func testSelectionOutsideClusterIsIgnored() {
        XCTAssertFalse(label(["Banana Reef", "Banana Reef"], selected: 5).containsSelection)
        XCTAssertFalse(label(["Banana Reef", "Banana Reef"]).containsSelection)
    }

    // ② 地點全部相同 ⇒ 用該名稱
    func testSameLocationUsesThatName() {
        XCTAssertEqual(label(["Banana Reef, Maldives", "Banana Reef, Maldives", "Banana Reef, Maldives"]),
                       DiveClusterLabel(title: "Banana Reef, Maldives", containsSelection: false))
    }

    // ③ 不同地點 ⇒ 中性說法，不得借用任一筆的名稱
    func testMixedLocationsUseNeutralText() {
        let result = label(["Crystal Rock, Komodo", "Castle Rock, Komodo", "DA 遠前導舊標籤"])
        XCTAssertEqual(result.title, multiple)
        XCTAssertFalse(result.containsSelection)
    }

    /// 地點只差在一筆是空白，也算不同（空白＝未知地點，不是同一個地點）。
    func testEmptyLocationMixedWithNamedLocationIsMixed() {
        XCTAssertEqual(label(["Batu Bolong, Komodo", ""]).title, multiple)
    }

    // ④ 全部空白 ⇒ 未知地點（② 的特例）
    func testAllEmptyLocationsUseUnknownText() {
        XCTAssertEqual(label(["", ""]), DiveClusterLabel(title: unknown, containsSelection: false))
    }
}
