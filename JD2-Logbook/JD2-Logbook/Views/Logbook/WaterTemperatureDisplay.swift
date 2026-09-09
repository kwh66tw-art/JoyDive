// WaterTemperatureDisplay.swift — JD2-Logbook/Views/Logbook
//
// 🔴 **本檔存在的唯一理由是「顯示規格可以被測試觀察」**（2026-09-09，稽核發現③）。
//
// C2（2026-09-07）把水溫改為 optional、未記錄時顯示「—」，並附了測試。但稽核
// 實測發現：把 `DiveRowView` 的 `?? "—"` 改成編造值，**140 支測試全綠**。
// 根因是那支測試把 View 裡的運算式**重打了一遍**再斷言自己那份拷貝：
//
//     let displayed = dive.waterTemperature.map { unit.formatTemperature($0) } ?? "—"
//     XCTAssertEqual(displayed, "—")     // ← View 改成什麼都不影響這支
//
// 測試與生產是兩份長得一樣、各自獨立的實作，所以它永遠不會紅（家族陷阱 19）。
// 把運算式收斂到本檔的具名函式、讓 View 呼叫它之後，測試才真的在測產品。
//
// 放在 App 層而非 DiveKit 是 PM 2026-09-09 裁示（本專案決定）：這屬顯示層、不是演算法，
// 為了消除三個 App 的三行重複而動 Kit 並連帶三個 App 升版，代價不成比例。

import Foundation
import DiveKit

/// 水溫顯示：未記錄（`nil`）時的呈現規格集中於此。
enum WaterTemperatureDisplay {

    /// 未記錄時顯示的佔位符。
    ///
    /// ⚠️ 全形破折號「—」，不是連字號「-」也不是減號「−」——
    /// 三者在不同字型下寬度差異明顯，混用會讓列表對不齊。
    static let placeholder = "—"

    /// 日誌列表用：交給 `UnitSystem.formatTemperature` 格式化。
    static func rowValue(_ celsius: Double?, unitSystem: UnitSystem) -> String {
        guard let celsius else { return placeholder }
        return unitSystem.formatTemperature(celsius)
    }

    /// 統計格（`DiveStatCell`）用的數值：整數，小數點依語系。
    static func statValue(_ celsius: Double?,
                          unitSystem: UnitSystem,
                          locale: Locale) -> String {
        guard let celsius else { return placeholder }
        return String(format: "%.0f", locale: locale,
                      unitSystem.convertTemperature(celsiusValue: celsius))
    }

    /// 統計格用的單位符號。
    ///
    /// 🔴 **未記錄時必須留空**。若照常回傳「°C」，畫面會顯示「— °C」
    /// ——那是一個**看起來像有讀數**的組合，比明顯的空白更容易誤導
    /// （F-20 節點 7：合理的假值比明顯的假值危險）。
    /// 數值與單位分屬兩個參數、由呼叫端各自填入，很容易只改其中一個，
    /// 因此兩者的 nil 規則刻意寫在同一個檔案裡對照。
    static func statUnit(_ celsius: Double?, unitSystem: UnitSystem) -> String {
        celsius == nil ? "" : unitSystem.temperatureSymbol
    }
}
