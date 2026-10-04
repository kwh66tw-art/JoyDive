// DatabaseOpenErrorView.swift — JD2-Logbook/Views
// v1.3 P0-1／D2（PM 2026-10-04 核准）：資料庫打不開時顯示的錯誤頁，取代原本的 `fatalError` 閃退。
//
// 只說使用者能做的事（更新 App、聯絡我們）並明說資料沒有被刪除；不顯示錯誤代碼細節
// （對使用者無意義），技術細節只寫進 console 供除錯。顯示此頁時 App 不載入日誌畫面、不寫入任何資料。

import SwiftUI

struct DatabaseOpenErrorView: View {
    @Environment(AppLanguageManager.self) private var languageManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(verbatim: languageManager.localized("Your dive log could not be opened"))
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(verbatim: languageManager.localized("Your saved dives have not been deleted. Please update JoyDive² to the latest version. If the problem continues, contact us through the App Store page."))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
