// GasMix+LocalizedDisplay.swift — JD2Core/Utilities
// 統一氣體混合顯示名稱：Air 在地化；EANx/Trimix 維持國際通用簡寫（PADI/業界慣例），
// 不翻譯——跟壓力單位 bar/psi 一樣是潛水員共通的技術代碼。取代原本三處各自重寫
// 一次 switch（且其中一處會產生 "EANx (EANx32)" 這種重複字串的顯示 bug）。
//
// ⚠️ 吃 AppLanguageManager 當參數、不用 String(localized:)：這是 GasMix（DiveKit
// 型別）的 extension，不是 View，沒有 SwiftUI Environment 可用；且呼叫端把結果
// 當 String 用（塞進 SheetDetailRow(value:) 等），不是 Text，無法靠
// `.environment(\.locale)` 即時跟隨 in-app 語言切換。跟 DiveSiteSheetView 同一類
// bug（String(localized:) 讀系統 Locale，語言切換後不重開 App 會殘留舊語言），
// 修法比照改吃 languageManager.localized(_:)。

import Foundation
import DiveKit

extension GasMix {
    func localizedDisplayName(_ languageManager: AppLanguageManager) -> String {
        self == .air ? languageManager.localized("Air") : displayName
    }
}
