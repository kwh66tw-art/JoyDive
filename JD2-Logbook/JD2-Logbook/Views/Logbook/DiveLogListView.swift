// DiveLogListView.swift — JD2-Logbook/Views/Logbook/
// Week 9 — 潛水日誌列表，含統計 Header + 搜尋 + 空狀態

import SwiftUI
import SwiftData

struct DiveLogListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppLanguageManager.self) private var languageManager
    @Query(sort: \DiveLog.dateTime, order: .reverse) var dives: [DiveLog]
    @State private var searchText = ""

    // v1.4 搜尋收合（PM 2026-11-04）：搜尋框平時收成工具列的放大鏡，按了才展開。
    // 本專案決定：iOS／macOS 都自己做，不用原生 `.searchToolbarBehavior(.minimize)`——
    // 該 API 是 iOS 26.0+、macOS 不可用（iOS 27.1 SDK SwiftUI.swiftinterface），而本 App 支援 iOS 17、
    // 模擬器只有 26+ ⇒ iOS 17–25 會是一套測不到的不同行為；按鈕位置也要實測才知道，PM 要的是上方工具列。
    // 規則：點放大鏡 ⇒ 展開並聚焦；取消或清空 ⇒ 收回；有搜尋字時不收回（篩選結果不被藏起來）。
    /// 搜尋列是否展開（iOS：是否掛 `.searchable`；macOS：是否顯示自製搜尋列）。
    @State private var isSearchShown = false
    #if os(iOS)
    /// 系統搜尋狀態（`.searchable(isPresented:)`）：按取消會變 false。
    @State private var isSearchPresented = false
    #else
    @FocusState private var searchFieldFocused: Bool
    #endif

    // v1.4 A3：篩選（`DiveListFilter`）。統計列（`StatsHeaderView`）仍吃全部紀錄（D5）。
    @State private var filter = DiveListFilter()
    @State private var judge = TissueLoadingJudge()
    /// 只列資料裡實際存在的選項；資料變動時重算（`datasetKey`），不在每次重繪時重算（要解碼每筆的匯入資料）。
    @State private var availableGases: [DiveGasCategory] = []
    @State private var availableModes: [DiveLogMode] = []

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

    /// macOS：容器的工具列按鈕（列表／月曆切換、新增），排在放大鏡與篩選之後、同一組內——
    /// 父子各宣告一組時順序不由我們決定（11/04 實測子組固定在後）。
    var macToolbarExtras: AnyView? = nil

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
        guard !searchText.isEmpty || filter.isActive else { return dives }
        // v1.4 A2：潛點＋備註＋潛伴＋標籤（見 `DiveLog.matchesSearch`）；A3：篩選再 AND。
        return dives.filter { dive in
            (searchText.isEmpty || dive.matchesSearch(searchText))
                && (!filter.isActive || filter.matches(dive, tissueSupported: judge.results[dive.persistentModelID]))
        }
    }

    /// 紀錄集合或任何會影響篩選判定的欄位變了 ⇒ 值改變（ID＋`replayInputsFingerprint`，後者含氣體、模式、匯入標記）。
    private var datasetKey: Int {
        var hasher = Hasher()
        for dive in dives {
            hasher.combine(dive.persistentModelID)
            hasher.combine(dive.replayInputsFingerprint)
        }
        return hasher.finalize()
    }

    private struct JudgeTaskKey: Equatable {
        let dataset: Int
        let needed: Bool
    }

    /// 有組織負荷條件、且還在算或還有紀錄沒有結果。後者涵蓋剛勾選、`.task` 尚未開始的那幾幀——
    /// 只看 `isComputing` 會在那一瞬間誤顯示「沒有符合的潛水」（2,000 筆模擬器實測）。
    private var isJudgingForFilter: Bool {
        filter.needsTissueJudgement && (judge.isComputing || judge.results.count < dives.count)
    }

    private var filterMenu: some View {
        DiveListFilterMenu(filter: $filter, gases: availableGases, modes: availableModes)
    }

    /// 工具列放大鏡：收合時展開並聚焦；有搜尋字時改實心圖示＋強調色，看得出「搜尋中」。
    private var searchButton: some View {
        Button {
            #if os(iOS)
            isSearchShown = true
            // 同一次更新裡掛上 `.searchable` 又設 isPresented，系統可能還沒建好搜尋列 ⇒ 下一輪再設。
            DispatchQueue.main.async { isSearchPresented = true }
            #else
            if isSearchShown && searchText.isEmpty {
                isSearchShown = false
            } else {
                isSearchShown = true
                DispatchQueue.main.async { searchFieldFocused = true }
            }
            #endif
        } label: {
            Image(systemName: searchText.isEmpty ? "magnifyingglass" : "magnifyingglass.circle.fill")
                .foregroundStyle(searchText.isEmpty ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.accentColor))
        }
        .help(languageManager.localized("Search"))
        .accessibilityLabel(languageManager.localized("Search"))
    }

    /// 取消或清空、且沒有搜尋字 ⇒ 收回成放大鏡。
    private func collapseSearchIfIdle() {
        #if os(iOS)
        if !isSearchPresented && searchText.isEmpty { isSearchShown = false }
        #else
        if !searchFieldFocused && searchText.isEmpty { isSearchShown = false }
        #endif
    }

    /// 篩選中、算完仍沒有結果 ⇒「沒有符合的潛水」＋清除篩選（只清篩選、不清搜尋字）。
    private var showsNoMatches: Bool {
        filter.isActive && filteredDives.isEmpty && !isJudgingForFilter
    }

    private var noMatchesView: some View {
        ContentUnavailableView {
            Label(languageManager.localized("No matching dives"), systemImage: "line.3.horizontal.decrease")
        } actions: {
            Button(languageManager.localized("Clear Filters")) { filter = DiveListFilter() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 組織負荷逐步判定中：列表底部顯示，算完消失。
    private var calculatingRow: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text(verbatim: languageManager.localized("Calculating…"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
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
                        Label(languageManager.localized("No dives yet"), systemImage: "water.waves")
                    },
                    description: {
                        Text(verbatim: languageManager.localized("Use the Import tab to add your dive computer logs."))
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
                                    Label(languageManager.localized("Delete"), systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteDive(dive)
                                } label: {
                                    Label(languageManager.localized("Delete"), systemImage: "trash")
                                }
                            }
                        }
                        if isJudgingForFilter {
                            calculatingRow
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .overlay {
                        if showsNoMatches { noMatchesView }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            searchButton
                            filterMenu
                        }
                    }
                    .onChange(of: highlightedDiveID) { _, newID in
                        guard let newID else { return }
                        withAnimation(.easeIn(duration: 0.3)) { highlightFlash = newID }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeOut(duration: 0.5)) { highlightFlash = nil }
                        }
                    }
                    .modifier(CollapsibleSearch(
                        isShown: isSearchShown,
                        text: $searchText,
                        isPresented: $isSearchPresented,
                        prompt: languageManager.localized("Search site, buddy, tags…")
                    ))
                    .onChange(of: isSearchPresented) { _, _ in collapseSearchIfIdle() }
                    .onChange(of: searchText) { _, _ in collapseSearchIfIdle() }

                    #else
                    // ── macOS：搜尋欄內嵌列表上方 + ScrollView 卡片（卡片邊框顯示選取）──
                    VStack(spacing: 0) {
                        // 搜尋欄（直接嵌入，避免 .toolbar placement 跑到視窗右上角）；
                        // v1.4 平時收合，按左欄工具列的放大鏡才出現（見 `isSearchShown`）。
                        if isSearchShown {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField(languageManager.localized("Search site, buddy, tags…"), text: $searchText)
                                    .textFieldStyle(.plain)
                                    .focused($searchFieldFocused)
                                    // Esc：清空並收回
                                    .onExitCommand {
                                        searchText = ""
                                        isSearchShown = false
                                    }
                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                        isSearchShown = false
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
                            .onChange(of: searchFieldFocused) { _, _ in collapseSearchIfIdle() }

                            Divider()
                        }

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
                                                Label(languageManager.localized("Delete"), systemImage: "trash")
                                            }
                                            // 選單出現時把選取移到游標所在的這筆，避免誤刪聚焦中的另一筆
                                            .onAppear {
                                                selectedID = dive.persistentModelID
                                                onDiveTapped?(dive)
                                            }
                                        }
                                        .id(dive.persistentModelID)
                                    }
                                    if isJudgingForFilter { calculatingRow }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                            .overlay {
                                if showsNoMatches { noMatchesView }
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
                    // v1.4：放大鏡與篩選移到左欄工具列（原本篩選在搜尋欄旁，搜尋列收合後就看不到）。
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            searchButton
                            filterMenu
                            if let macToolbarExtras { macToolbarExtras }
                        }
                    }
                    #endif
                }
                .task(id: datasetKey) {
                    availableGases = DiveListFilter.availableGases(in: dives)
                    availableModes = DiveListFilter.availableModes(in: dives)
                    filter = filter.pruned(gases: availableGases, modes: availableModes)
                }
                // 只有勾了組織負荷條件才判定；資料變動 ⇒ 舊工作取消、依快取鍵只重算受影響的紀錄。
                .task(id: JudgeTaskKey(dataset: datasetKey, needed: filter.needsTissueJudgement)) {
                    guard filter.needsTissueJudgement else { return }
                    await judge.update(sortedAscending: Array(dives.reversed()))
                }
            }
        }
    }
}

