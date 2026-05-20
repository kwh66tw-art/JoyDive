// LogbookContainerView.swift — JD2-Logbook/Views/Logbook/
// Week 9 — 日誌 Tab 容器，包含 List ↔ Calendar 切換 + NavigationStack

import SwiftUI
import SwiftData

enum LogbookViewMode {
    case list, calendar
}

struct LogbookContainerView: View {
    @State private var viewMode: LogbookViewMode = .list
    @State private var navigationPath = NavigationPath()
    @State private var showNewDiveSheet = false

    // 讓外部（如 ImportWizardView 匯入成功後）能 highlight 最新項目
    var highlightedDiveID: PersistentIdentifier? = nil

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                switch viewMode {
                case .list:
                    DiveLogListView(highlightedDiveID: highlightedDiveID)
                case .calendar:
                    DiveCalendarView()
                }
            }
            .navigationTitle("Dive Logbook")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // 右側：視圖切換
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode = (viewMode == .list) ? .calendar : .list
                        }
                    } label: {
                        Image(systemName: viewMode == .list ? "calendar" : "list.bullet")
                            .imageScale(.medium)
                    }
                    .accessibilityLabel(
                        viewMode == .list
                            ? String(localized: "Switch to Calendar View")
                            : String(localized: "Switch to List View")
                    )
                }

                // 右側：新增潛水（決策 #7）
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewDiveSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .imageScale(.medium)
                    }
                    .accessibilityLabel(String(localized: "Add New Dive"))
                }
            }
            // 全域 NavigationDestination：List 和 Calendar 共用
            .navigationDestination(for: DiveLog.self) { dive in
                DiveLogDetailView(dive: dive)
            }
            .sheet(isPresented: $showNewDiveSheet) {
                DiveLogEditSheet(mode: .new)
            }
        }
    }
}

#Preview {
    LogbookContainerView()
        .modelContainer(DiveLogDatabase.shared.modelContainer)
}
