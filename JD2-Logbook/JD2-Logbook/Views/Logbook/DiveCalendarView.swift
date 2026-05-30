// DiveCalendarView.swift — JD2-Logbook/Views/Logbook/
// Week 9 — 月曆視圖，小圓點標記有潛水的日期

import SwiftUI
import SwiftData

struct DiveCalendarView: View {
    @Query(sort: \DiveLog.dateTime, order: .reverse) var allDives: [DiveLog]
    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())
    @State private var selectedDate: Date? = Date() // 初始化為今天

    /// 年/月快速跳選 popover（iOS + macOS 共用）
    @State private var showDatePicker = false

    /// macOS 專用：點選日誌 row 時的回調（支援傳入 nil 以清空詳情欄）
    var onDiveTapped: ((DiveLog?) -> Void)? = nil

    /// 當前選取的潛水（用於日清單 row 的 focus 框，與右側詳情欄同步）
    @State private var selectedDiveID: PersistentIdentifier? = nil

    /// macOS：當日清單是否取得鍵盤焦點（讓方向鍵一進來即可用）
    @FocusState private var dayListFocused: Bool

    /// 統一選取入口：同步本地 focus 狀態與右側詳情欄
    private func selectDive(_ dive: DiveLog?) {
        selectedDiveID = dive?.persistentModelID
        onDiveTapped?(dive)
    }

    // MARK: - Month Navigation Helpers

    /// 切換月份（< > 與左右滑動共用）
    private func changeMonth(by delta: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
            selectedDate = nil
        }
        #if !os(iOS)
        selectDive(nil) // macOS：換月後清空右側詳情，保持一致
        #endif
    }

    /// popover 內：只改年份（保留月份，不關閉面板）
    private func changeDisplayedYear(by delta: Int) {
        let y = calendar.component(.year, from: displayedMonth) + delta
        let clamped = min(max(y, 1980), maxCalendarYear)
        let m = calendar.component(.month, from: displayedMonth)
        if let d = calendar.date(from: DateComponents(year: clamped, month: m, day: 1)) {
            withAnimation(.easeInOut(duration: 0.15)) { displayedMonth = d }
        }
    }

    /// popover 內：點選月份 → 跳到該年月並關閉面板
    private func jumpToMonth(_ month: Int) {
        let y = calendar.component(.year, from: displayedMonth)
        if let d = calendar.date(from: DateComponents(year: y, month: month, day: 1)) {
            withAnimation(.easeInOut(duration: 0.2)) {
                displayedMonth = d
                selectedDate = nil
            }
            #if !os(iOS)
            selectDive(nil)
            #endif
        }
        showDatePicker = false
    }

    /// 跳到今天（iOS + macOS）
    private func goToToday() {
        let today = Date()
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = calendar.startOfMonth(for: today)
            selectedDate   = today
        }
        #if !os(iOS)
        // macOS：同步右側詳情（今天有潛水則選首筆，否則清空）
        if let firstDive = divesByDay[dayKey(for: today)]?.first {
            selectDive(firstDive)
        } else {
            selectDive(nil)
        }
        #endif
    }

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    // MARK: - Computed

    /// 以「年-月-日」為 key 分組
    var divesByDay: [String: [DiveLog]] {
        Dictionary(grouping: allDives) { dive in
            dayKey(for: dive.dateTime)
        }
    }

    var selectedDives: [DiveLog] {
        guard let date = selectedDate else { return [] }
        return divesByDay[dayKey(for: date)] ?? []
    }

    #if !os(iOS)
    /// macOS：以上下方向鍵在當日清單中移動選取
    private func moveSelection(_ direction: MoveCommandDirection) {
        guard !selectedDives.isEmpty else { return }
        let current = selectedDives.firstIndex { $0.persistentModelID == selectedDiveID }
        var newIndex: Int
        switch direction {
        case .up:   newIndex = (current ?? 0) - 1
        case .down: newIndex = (current ?? -1) + 1
        default:    return
        }
        newIndex = max(0, min(selectedDives.count - 1, newIndex))
        selectDive(selectedDives[newIndex])
    }
    #endif

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 月份導航
            monthHeader

            // 星期標籤列
            weekdayHeader

            Divider()

            // 日期格子
            LazyVGrid(columns: columns, spacing: 0) {
                // 月份起點前的空格
                ForEach(0..<leadingEmptyCells, id: \.self) { _ in
                    Color.clear.frame(height: 52)
                }
                // 當月所有天
                ForEach(daysInDisplayedMonth, id: \.self) { date in
                    DayCell(
                        date: date,
                        isSelected: isSameDay(date, selectedDate),
                        isToday: isSameDay(date, Date()),
                        hasDives: divesByDay[dayKey(for: date)] != nil
                    )
                    .onTapGesture {
                        let newDate: Date? = isSameDay(date, selectedDate) ? nil : date
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedDate = newDate
                        }
                        // macOS：點選日期時，自動同步右側詳情欄（支援清空）
                        #if !os(iOS)
                        if let d = newDate {
                            if let firstDive = divesByDay[dayKey(for: d)]?.first {
                                selectDive(firstDive) // 有潛水，選取首筆
                            } else {
                                selectDive(nil)       // 無潛水，清空右側詳情
                            }
                        } else {
                            selectDive(nil)           // 取消選取日期，清空右側詳情
                        }
                        #endif
                    }
                }
            }
            .padding(.horizontal, 4)
            // 左右滑動切換月份（左滑 → 下個月，右滑 → 上個月）
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        if value.translation.width < -50 {
                            changeMonth(by: 1)
                        } else if value.translation.width > 50 {
                            changeMonth(by: -1)
                        }
                    }
            )

            Divider()
                .padding(.top, 4)

            // 選中日的潛水清單（iOS 於此顯示；macOS 同時顯示，點選可同步右側詳情欄）
            selectedDaySection
        }
        // 釘到頂部，避免月曆在高欄位中被垂直置中而「浮動」於中央
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - 年月標題 Label（雙平台共用）

    private var monthTitleLabel: some View {
        HStack(spacing: 4) {
            Text(displayedMonth, format: .dateTime.year().month(.wide))
                .font(.headline)
                .foregroundStyle(.tint)   // 藍色 tint 暗示可點擊
                .lineLimit(1)
                .fixedSize()              // 不折斷換行（解決窄視窗「2026年/5月」斷行）
            Image(systemName: "chevron.up.chevron.down") // 原生上下箭頭，提示可下拉
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 年 stepper + 12 月網格 popover（iOS + macOS 共用）

    /// 各語系「短月份」名稱（Jan/Feb… 或 1月/2月…）
    private static let monthShortSymbols: [String] = {
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        return fmt.shortMonthSymbols
    }()

    private var yearMonthGridPicker: some View {
        let currentYear  = calendar.component(.year,  from: displayedMonth)
        let currentMonth = calendar.component(.month, from: displayedMonth)
        return VStack(spacing: 14) {
            // ── 年份 stepper（‹ 2026 ›）────────────────────
            HStack {
                Button { changeDisplayedYear(by: -1) } label: {
                    Image(systemName: "chevron.left").frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(currentYear <= 1980)
                .accessibilityLabel(String(localized: "Previous year"))

                Spacer()
                Text(verbatim: "\(currentYear)")
                    .font(.headline.monospacedDigit())
                Spacer()

                Button { changeDisplayedYear(by: 1) } label: {
                    Image(systemName: "chevron.right").frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(currentYear >= maxCalendarYear)
                .accessibilityLabel(String(localized: "Next year"))
            }

            // ── 12 個月網格（3×4），當前月份高亮 ──────────────
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(1...12, id: \.self) { month in
                    Button { jumpToMonth(month) } label: {
                        Text(Self.monthShortSymbols[month - 1])
                            .font(.callout.weight(month == currentMonth ? .semibold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(month == currentMonth ? Color.accentColor : Color.clear)
                            )
                            .foregroundStyle(month == currentMonth ? Color.white : Color.primary)
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    // MARK: - Year Range Helper

    /// 年份上限（今年 + 2）
    private var maxCalendarYear: Int {
        Calendar.current.component(.year, from: Date()) + 2
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        VStack(spacing: 0) {
            // ── < 月份年份 > 導航列（兩平台共用）──────────────
            HStack {
                Button { changeMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Previous month")

                Spacer()

                // 中央：整合年月標題（點擊彈出年 stepper + 月網格 popover）+ Today 按鈕
                HStack(spacing: 8) {
                    Button { showDatePicker = true } label: { monthTitleLabel }
                    #if !os(iOS)
                    .buttonStyle(.plain)
                    #endif
                    .accessibilityLabel(String(localized: "Select year and month"))
                    .popover(isPresented: $showDatePicker) {
                        yearMonthGridPicker
                            .presentationCompactAdaptation(.popover)
                    }

                    // Today 按鈕（iOS + macOS）
                    Button { goToToday() } label: {
                        Image(systemName: "calendar.badge.clock")
                            .font(.subheadline)
                    }
                    #if !os(iOS)
                    .buttonStyle(.borderless)
                    .help(String(localized: "Jump to Today"))
                    #endif
                    .accessibilityLabel(String(localized: "Jump to Today"))
                }

                Spacer()

                Button { changeMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Next month")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(localizedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Selected Day Section

    private var selectedDaySection: some View {
        Group {
            if let date = selectedDate {
                VStack(alignment: .leading, spacing: 0) {
                    // 日期標題
                    Text(date, format: .dateTime.year().month(.abbreviated).day())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                    if selectedDives.isEmpty {
                        // 無潛水
                        VStack(spacing: 6) {
                            Image(systemName: "water.waves.slash")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                            Text("No dives on this date.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        // 當日潛水列表
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(selectedDives) { dive in
                                    #if os(iOS)
                                    NavigationLink(value: dive) {
                                        DiveRowView(dive: dive,
                                                    isSelected: selectedDiveID == dive.persistentModelID)
                                            .padding(.horizontal, 16)
                                    }
                                    .buttonStyle(.plain)
                                    #else
                                    Button {
                                        selectDive(dive)
                                    } label: {
                                        DiveRowView(dive: dive,
                                                    isSelected: selectedDiveID == dive.persistentModelID)
                                            .padding(.horizontal, 16)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    #endif
                                }
                            }
                            .padding(.bottom, 12)
                        }
                        #if !os(iOS)
                        // macOS：可聚焦 + 上下方向鍵切換選取
                        .focusable()
                        .focused($dayListFocused)
                        .focusEffectDisabled()          // 移除整塊外圍 focus ring
                        .onMoveCommand { direction in
                            moveSelection(direction)
                        }
                        // 進入清單時自動取得鍵盤焦點，方向鍵立即可用
                        .onAppear { dayListFocused = true }
                        .onChange(of: selectedDate) { _, _ in dayListFocused = true }
                        #endif
                    }
                }
            } else {
                // 未選擇日期
                VStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("Select a date to see dives.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
    }

    // MARK: - Calendar Helpers

    private var daysInDisplayedMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: displayedMonth)
        }
    }

    /// 月份第一天前需要留空的格數（以 Calendar.current.firstWeekday 對齊）
    private var leadingEmptyCells: Int {
        let firstWeekday = calendar.firstWeekday          // 1=Sun, 2=Mon …
        let monthWeekday = calendar.component(.weekday, from: displayedMonth)
        return (monthWeekday - firstWeekday + 7) % 7
    }

    /// 本地化星期縮寫（按 firstWeekday 旋轉）
    private var localizedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    private func dayKey(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.year!)-\(c.month!)-\(c.day!)"
    }

    private func isSameDay(_ a: Date, _ b: Date?) -> Bool {
        guard let b = b else { return false }
        return calendar.isDate(a, inSameDayAs: b)
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasDives: Bool

    private var dayNumber: String {
        Calendar.current.component(.day, from: date).description
    }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                // 選中背景
                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 34, height: 34)
                } else if isToday {
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 1.5)
                        .frame(width: 34, height: 34)
                }

                Text(dayNumber)
                    .font(.callout.weight(isToday || isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(width: 34, height: 34)

            // 潛水圓點
            Circle()
                .fill(isSelected ? Color.white.opacity(0.9) : Color.accentColor)
                .frame(width: 5, height: 5)
                .opacity(hasDives ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .contentShape(Rectangle())
        .accessibilityLabel(
            hasDives
                ? "\(date.formatted(.dateTime.day().month())): has dives"
                : date.formatted(.dateTime.day().month())
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Calendar Extension

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}

#Preview {
    NavigationStack {
        DiveCalendarView()
            .navigationTitle("Dive Logbook")
    }
    .modelContainer(DiveLogDatabase.shared.modelContainer)
}
