// DiveLogListView.swift — JD2-Logbook/Views/Logbook/
// Week 9 — 潛水日誌列表，含統計 Header + 搜尋 + 空狀態

import SwiftUI
import SwiftData

struct DiveLogListView: View {
    @Query(sort: \DiveLog.dateTime, order: .reverse) var dives: [DiveLog]
    @State private var searchText = ""

    /// 匯入後高亮顯示的潛水 ID（由 MainTabView / ImportWizardView 傳入）
    var highlightedDiveID: PersistentIdentifier? = nil
    @State private var highlightFlash: PersistentIdentifier? = nil   // iOS flash 動畫用

    #if !os(iOS)
    /// macOS List 選取狀態（方向鍵 + 滑鼠點選）
    @State private var selectedID: PersistentIdentifier? = nil
    #endif

    /// macOS 專用：點擊 row 時的回調（macOS 不用 NavigationLink，用此 binding 更新詳情欄）
    var onDiveTapped: ((DiveLog) -> Void)? = nil

    var filteredDives: [DiveLog] {
        guard !searchText.isEmpty else { return dives }
        return dives.filter {
            $0.location.localizedCaseInsensitiveContains(searchText) ||
            $0.notes.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if dives.isEmpty {
                // 空狀態
                ContentUnavailableView(
                    label: {
                        Label("No dives yet", systemImage: "water.waves")
                    },
                    description: {
                        Text("Use the Import tab to add your dive computer logs.")
                    }
                )
            } else {
                VStack(spacing: 0) {
                    // 統計 Header
                    StatsHeaderView(dives: dives)

                    // 日誌列表
                    #if os(iOS)
                    // ── iOS：NavigationLink 導航 + flash 高亮 ──────────
                    List {
                        ForEach(filteredDives) { dive in
                            NavigationLink(value: dive) {
                                DiveRowView(dive: dive)
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(
                                highlightFlash == dive.persistentModelID
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.clear
                            )
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: highlightedDiveID) { _, newID in
                        guard let newID else { return }
                        withAnimation(.easeIn(duration: 0.3)) { highlightFlash = newID }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeOut(duration: 0.5)) { highlightFlash = nil }
                        }
                    }
                    .searchable(
                        text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: Text("Search location…")
                    )

                    #else
                    // ── macOS：搜尋欄內嵌列表上方 + List(selection:) 方向鍵導航 ──
                    VStack(spacing: 0) {
                        // 搜尋欄（直接嵌入，避免 .toolbar placement 跑到視窗右上角）
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField(String(localized: "Search location…"), text: $searchText)
                                .textFieldStyle(.plain)
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.bar)

                        Divider()

                        List(selection: $selectedID) {
                            ForEach(filteredDives) { dive in
                                DiveRowView(dive: dive)
                                    .tag(dive.persistentModelID)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(
                                        selectedID == dive.persistentModelID
                                            ? Color.accentColor.opacity(0.15)
                                            : Color.clear
                                    )
                            }
                        }
                        .listStyle(.plain)
                        // 選取變化（滑鼠點擊 / 方向鍵）→ 更新右側詳情欄
                        .onChange(of: selectedID) { _, newID in
                            guard let newID,
                                  let dive = filteredDives.first(where: { $0.persistentModelID == newID })
                            else { return }
                            onDiveTapped?(dive)
                        }
                        // 匯入成功後自動選取新日誌（取代 iOS flash 動畫）
                        .onChange(of: highlightedDiveID) { _, newID in
                            guard let newID else { return }
                            selectedID = newID
                        }
                    }
                    #endif
                }
            }
        }
    }
}

// MARK: - 統計 Header

struct StatsHeaderView: View {
    let dives: [DiveLog]

    var totalDives: Int { dives.count }

    var totalHours: Double {
        Double(dives.reduce(0) { $0 + $1.diveTimeSeconds }) / 3600.0
    }

    var deepestDive: Double {
        dives.map(\.maxDepth).max() ?? 0
    }

    var body: some View {
        HStack(spacing: 0) {
            StatCell(
                value: "\(totalDives)",
                label: "Dives",
                icon: "figure.pool.swim"
            )

            Divider()
                .frame(height: 32)

            StatCell(
                value: String(format: "%.1fh", totalHours),
                label: "Total Time",
                icon: "timer"
            )

            Divider()
                .frame(height: 32)

            StatCell(
                value: String(format: "%.1fm", deepestDive),
                label: "Deepest",
                icon: "arrow.down.to.line"
            )
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}

struct StatCell: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(.primary)

            Text(LocalizedStringKey(label))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

#Preview {
    NavigationStack {
        DiveLogListView()
            .navigationTitle("Dive Logbook")
    }
    .modelContainer(DiveLogDatabase.shared.modelContainer)
}
