// DiveLogEditSheet.swift — JD2-Logbook/Views/Logbook/
// Week 11 — 新增 & 編輯潛水日誌共用 Sheet

import SwiftUI
import SwiftData

// MARK: - 編輯模式

enum DiveEditMode {
    case new
    case edit(DiveLog)
}

// MARK: - Sheet

struct DiveLogEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: DiveEditMode

    // MARK: Form State
    @State private var dateTime: Date
    @State private var location: String
    @State private var maxDepth: Double
    @State private var durationMinutes: Int     // 儲存為整數分鐘（精度足夠手動輸入）
    @State private var waterTemperature: Double
    @State private var environmentType: String
    @State private var notes: String
    @State private var buddy: String

    // Date helpers (iOS year/month dropdowns)
    @State private var calendarYear:  Int
    @State private var calendarMonth: Int

    // Gas mix
    private enum GasMixPickerType: String, CaseIterable, Identifiable {
        case air    = "Air"
        case nitrox = "Nitrox"
        var id: String { rawValue }
    }
    @State private var gasMixType: GasMixPickerType
    @State private var nitroxO2Percent: Double  // 22–40

    // MARK: Keyboard Focus (Tab / Shift+Tab 導覽)
    private enum Field: Hashable {
        case location, maxDepth, waterTemp, buddy, notes
    }
    @FocusState private var focusedField: Field?

    // MARK: - Init

    init(mode: DiveEditMode) {
        self.mode = mode

        switch mode {
        case .new:
            let now = Date()
            let cal = Calendar.current
            _dateTime           = State(initialValue: now)
            _calendarYear       = State(initialValue: cal.component(.year,  from: now))
            _calendarMonth      = State(initialValue: cal.component(.month, from: now))
            _location           = State(initialValue: "")
            _maxDepth           = State(initialValue: 18.0)
            _durationMinutes    = State(initialValue: 45)
            _waterTemperature   = State(initialValue: 28.0)
            _environmentType    = State(initialValue: "seawater")
            _notes              = State(initialValue: "")
            _buddy              = State(initialValue: "")
            _gasMixType         = State(initialValue: .air)
            _nitroxO2Percent    = State(initialValue: 32.0)

        case .edit(let dive):
            let cal = Calendar.current
            _dateTime           = State(initialValue: dive.dateTime)
            _calendarYear       = State(initialValue: cal.component(.year,  from: dive.dateTime))
            _calendarMonth      = State(initialValue: cal.component(.month, from: dive.dateTime))
            _location           = State(initialValue: dive.location)
            _maxDepth           = State(initialValue: dive.maxDepth)
            _durationMinutes    = State(initialValue: max(1, dive.diveTimeSeconds / 60))
            _waterTemperature   = State(initialValue: dive.waterTemperature)
            _environmentType    = State(initialValue: dive.environmentType)
            _notes              = State(initialValue: dive.notes)
            _buddy              = State(initialValue: dive.buddy ?? "")

            // 解析已儲存的 gas mix JSON
            if let data = dive.gasMixJSON.data(using: .utf8),
               let gas  = try? JSONDecoder().decode(GasMix.self, from: data) {
                switch gas {
                case .air:
                    _gasMixType      = State(initialValue: .air)
                    _nitroxO2Percent = State(initialValue: 32.0)
                case .nitrox(let fO2):
                    _gasMixType      = State(initialValue: .nitrox)
                    _nitroxO2Percent = State(initialValue: (fO2 * 100).rounded())
                case .trimix:
                    // Trimix 目前不支援手動編輯，降級為 Air
                    _gasMixType      = State(initialValue: .air)
                    _nitroxO2Percent = State(initialValue: 32.0)
                }
            } else {
                _gasMixType      = State(initialValue: .air)
                _nitroxO2Percent = State(initialValue: 32.0)
            }
        }
    }

    // MARK: - Date Helpers (iOS)

    /// 年份上限（今年 + 2）
    private var maxCalendarYear: Int {
        Calendar.current.component(.year, from: Date()) + 2
    }

    /// 各語系月份名稱（DateFormatter 依裝置語系自動本地化）
    private static let monthSymbols: [String] = {
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        return fmt.monthSymbols
    }()

    /// 年月下拉變更後，把 dateTime 移到同一天（若新月沒有那一天則取末日）
    private func syncDateToYearMonth() {
        let cal    = Calendar.current
        let day    = cal.component(.day,    from: dateTime)
        let hour   = cal.component(.hour,   from: dateTime)
        let minute = cal.component(.minute, from: dateTime)

        // 計算新月天數，避免「2月31日」之類的無效日期
        let firstOfMonth = cal.date(from: DateComponents(year: calendarYear, month: calendarMonth, day: 1)) ?? dateTime
        let daysInMonth  = cal.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        let clampedDay   = Swift.min(day, daysInMonth)

        if let newDate = cal.date(from: DateComponents(
            year: calendarYear, month: calendarMonth,
            day: clampedDay, hour: hour, minute: minute
        )) {
            dateTime = newDate
        }
    }

    // MARK: - Validation

    private var isSaveEnabled: Bool {
        maxDepth > 0 && durationMinutes > 0
    }

    private var titleText: String {
        switch mode {
        case .new:  return String(localized: "New Dive")
        case .edit: return String(localized: "Edit Dive")
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // ── 日期時間 ────────────────────────────────
                // Year / Month Picker 在 iOS + macOS 皆顯示（快速跳年月）
                Section {
                    // ── 年份（iOS + macOS 共用）──────────────
                    Picker(String(localized: "Year"), selection: $calendarYear) {
                        ForEach(Array(1980...maxCalendarYear), id: \.self) { year in
                            Text(verbatim: "\(year)").tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: calendarYear) { _, _ in syncDateToYearMonth() }

                    // ── 月份（iOS + macOS 共用）──────────────
                    Picker(String(localized: "Month"), selection: $calendarMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text(Self.monthSymbols[month - 1]).tag(month)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: calendarMonth) { _, _ in syncDateToYearMonth() }

                    #if os(iOS)
                    // ── iOS：graphical 月曆選日 ───────────────
                    DatePicker(
                        "",
                        selection: $dateTime,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .onChange(of: dateTime) { _, newDate in
                        let cal = Calendar.current
                        let y = cal.component(.year,  from: newDate)
                        let m = cal.component(.month, from: newDate)
                        if y != calendarYear  { calendarYear  = y }
                        if m != calendarMonth { calendarMonth = m }
                    }

                    // ── iOS 時間列 ────────────────────────────
                    DatePicker(
                        String(localized: "Time"),
                        selection: $dateTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    #else
                    // ── macOS：compact 月曆 + 時間（點擊展開 popover）
                    // Year/Month Picker 快速跳年月；compact 負責確定精確日期與時間
                    DatePicker(
                        String(localized: "Date & Time"),
                        selection: $dateTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .onChange(of: dateTime) { _, newDate in
                        let cal = Calendar.current
                        let y = cal.component(.year,  from: newDate)
                        let m = cal.component(.month, from: newDate)
                        if y != calendarYear  { calendarYear  = y }
                        if m != calendarMonth { calendarMonth = m }
                    }
                    #endif
                }

                // ── 地點 ─────────────────────────────────
                Section(header: Text("Location")) {
                    TextField(String(localized: "Dive Site"), text: $location)
                        .textContentType(.addressCity)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .location)
                }

                // ── 潛水數據 ─────────────────────────────
                Section(header: Text("Dive Data")) {
                    // 最大深度
                    HStack {
                        Text("Max Depth")
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("0.0", value: $maxDepth,
                                  format: .number.precision(.fractionLength(1)))
                            .labelsHidden() // 隱藏 TextField title，移除 macOS Form 多出的「0.0」
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            .focused($focusedField, equals: .maxDepth)
                        Text("m")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        String(format: String(localized: "Max Depth: %.1f metres"), maxDepth)
                    )

                    // 時長（分鐘 Stepper）
                    Stepper(value: $durationMinutes, in: 1...999) {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text("\(durationMinutes) min")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel(
                        String(format: String(localized: "Duration: %d minutes"), durationMinutes)
                    )

                    // 水溫
                    HStack {
                        Text("Water Temp")
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("0.0", value: $waterTemperature,
                                  format: .number.precision(.fractionLength(1)))
                            .labelsHidden() // 隱藏 TextField title，移除 macOS Form 多出的「0.0」
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            .focused($focusedField, equals: .waterTemp)
                        Text("°C")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        String(format: String(localized: "Water Temperature: %.1f degrees Celsius"),
                               waterTemperature)
                    )
                }

                // ── 氣體混合 ─────────────────────────────
                Section(header: Text("Gas Mix")) {
                    Picker(String(localized: "Gas"), selection: $gasMixType) {
                        ForEach(GasMixPickerType.allCases) { type in
                            Text(LocalizedStringKey(type.rawValue)).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    if gasMixType == .nitrox {
                        HStack(spacing: 12) {
                            Text("O₂")
                                .foregroundStyle(.secondary)
                            Slider(
                                value: $nitroxO2Percent,
                                in: 22...40,
                                step: 1
                            ) {
                                Text("O₂ %")
                            }
                            Text("\(Int(nitroxO2Percent))%")
                                .monospacedDigit()
                                .frame(width: 44, alignment: .trailing)
                                .foregroundStyle(.primary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            String(format: String(localized: "Nitrox O2: %d percent"),
                                   Int(nitroxO2Percent))
                        )
                    }
                }

                // ── 環境類型 ─────────────────────────────
                Section(header: Text("Environment")) {
                    Picker(String(localized: "Water Type"), selection: $environmentType) {
                        Text("Seawater").tag("seawater")
                        Text("Freshwater").tag("freshwater")
                        Text("Altitude").tag("altitude")
                    }
                }

                // ── 潛伴 ─────────────────────────────────
                Section(header: Text("Buddy")) {
                    TextField(String(localized: "Buddy Name (optional)"), text: $buddy)
                        .textContentType(.name)
                        .focused($focusedField, equals: .buddy)
                }

                // ── 備註 ─────────────────────────────────
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80, maxHeight: 200)
                        .accessibilityLabel(String(localized: "Notes"))
                        .focused($focusedField, equals: .notes)
                }
            }
            .navigationTitle(titleText)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #else
            .formStyle(.grouped) // macOS：原生分組表單，修正 label/控制項間距撐爆問題
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) { save() }
                        .disabled(!isSaveEnabled)
                        .fontWeight(.semibold)
                }
            }
        }
        #if !os(iOS)
        // macOS：約束 sheet 尺寸，避免 Form 被撐到整個視窗寬度導致版面崩潰
        .frame(minWidth: 460, idealWidth: 520, maxWidth: 560,
               minHeight: 560, idealHeight: 660)
        #endif
    }

    // MARK: - Save

    private func save() {
        let totalSeconds = durationMinutes * 60
        let gasMixJSON   = buildGasMixJSON()

        switch mode {
        case .new:
            let dive = DiveLog(
                dateTime:        dateTime,
                location:        location.trimmingCharacters(in: .whitespaces),
                maxDepth:        maxDepth,
                diveTimeSeconds: totalSeconds,
                gasMixJSON:      gasMixJSON,
                waterTemperature: waterTemperature
            )
            dive.environmentType = environmentType
            dive.notes  = notes.trimmingCharacters(in: .whitespaces)
            dive.buddy  = buddy.trimmingCharacters(in: .whitespaces).nilIfEmpty
            dive.sourceFormat = "manual"
            modelContext.insert(dive)

        case .edit(let dive):
            dive.dateTime         = dateTime
            dive.location         = location.trimmingCharacters(in: .whitespaces)
            dive.maxDepth         = maxDepth
            dive.diveTimeSeconds  = totalSeconds
            dive.gasMixJSON       = gasMixJSON
            dive.waterTemperature = waterTemperature
            dive.environmentType  = environmentType
            dive.notes  = notes.trimmingCharacters(in: .whitespaces)
            dive.buddy  = buddy.trimmingCharacters(in: .whitespaces).nilIfEmpty
            dive.updatedAt = Date()
        }

        dismiss()
    }

    private func buildGasMixJSON() -> String {
        switch gasMixType {
        case .air:
            return "\"air\""
        case .nitrox:
            let fO2 = nitroxO2Percent / 100.0
            return "{\"nitrox\":{\"fO2\":\(String(format: "%.4g", fO2))}}"
        }
    }
}

// MARK: - Helpers

private extension String {
    /// 空字串轉 nil（便於寫回 buddy 可選欄位）
    var nilIfEmpty: String? {
        self.isEmpty ? nil : self
    }
}

// MARK: - Preview

#Preview("New Dive") {
    DiveLogEditSheet(mode: .new)
        .modelContainer(DiveLogDatabase.shared.modelContainer)
}

#Preview("Edit Dive") {
    DiveLogEditSheet(mode: .edit(DiveLog(
        dateTime: Date(),
        location: "Small Island, Komodo",
        maxDepth: 52.3,
        diveTimeSeconds: 5640,
        gasMixJSON: "\"air\"",
        waterTemperature: 28.0
    )))
    .modelContainer(DiveLogDatabase.shared.modelContainer)
}
