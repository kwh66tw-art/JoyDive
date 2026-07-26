// DiveLogListView.swift — JD2-Logbook/Views/Logbook/
// Week 9 — 潛水日誌列表，含統計 Header + 搜尋 + 空狀態

import SwiftUI
import SwiftData

struct DiveLogListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppLanguageManager.self) private var languageManager
    @Query(sort: \DiveLog.dateTime, order: .reverse) var dives: [DiveLog]
    @State private var searchText = ""

    /// 匯入後高亮顯示的潛水 ID（由 MainTabView / ImportWizardView 傳入）
    var highlightedDiveID: PersistentIdentifier? = nil
    @State private var highlightFlash: PersistentIdentifier? = nil   // iOS flash 動畫用

    #if !os(iOS)
    /// macOS 選取狀態（方向鍵 + 滑鼠點選）
    @State private var selectedID: PersistentIdentifier? = nil
    /// macOS：列表鍵盤焦點，讓上下鍵選取生效
    @FocusState private var listFocused: Bool
    #endif

    /// macOS 專用：點擊 row 時的回調（macOS 不用 NavigationLink，用此 binding 更新詳情欄）
    var onDiveTapped: ((DiveLog) -> Void)? = nil

    /// 刪除後通知容器（macOS 用以清空右側被刪的詳情）
    var onDiveDeleted: ((DiveLog) -> Void)? = nil

    private func deleteDive(_ dive: DiveLog) {
        let id = dive.persistentModelID
        modelContext.delete(dive)
        try? modelContext.save()
        #if !os(iOS)
        if selectedID == id { selectedID = nil }
        #endif
        onDiveDeleted?(dive)
    }

    var filteredDives: [DiveLog] {
        guard !searchText.isEmpty else { return dives }
        return dives.filter {
            $0.location.localizedCaseInsensitiveContains(searchText) ||
            $0.notes.localizedCaseInsensitiveContains(searchText)
        }
    }

    #if !os(iOS)
    /// macOS：上下鍵移動選取，並同步右側詳情與捲動位置
    private func moveSelection(_ direction: MoveCommandDirection, proxy: ScrollViewProxy) {
        guard !filteredDives.isEmpty else { return }
        let currentIndex = filteredDives.firstIndex { $0.persistentModelID == selectedID }
        let newIndex: Int
        switch direction {
        case .up:
            newIndex = currentIndex.map { max(0, $0 - 1) } ?? (filteredDives.count - 1)
        case .down:
            newIndex = currentIndex.map { min(filteredDives.count - 1, $0 + 1) } ?? 0
        default:
            return
        }
        let dive = filteredDives[newIndex]
        selectedID = dive.persistentModelID
        onDiveTapped?(dive)
        withAnimation { proxy.scrollTo(dive.persistentModelID, anchor: .center) }
    }
    #endif

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
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteDive(dive)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteDive(dive)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
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
                    // ── macOS：搜尋欄內嵌列表上方 + ScrollView 卡片（卡片邊框顯示選取）──
                    VStack(spacing: 0) {
                        // 搜尋欄（直接嵌入，避免 .toolbar placement 跑到視窗右上角）
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField(languageManager.localized("Search location…"), text: $searchText)
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

                        // 不使用 List 的系統選取/焦點框（與卡片圓角衝突會產生偏移粗藍框）
                        // 改用 ScrollView + LazyVStack，選取狀態直接畫在卡片邊框上
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    ForEach(filteredDives) { dive in
                                        DiveRowView(
                                            dive: dive,
                                            isSelected: selectedID == dive.persistentModelID
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedID = dive.persistentModelID
                                            onDiveTapped?(dive)
                                            listFocused = true // 點選後取得鍵盤焦點，方向鍵可接續導覽
                                        }
                                        // WCAG: onTapGesture 不會自動暴露 a11y 動作，明確補上
                                        .accessibilityAddTraits(.isButton)
                                        .accessibilityAction {
                                            selectedID = dive.persistentModelID
                                            onDiveTapped?(dive)
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                deleteDive(dive)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            // 選單出現時把選取移到游標所在的這筆，避免誤刪聚焦中的另一筆
                                            .onAppear {
                                                selectedID = dive.persistentModelID
                                                onDiveTapped?(dive)
                                            }
                                        }
                                        .id(dive.persistentModelID)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                            // 讓 ScrollView 可接收鍵盤焦點與方向鍵；關閉焦點框避免又出現藍框
                            .focusable()
                            .focused($listFocused)
                            .focusEffectDisabled()
                            // 上下鍵移動選取（取代原 List 內建的方向鍵導覽）
                            .onMoveCommand { direction in
                                moveSelection(direction, proxy: proxy)
                            }
                            .onAppear { listFocused = true }
                            // 匯入成功後自動選取新日誌並捲動到該筆
                            .onChange(of: highlightedDiveID) { _, newID in
                                guard let newID else { return }
                                selectedID = newID
                                if let dive = filteredDives.first(where: { $0.persistentModelID == newID }) {
                                    onDiveTapped?(dive)
                                }
                                withAnimation { proxy.scrollTo(newID, anchor: .center) }
                            }
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

    /// 總時間以「Xh Ym」呈現（不足 1 小時只顯示 Ym），比小數點時數直覺
    var totalTimeText: String {
        let total = dives.reduce(0) { $0 + $1.diveTimeSeconds }
        let h = total / 3600
        let m = (total % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
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
                value: totalTimeText,
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
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(LocalizedStringKey(label))
                .font(.caption2)
                .foregroundStyle(Color.accessibleSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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
