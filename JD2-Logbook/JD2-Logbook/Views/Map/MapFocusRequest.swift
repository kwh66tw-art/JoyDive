// MapFocusRequest.swift — JD2-Logbook/Views/Map/
// v1.4 B1（PM 2026-10-26，D6）：「在地圖上顯示這筆潛水」的跨分頁請求。
//
// 分頁狀態在 `MainTabView`（iOS `selectedTab`／macOS `sidebarSelection`），詳細頁碰不到 ⇒ 由 `MainTabView`
// 建立本物件並放進 environment：詳細頁寫入目標，`MainTabView` 切到地圖，`MapView` 出現（或已在畫面上）時
// 讀取、選取並置中，然後清空。地圖頁內的卡片（`DiveSiteSheetView`）寫入時只置中、不切分頁（本來就在地圖）。
// environment 以 optional 讀取：預覽與測試沒有注入時，座標列維持純文字。

import SwiftUI
import SwiftData

@MainActor
@Observable
final class MapFocusRequest {
    /// 待處理的目標；`MapView` 處理後清空。
    private(set) var targetDiveID: PersistentIdentifier?

    func focus(on dive: DiveLog) {
        targetDiveID = dive.persistentModelID
    }

    /// `MapView` 取走請求（取走即清空，同一個請求只處理一次）。
    func take() -> PersistentIdentifier? {
        defer { targetDiveID = nil }
        return targetDiveID
    }
}
