// MainTabView.swift — JD2-Logbook/Views/MainTabView.swift
// Week 9  — Bottom TabBar 主架構（iOS）
// Week 13 — macOS NavigationSplitView + HSplitView 重構
//
// iOS：TabView（Tab 0=Logbook, 1=Map, 2=Import, 3=Settings）
// macOS：NavigationSplitView sidebar + HSplitView（Logbook: 左列表/右詳情）

import SwiftUI
import SwiftData

// MARK: - Sidebar Item（macOS）

private enum SidebarItem: Int, CaseIterable, Identifiable {
    case logbook     = 0
    case map         = 1
    case importDives = 2
    case settings    = 3

    var id: Int { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .logbook:     return "Logbook"
        case .map:         return "Map"
        case .importDives: return "Import"
        case .settings:    return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .logbook:     return "list.bullet.below.rectangle"
        case .map:         return "map"
        case .importDives: return "square.and.arrow.down"
        case .settings:    return "gearshape"
        }
    }
}

// MARK: - Main View

struct MainTabView: View {

    @Environment(AppLanguageManager.self) private var languageManager

    /// 匯入成功後要 highlight 的潛水 ID（iOS + macOS 共用）
    @State private var postImportHighlightID: PersistentIdentifier? = nil

    #if os(iOS)
    @State private var selectedTab: Int = 0
    #else
    @State private var sidebarSelection: SidebarItem? = .logbook
    /// 真正的 @State 綁定（非常數），讓 sidebar toggle 按鈕可正常開合
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    #endif

    var body: some View {
        #if os(iOS)
        iOSBody
        #else
        macOSBody
        #endif
    }

    // MARK: - iOS：TabView

    #if os(iOS)
    private var iOSBody: some View {
        TabView(selection: $selectedTab) {
            VStack(spacing: 0) {
                LogbookContainerView(highlightedDiveID: postImportHighlightID)
                // 主要廣告版位：日誌為預設且最高流量畫面（Premium 自動隱藏）
                PremiumAwareAdBanner(adUnitID: AdUnitID.logbook)
            }
                .tabItem {
                    Label {
                        Text(verbatim: languageManager.localized("Logbook"))
                    } icon: {
                        Image(systemName: "list.bullet.below.rectangle")
                    }
                }
                .tag(0)

            MapView()
                .tabItem {
                    Label {
                        Text(verbatim: languageManager.localized("Map"))
                    } icon: {
                        Image(systemName: "map")
                    }
                }
                .tag(1)

            ImportWizardView(
                onImportSuccess: { highlightID in
                    postImportHighlightID = highlightID
                    withAnimation { selectedTab = 0 }
                }
            )
            .tabItem {
                Label {
                    Text(verbatim: languageManager.localized("Import"))
                } icon: {
                    Image(systemName: "square.and.arrow.down")
                }
            }
            .tag(2)

            VStack(spacing: 0) {
                SettingsView()
                // 設定頁底部廣告版位（Premium 自動隱藏）
                PremiumAwareAdBanner(adUnitID: AdUnitID.settings)
            }
                .tabItem {
                    Label {
                        Text(verbatim: languageManager.localized("Settings"))
                    } icon: {
                        Image(systemName: "gearshape")
                    }
                }
                .tag(3)
        }
    }

    // MARK: - macOS：NavigationSplitView

    #else
    private var macOSBody: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(SidebarItem.allCases, selection: $sidebarSelection) { item in
                Label(item.label, systemImage: item.icon)
                    .tag(item)
            }
            .listStyle(.sidebar)
            .navigationTitle(Text(verbatim: languageManager.localized("JoyDive²")))
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            switch sidebarSelection ?? .logbook {
            case .logbook:
                // HSplitView 內部自帶 NavigationStack，不需在此包覆
                // 詳情 pane 最小尺寸：左列(260) + 右詳情(300) = 560，縱向 480
                MacLogbookSplitView(highlightID: postImportHighlightID)
                    .frame(minWidth: 560, minHeight: 480)

            case .map:
                // 提供 NavigationStack，讓 MapView 不再自包（解決頂部空白）
                // 地圖 pane 最小寬度需容納「地圖 + 右側 320pt 側面板」，
                // 避免側面板出現時把地圖擠壓/裁切（推開式 HSplitView）。
                NavigationStack {
                    MapView()
                }
                .frame(minWidth: 700, minHeight: 480)

            case .importDives:
                // 提供 NavigationStack，讓 ImportWizardView 不再自包（解決頂部空白）
                // 匯入 pane 最小尺寸（含步驟列 + 雙欄格式卡片，寬度需求略高）
                NavigationStack {
                    ImportWizardView(onImportSuccess: { highlightID in
                        postImportHighlightID = highlightID
                        sidebarSelection = .logbook
                    })
                }
                .frame(minWidth: 440, minHeight: 440) // 匯入內容較精簡，下限較矮以減少底部留白

            case .settings:
                // 提供 NavigationStack，讓 SettingsView 不再自包
                // → 解決頂部空白；LicensesView NavigationLink 在此 stack 下正常運作
                // 設定 pane 最小尺寸（表單較長，下限較高以多顯示內容）
                NavigationStack {
                    SettingsView()
                }
                .frame(minWidth: 420, minHeight: 560)
            }
        }
    }
    #endif
}

