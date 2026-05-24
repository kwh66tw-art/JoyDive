// DiveCalendarView.swift — JD2-Logbook/Views/Logbook/
// Week 9 — 月曆視圖，小圓點標記有潛水的日期

import SwiftUI
import SwiftData

struct DiveCalendarView: View {
    @Query(sort: \DiveLog.dateTime, order: .reverse) var allDives: [DiveLog]
    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())
    @State private var selectedDate: Date? = nil

    /// macOS 專用：點選日誌 row 時的回調（更新右側詳情欄）
    var onDiveTapped: ((DiveLog) -> Void)? = nil

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
                        // macOS：點選有潛水的日期時，自動同步右側詳情欄
                        #if !os(iOS)
                        if let d = newDate,
                           let firstDive = divesByDay[dayKey(for: d)]?.first {
                            onDiveTapped?(firstDive)
                        }
                        #endif
                    }
                }
            }
            .padding(.horizontal, 4)

            Divider()
                .padding(.top, 4)

            // 選中日的潛水清單
            selectedDaySection
        }
    }

    // MARK: - Year / Month Quick-Jump Helpers（macOS）

    private var maxCalendarYear: Int {
        Calendar.current.component(.year, from: Date()) + 2
    }

    private static let monthSymbols: [String] = {
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        return fmt.monthSymbols
    }()

    /// year Picker → 更新 displayedMonth
    private var yearBinding: Binding<Int> {
        Binding(
            get: { calendar.component(.year, from: displayedMonth) },
            set: { year in
                let month = calendar.component(.month, from: displayedMonth)
                if let newDate = calendar.date(
                    from: DateComponents(year: year, month: month, day: 1)
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayedMonth = newDate
                        selectedDate   = nil
                    }
                }
            }
        )
    }

    /// month Picker → 更新 displayedMonth
    private var monthBinding: Binding<Int> {
        Binding(
            get: { calendar.component(.month, from: displayedMonth) },
            set: { month in
                let year = calendar.component(.year, from: displayedMonth)
                if let newDate = calendar.date(
                    from: DateComponents(year: year, month: month, day: 1)
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayedMonth = newDate
                        selectedDate   = nil
                    }
                }
            }
        )
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        VStack(spacing: 0) {
            #if !os(iOS)
            // macOS：年/月快速跳選（iOS 直接用 < > 逐月切換即可）
            HStack(spacing: 8) {
                Picker(String(localized: "Year"), selection: yearBinding) {
                    ForEach(Array(1980...maxCalendarYear), id: \.self) { year in
                        Text(verbatim: "\(year)").tag(year)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 110)

                Picker(String(localized: "Month"), selection: monthBinding) {
                    ForEach(1...12, id: \.self) { month in
                        Text(Self.monthSymbols[month - 1]).tag(month)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 150)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
            #endif

            // ── < 月份年份 > 導航列（兩平台共用）──────────────
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayedMonth = calendar.date(
                            byAdding: .month, value: -1, to: displayedMonth
                        ) ?? displayedMonth
                        selectedDate = nil
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Previous month")

                Spacer()

                Text(displayedMonth, format: .dateTime.year().month(.wide))
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayedMonth = calendar.date(
                            byAdding: .month, value: 1, to: displayedMonth
                        ) ?? displayedMonth
                        selectedDate = nil
                    }
                } label: {
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
                                        DiveRowView(dive: dive)
                                            .padding(.horizontal, 16)
                                    }
                                    .buttonStyle(.plain)
                                    #else
                                    Button {
                                        onDiveTapped?(dive)
                                    } label: {
                                        DiveRowView(dive: dive)
                                            .padding(.horizontal, 16)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    #endif
                                }
                            }
                            .padding(.bottom, 12)
                        }
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
