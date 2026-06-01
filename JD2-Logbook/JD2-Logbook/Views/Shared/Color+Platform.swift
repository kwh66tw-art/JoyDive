// Color+Platform.swift — JD2-Logbook/Views/Shared/
// 跨平台語意色彩擴充
//
// iOS 使用 UIColor 語意色；macOS 使用 NSColor 等效色。
// 所有 View 統一呼叫 Color.platformXxx，不直接用 Color(.uiColorName)。

import SwiftUI

extension Color {

    /// 對應 iOS `secondarySystemGroupedBackground`
    /// 用途：卡片 / row 背景（DiveRowView、DiveSiteSheetView 等）
    static var platformSecondaryGroupedBackground: Color {
        #if os(iOS)
        Color(.secondarySystemGroupedBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }

    /// 對應 iOS `systemGroupedBackground`
    /// 用途：步驟指示器背景（ImportWizardView）
    static var platformGroupedBackground: Color {
        #if os(iOS)
        Color(.systemGroupedBackground)
        #else
        Color(NSColor.windowBackgroundColor)
        #endif
    }

    /// 對應 iOS `tertiarySystemFill`
    /// 用途：廣告佔位框背景（AdBannerView Debug）
    static var platformTertiaryFill: Color {
        #if os(iOS)
        Color(.tertiarySystemFill)
        #else
        Color(NSColor.quaternaryLabelColor).opacity(0.25)
        #endif
    }

    /// WCAG 達標的「次要灰」：取代 `.secondary` 用於小字次要標籤/數值，
    /// 在淺/深色模式皆確保與背景對比 ≥ 4.5:1（深 0.32 / 淺 0.75 白階）。
    static var accessibleSecondary: Color {
        #if os(iOS)
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 0.75, alpha: 1)
                : UIColor(white: 0.32, alpha: 1)
        })
        #else
        Color(nsColor: NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return dark ? NSColor(white: 0.75, alpha: 1) : NSColor(white: 0.32, alpha: 1)
        })
        #endif
    }
}
