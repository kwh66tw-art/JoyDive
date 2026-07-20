// GasMix+LocalizedDisplay.swift — JD2Core/Utilities
// 統一氣體混合顯示名稱：Air 在地化；EANx/Trimix 維持國際通用簡寫（PADI/業界慣例），
// 不翻譯——跟壓力單位 bar/psi 一樣是潛水員共通的技術代碼。取代原本三處各自重寫
// 一次 switch（且其中一處會產生 "EANx (EANx32)" 這種重複字串的顯示 bug）。

import Foundation
import DiveKit

extension GasMix {
    var localizedDisplayName: String {
        self == .air ? String(localized: "Air") : displayName
    }
}
