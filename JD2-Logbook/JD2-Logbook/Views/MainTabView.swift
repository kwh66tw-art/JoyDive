// MainTabView.swift — JD2-Logbook/Views/MainTabView.swift
// Week 9 — Bottom TabBar 主架構（Week 11 更新：selectedTab + 匯入後跳轉）
//
// Tab index：0 = Logbook, 1 = Map, 2 = Import, 3 = Settings

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab: Int = 0

    /// 匯入成功後要 highlight 的潛水 ID，傳給 LogbookContainerView
    @State private var postImportHighlightID: PersistentIdentifier? = nil

    var body: some View {
        TabView(selection: $selectedTab) {
            // MARK: - 日誌 Tab (0)
            LogbookContainerView(highlightedDiveID: postImportHighlightID)
                .tabItem {
                    Label("Logbook", systemImage: "list.bullet.below.rectangle")
                }
                .tag(0)

            // MARK: - 地圖 Tab (1)
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(1)

            // MARK: - 匯入 Tab (2)
            ImportWizardView(
                onImportSuccess: { highlightID in
                    // 決策 #2：切換至 Logbook Tab + highlight 最新項目
                    postImportHighlightID = highlightID
                    withAnimation {
                        selectedTab = 0
                    }
                }
            )
            .tabItem {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .tag(2)

            // MARK: - 設定 Tab (3)
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(3)
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(DiveLogDatabase.shared.modelContainer)
}
