// DiveLog+Search.swift — JD2Core/Utilities
// v1.4 A2（PM 2026-10-07 採納、2026-10-26 裁示 D3；決策 `docs/decisions/D-2026-10-26-v1.4-D3至D7裁示.md`）：
// 列表搜尋由「地點＋備註」擴充為「潛點（＝`location`）＋備註＋潛伴＋標籤」。
//
// 潛伴／標籤只存在 `importExtrasJSON`（沒有獨立欄位；家族無正式欄位計畫）。**解析 JSON、只比對指定鍵的值**，
// 不對原始 JSON 字串做搜尋——那會命中鍵名（搜「buddy」每筆有潛伴的都中）與其他欄位（序號、韌體等）。
// 鍵名取自 DiveImportKit 解析器實際寫入的字面值（2026-10-26 grep：`"buddy"`＝UDDF／Subsurface XML／
// Subsurface CSV／Diving Log SQLite；`"tags"`＝Subsurface XML）。Kit 若新增其他鍵名，這裡要同步。

import Foundation

extension DiveLog {
    /// 搜尋時比對值的 `importExtras` 鍵（潛伴、標籤）。
    static let searchableImportExtraKeys = ["buddy", "tags"]

    /// 列表搜尋是否命中。空白查詢 ⇒ 全部命中（與原本 `searchText.isEmpty` 時顯示全部一致）。
    func matchesSearch(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        if location.localizedCaseInsensitiveContains(query) || notes.localizedCaseInsensitiveContains(query) {
            return true
        }
        let extras = importExtras
        return Self.searchableImportExtraKeys.contains { key in
            extras[key]?.localizedCaseInsensitiveContains(query) == true
        }
    }
}
