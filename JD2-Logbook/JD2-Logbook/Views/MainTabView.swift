// MainTabView.swift — JD2-Logbook/Views/MainTabView.swift
// Week 9 — Bottom TabBar 主架構
//
// Tabs: 日誌 | 地圖(placeholder) | 匯入 | 設定(placeholder)

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // MARK: - 日誌 Tab
            LogbookContainerView()
                .tabItem {
                    Label("Logbook", systemImage: "list.bullet.below.rectangle")
                }

            // MARK: - 地圖 Tab（Week 10 實作）
            MapPlaceholderView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }

            // MARK: - 匯入 Tab
            ImportWizardView()
                .tabItem {
                    Label("Import", systemImage: "square.and.arrow.down")
                }

            // MARK: - 設定 Tab（Week 11 實作）
            SettingsPlaceholderView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    MainTabView()
}
