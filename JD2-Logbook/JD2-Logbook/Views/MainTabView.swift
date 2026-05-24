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

    /// 匯入成功後要 highlight 的潛水 ID（iOS + macOS 共用）
    @State private var postImportHighlightID: PersistentIdentifier? = nil

    #if os(iOS)
    @State private var selectedTab: Int = 0
    #else
    @State private var sidebarSelection: SidebarItem? = .logbook
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
            LogbookContainerView(highlightedDiveID: postImportHighlightID)
                .tabItem { Label("Logbook", systemImage: "list.bullet.below.rectangle") }
                .tag(0)

            MapView()
                .tabItem { Label("Map", systemImage: "map") }
                .tag(1)

            ImportWizardView(
                onImportSuccess: { highlightID in
                    postImportHighlightID = highlightID
                    withAnimation { selectedTab = 0 }
                }
            )
            .tabItem { Label("Import", systemImage: "square.and.arrow.down") }
            .tag(2)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(3)
        }
    }

    // MARK: - macOS：NavigationSplitView

    #else
    private var macOSBody: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(SidebarItem.allCases, selection: $sidebarSelection) { item in
                Label(item.label, systemImage: item.icon)
                    .tag(item)
            }
            .listStyle(.sidebar)
            .navigationTitle("JD2 Logbook")
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            switch sidebarSelection ?? .logbook {
            case .logbook:
                // HSplitView 內部自帶 NavigationStack，不需在此包覆
                MacLogbookSplitView(highlightID: postImportHighlightID)

            case .map:
                // 提供 NavigationStack，讓 MapView 不再自包（解決頂部空白）
                NavigationStack {
                    MapView()
                }

            case .importDives:
                // 提供 NavigationStack，讓 ImportWizardView 不再自包（解決頂部空白）
                NavigationStack {
                    ImportWizardView(onImportSuccess: { highlightID in
                        postImportHighlightID = highlightID
                        sidebarSelection = .logbook
                    })
                }

            case .settings:
                // 提供 NavigationStack，讓 SettingsView 不再自包
                // → 解決頂部空白；LicensesView NavigationLink 在此 stack 下正常運作
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
    #endif
}

// MARK: - macOS Logbook：HSplitView（左列表 + 右詳情）

#if !os(iOS)
private struct MacLogbookSplitView: View {
    var highlightID: PersistentIdentifier?

    @Query(sort: \DiveLog.dateTime, order: .reverse) private var dives: [DiveLog]
    @State private var selectedDive: DiveLog? = nil
    @State private var viewMode: LogbookViewMode = .list
    @State private var showNewDiveSheet = false

    var body: some View {
        Group {
            if dives.isEmpty {
                // ── 空狀態：全版面單一提示（避免左右欄雙重空狀態）──
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Text("Dive Logbook")
                            .font(.headline)
                            .padding(.leading, 4)
                        Spacer()
                        Button { showNewDiveSheet = true } label: {
                            Image(systemName: "plus")
                        }
                        .help(String(localized: "Add New Dive"))
                        .accessibilityLabel(String(localized: "Add New Dive"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.bar)

                    Divider()

                    ContentUnavailableView(
                        label: {
                            Label("No dives yet", systemImage: "water.waves")
                        },
                        description: {
                            Text("Use the Import tab to add your dive computer logs.")
                        }
                    )
                }

            } else {
                HSplitView {
                    // ── 左欄：自訂 header 取代 NavigationStack，消除頂部空白 ──
                    VStack(spacing: 0) {
                        HStack(spacing: 6) {
                            Text("Dive Logbook")
                                .font(.headline)
                                .padding(.leading, 4)
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewMode = (viewMode == .list) ? .calendar : .list
                                }
                            } label: {
                                Image(systemName: viewMode == .list ? "calendar" : "list.bullet")
                            }
                            .help(viewMode == .list
                                  ? String(localized: "Switch to Calendar View")
                                  : String(localized: "Switch to List View"))
                            .accessibilityLabel(
                                viewMode == .list
                                    ? String(localized: "Switch to Calendar View")
                                    : String(localized: "Switch to List View")
                            )
                            Button { showNewDiveSheet = true } label: {
                                Image(systemName: "plus")
                            }
                            .help(String(localized: "Add New Dive"))
                            .accessibilityLabel(String(localized: "Add New Dive"))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.bar)

                        Divider()

                        switch viewMode {
                        case .list:
                            DiveLogListView(
                                highlightedDiveID: highlightID,
                                onDiveTapped: { dive in selectedDive = dive }
                            )
                        case .calendar:
                            DiveCalendarView(onDiveTapped: { dive in selectedDive = dive })
                        }
                    }
                    .frame(minWidth: 260, idealWidth: 320, maxWidth: 440)

                    // ── 右欄：保留 NavigationStack 供 Edit/Export toolbar 使用 ──
                    NavigationStack {
                        if let dive = selectedDive {
                            DiveLogDetailView(dive: dive)
                        } else {
                            ContentUnavailableView {
                                Label("No Dive Selected", systemImage: "list.bullet.below.rectangle")
                            } description: {
                                Text("Select a dive from the list to view details.")
                            }
                            .navigationTitle("Dive Details")
                        }
                    }
                    .frame(minWidth: 300)
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
