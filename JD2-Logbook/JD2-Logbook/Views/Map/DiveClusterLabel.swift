// DiveClusterLabel.swift — JD2-Logbook/Views/Map/
// v1.4 B1-A（PM 2026-11-04）：聚合點的名稱與選取標示由我們決定，不交給 MapKit 從成員中任挑一筆。
// 問題定義與四層追溯見 `docs/decisions/D-2026-10-26-v1.4-D3至D7裁示.md`「B1-A」節。
//
// 規則（依序，先符合者為準）：
//   ① 成員含目前選取的潛水 ⇒ 名稱＝該筆的地點，並標示為選取中。
//   ② 成員地點全部相同 ⇒ 用該名稱。
//   ③ 不同地點混在一起 ⇒ 不用任何一筆的地點，改用中性說法（不帶數字：Logbook 的語言切換路徑不支援依數量選複數形，見 F-09）。
//   ④ 地點空白 ⇒ 以「未知地點」字串參與比較與顯示。

import Foundation

struct DiveClusterLabel: Equatable {
    let title: String
    /// 成員含目前選取的潛水（①）：聚合點要做選取標示。
    let containsSelection: Bool
}

enum DiveClusterLabeling {

    /// - Parameters:
    ///   - memberLocations: 各成員的 `DiveLog.location`（原值，空白由 ④ 處理）。
    ///   - selectedIndex: 目前選取的潛水在 `memberLocations` 中的位置；不在這個聚合點裡為 nil。
    static func label(memberLocations: [String],
                      selectedIndex: Int?,
                      unknownLocationText: String,
                      multipleSitesText: String) -> DiveClusterLabel {
        let names = memberLocations.map { $0.isEmpty ? unknownLocationText : $0 }
        if let selectedIndex, names.indices.contains(selectedIndex) {
            return DiveClusterLabel(title: names[selectedIndex], containsSelection: true)
        }
        if let first = names.first, names.allSatisfy({ $0 == first }) {
            return DiveClusterLabel(title: first, containsSelection: false)
        }
        return DiveClusterLabel(title: multipleSitesText, containsSelection: false)
    }
}