#if os(iOS)
/// 搜尋收合時完全不掛 `.searchable`，展開時才掛（標題下方出現搜尋列並聚焦）。
private struct CollapsibleSearch: ViewModifier {
    let isShown: Bool
    @Binding var text: String
    @Binding var isPresented: Bool
    let prompt: String

    func body(content: Content) -> some View {
        if isShown {
            content.searchable(
                text: $text,
                isPresented: $isPresented,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text(verbatim: prompt)
            )
        } else {
            content
        }
    }
}
#endif

// MARK: - 統計 Header

struct StatsHeaderView: View {
    let dives: [DiveLog]

    // v1.2 #4 遺漏的欄位：deepestDive 原本寫死 "%.1fm"，英制模式下數字/單位都沒換算。
    @AppStorage(UnitSystem.storageKey) private var unitSystem = UnitSystem.metric
    // 2026-09-12：數字的小數點寫法要跟著 **App 內** 語言切換走（不是系統語言）。
    @Environment(AppLanguageManager.self) private var languageManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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

    // WCAG 1.4.10 Reflow：accessibility 級 Dynamic Type 下 3 欄硬擠一列會視覺重疊
    // （2026-07-26 模擬器 AX5 實測抓到，同款問題見 DiveLogDetailView/DiveSiteSheetView）。
    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    StatCell(value: "\(totalDives)", label: "Dives", icon: "figure.pool.swim")
                    Divider()
                    StatCell(value: totalTimeText, label: "Total Time", icon: "timer")
                    Divider()
                    StatCell(value: unitSystem.formatDepth(deepestDive, locale: languageManager.locale), label: "Deepest", icon: "arrow.down.to.line")
                }
            } else {
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
                        value: unitSystem.formatDepth(deepestDive, locale: languageManager.locale),
                        label: "Deepest",
                        icon: "arrow.down.to.line"
                    )
                }
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}

struct StatCell: View {
    @Environment(AppLanguageManager.self) private var languageManager
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
                .shrinkOnlyIfNeeded(minimumScale: 0.7) // v1.4 C：原 .minimumScaleFactor(0.7)

            Text(verbatim: languageManager.localized(label))
                .font(.caption2)
                .foregroundStyle(Color.accessibleSecondary)
                .lineLimit(1)
                .shrinkOnlyIfNeeded(minimumScale: 0.7) // v1.4 C：原 .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(languageManager.localized(label))")
    }
}

#Preview {
    NavigationStack {
        DiveLogListView()
            .navigationTitle("Dive Logbook")
    }
    .modelContainer(DiveLogDatabase.shared.modelContainer)
}
