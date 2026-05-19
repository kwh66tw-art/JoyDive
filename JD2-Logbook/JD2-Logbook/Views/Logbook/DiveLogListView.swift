// DiveLogListView.swift — JD2-Logbook/Views/Logbook/
// Week 9 — 潛水日誌列表，含統計 Header + 搜尋 + 空狀態

import SwiftUI
import SwiftData

struct DiveLogListView: View {
    @Query(sort: \DiveLog.dateTime, order: .reverse) var dives: [DiveLog]
    @State private var searchText = ""

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
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .searchable(
                        text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: Text("Search location…")
                    )
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