// MARK: - macOS Logbook：HSplitView（左列表 + 右詳情）

#if !os(iOS)
private struct MacLogbookSplitView: View {
    @Environment(AppLanguageManager.self) private var languageManager
    var highlightID: PersistentIdentifier?

    @Query(sort: \DiveLog.dateTime, order: .reverse) private var dives: [DiveLog]
    @State private var selectedDive: DiveLog? = nil
    @State private var viewMode: LogbookViewMode = .list
    @State private var showNewDiveSheet = false

    var body: some View {
        Group {
            if dives.isEmpty {
                // ── 空狀態：採用對稱導航標題與滿版空狀態 ──
                NavigationStack {
                    ContentUnavailableView(
                        label: {
                            Label("No dives yet", systemImage: "water.waves")
                        },
                        description: {
                            Text("Use the Import tab to add your dive computer logs.")
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle(Text(verbatim: languageManager.localized("Dive Logbook")))
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button { showNewDiveSheet = true } label: {
                                Image(systemName: "plus")
                            }
                            .help(languageManager.localized("Add New Dive"))
                            .accessibilityLabel(languageManager.localized("Add New Dive"))
                        }
                    }
                }

            } else {
                HSplitView {
                    // ── 左欄 (左對稱導航)：List / Calendar 頂滿，由系統 Title 列託管 ──
                    NavigationStack {
                        VStack(spacing: 0) {
                            switch viewMode {
                            case .list:
                                DiveLogListView(
                                    highlightedDiveID: highlightID,
                                    onDiveTapped: { dive in selectedDive = dive },
                                    onDiveDeleted: { deleted in
                                        if selectedDive?.persistentModelID == deleted.persistentModelID {
                                            selectedDive = nil
                                        }
                                    }
                                )
                            case .calendar:
                                DiveCalendarView(onDiveTapped: { dive in
                                    selectedDive = dive
                                })
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .navigationTitle(Text(verbatim: languageManager.localized("Dive Logbook")))
                        .toolbar {
                            ToolbarItemGroup(placement: .primaryAction) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewMode = (viewMode == .list) ? .calendar : .list
                                        selectedDive = nil // 切換時重設，防止右側錯位
                                    }
                                } label: {
                                    Image(systemName: viewMode == .list ? "calendar" : "list.bullet")
                                }
                                .help(viewMode == .list
                                      ? languageManager.localized("Switch to Calendar View")
                                      : languageManager.localized("Switch to List View"))
                                .accessibilityLabel(viewMode == .list
                                      ? languageManager.localized("Switch to Calendar View")
                                      : languageManager.localized("Switch to List View"))

                                Button { showNewDiveSheet = true } label: {
                                    Image(systemName: "plus")
                                }
                                .help(languageManager.localized("Add New Dive"))
                                .accessibilityLabel(languageManager.localized("Add New Dive"))
                            }
                        }
                    }
                    .frame(minWidth: 260, idealWidth: 320, maxWidth: 440)
                    .frame(maxHeight: .infinity)

                    // ── 右欄 (右對稱導航)：獨立 Stack，確保 Edit 100% 渲染穩定 ──
                    NavigationStack {
                        Group {
                            if let dive = selectedDive {
                                DiveLogDetailView(dive: dive, onDeleted: { selectedDive = nil })
                            } else {
                                ContentUnavailableView {
                                    Label("No Dive Selected", systemImage: viewMode == .list ? "list.bullet.below.rectangle" : "calendar")
                                } description: {
                                    if viewMode == .list {
                                        Text("Select a dive from the list to view details.")
                                    } else {
                                        Text("Select a date with dives from the calendar to view details.")
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .navigationTitle(Text(verbatim: "")) // 空標題保持對齊；verbatim 避免被抽成空字串 key
                    }
                    .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .sheet(isPresented: $showNewDiveSheet) {
            DiveLogEditSheet(mode: .new)
        }
    }
}
#endif

// MARK: - Preview

#Preview {
    MainTabView()
        .modelContainer(DiveLogDatabase.shared.modelContainer)
}
