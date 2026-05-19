// SettingsPlaceholderView.swift — JD2-Logbook/Views/Settings/
// Week 9 — 設定 Tab 佔位視圖（Week 11 實作：語言切換、外觀、IAP）

import SwiftUI

struct SettingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                label: {
                    Label("Settings coming soon", systemImage: "gearshape")
                },
                description: {
                    Text("Language, appearance, and preferences will be available in a future update.")
                }
            )
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    SettingsPlaceholderView()
}
