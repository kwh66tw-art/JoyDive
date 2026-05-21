// DiveLogListView.swift — JD2-Logbook/Views/Logbook/
// Week 9 — 潛水日誌列表，含統計 Header + 搜尋 + 空狀態

import SwiftUI
import SwiftData

struct DiveLogListView: View {
    @Query(sort: \DiveLog.dateTime, order: .reverse) var dives: [DiveLog]
    @State private var searchText = ""

    /// 匯入後高亮顯示的潛水 ID（由 MainTabView / ImportWizardView 傳入）
    var highlightedDiveID: PersistentIdentifier? = nil
    @State private var highlightFlash: PersistentIdentifier? = nil

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
                        // flash 動畫：高亮 → 1.5 秒後消失
                        withAnimation(.easeIn(duration: 0.3)) {
                            highlightFlash = newID
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeOut(duration: 0.5)) {
                                highlightFlash = nil
                            }
                        }
                    }
                    #if os(iOS)
                    .searchable(
                        text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: Text("Search location…")
                    )
                    #else
                    .searchable(
                        text: $searchText,
                        placement: .toolbar,
                        prompt: Text("Search location…")
                    )
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
