// DiveLog+EnvironmentDisplay.swift — JD2Core/Utilities
// v1.4 A1（PM 2026-10-26）：詳細頁與地圖面板共用的「水域類型」顯示字串。取代原本兩處各寫一次的
// `switch environmentType { … default: Seawater }`——default 落到海水，會把「未記錄」顯示成海水。
//
// 水域類型（儲存值）與「高海拔」（由 `surfacePressureBar` 推導的徽章）是兩件獨立的事，並列顯示，
// 例如「海水・高海拔潛水」；推導不寫回儲存值（裁示 (b)，決策 `docs/decisions/D-2026-10-26-環境欄位未記錄.md`）。
// 舊標籤 "altitude" ⇒ 水域未記錄＋徽章依氣壓決定。
//
// 吃 AppLanguageManager 當參數，理由同 `GasMix+LocalizedDisplay.swift`。

import Foundation

extension DiveLog {
    /// `@MainActor`：`AppLanguageManager.localized` 是 main actor 隔離；呼叫端都是 View。
    @MainActor
    func environmentDisplayText(_ languageManager: AppLanguageManager) -> String {
        let water: String
        switch waterType {
        case .seawater?:   water = languageManager.localized("Seawater")
        case .freshwater?: water = languageManager.localized("Freshwater")
        case nil:          water = languageManager.localized("Not Recorded")
        }
        guard isHighAltitude else { return water }
        return water + " · " + languageManager.localized("Altitude")
    }
}
