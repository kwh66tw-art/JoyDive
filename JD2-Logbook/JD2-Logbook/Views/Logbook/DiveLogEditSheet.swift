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

    // MARK: - Environment Details
    @State private var weather: String
    @State private var airTemperature: Double
    @State private var surfaceCondition: String
    @State private var waterflow: String
    @State private var visibility: Double

    // MARK: - Time Details
    @State private var entryTime: Date       // 使用者可填入的入水時間（時:分）
    @State private var exitTime: Date?       // 自動計算的出水時間（只讀）

    // MARK: - Equipment Details
    @State private var wetsuitThickness: String
    @State private var weightTotal: Double
    @State private var cylinderMaterial: String
    @State private var cylinderSize: String
    @State private var cylinderStartPressure: Double
    @State private var cylinderEndPressure: Double?

    // MARK: Keyboard Focus (Tab / Shift+Tab 導覽)
    private enum Field: Hashable {
        case location, entryTime, durationMinutes, maxDepth, waterTemp, notes
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
            _gasMixType         = State(initialValue: .air)
            _nitroxO2Percent    = State(initialValue: 32.0)

            // Environment Details
            _weather            = State(initialValue: "clear")
            _airTemperature     = State(initialValue: 25.0)
            _surfaceCondition   = State(initialValue: "calm")
            _waterflow          = State(initialValue: "none")
            _visibility         = State(initialValue: 12.0)

            // Time Details
            _entryTime          = State(initialValue: now)
            _exitTime           = State(initialValue: nil)

            // Equipment Details
            _wetsuitThickness   = State(initialValue: "3")
            _weightTotal        = State(initialValue: 0)
            _cylinderMaterial   = State(initialValue: "aluminum")
            _cylinderSize       = State(initialValue: "S80(12L)")
            _cylinderStartPressure  = State(initialValue: 200)
            _cylinderEndPressure    = State(initialValue: 50)

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

            // Environment Details
            _weather            = State(initialValue: dive.weather)
            _airTemperature     = State(initialValue: dive.airTemperature)
            _surfaceCondition   = State(initialValue: dive.surfaceCondition)
            _waterflow          = State(initialValue: dive.waterflow)
            _visibility         = State(initialValue: dive.visibility)

            // Time Details
            _entryTime          = State(initialValue: dive.entryTime ?? dive.dateTime)
            _exitTime           = State(initialValue: dive.exitTime)

            // Equipment Details
            _wetsuitThickness   = State(initialValue: dive.wetsuitThickness)
            _weightTotal        = State(initialValue: dive.weightTotal)
            _cylinderMaterial   = State(initialValue: dive.cylinderMaterial)
            _cylinderSize       = State(initialValue: dive.cylinderSize)
            _cylinderStartPressure  = State(initialValue: dive.cylinderStartPressure)
            _cylinderEndPressure    = State(initialValue: dive.cylinderEndPressure ?? 50)
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

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
                // ═════════════════════════════════════════════════════════
                // BLOCK 1: 基本資訊 (Basic Info with 12-grid month selector)
                // ═════════════════════════════════════════════════════════
                Section(header: Text("Basic Info")) {
                    // ── 年份（iOS + macOS 共用）──────────────
                    Picker(String(localized: "Year"), selection: $calendarYear) {
                        ForEach(Array(1980...maxCalendarYear), id: \.self) { year in
                            Text(verbatim: "\(year)").tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: calendarYear) { _, _ in syncDateToYearMonth() }

                    // ── 12宮格月份選擇器（iOS + macOS 共用）──────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "Month"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(1...12, id: \.self) { month in
                                Button(action: {
                                    calendarMonth = month
                                    syncDateToYearMonth()
                                }) {
                                    Text(Self.monthSymbols[month - 1])
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(calendarMonth == month ? Color.blue : Color(.systemGray5))
                                        )
                                        .foregroundStyle(calendarMonth == month ? .white : .primary)
                                }
                            }
                        }
                        .padding(.horizontal, -8)
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))

                    // ── 潛水地點 ─────────────────────────────────
                    TextField(String(localized: "Dive Site"), text: $location)
                        .textContentType(.addressCity)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .location)
                }

                // ═════════════════════════════════════════════════════════
                // BLOCK 2: 潛水數據與時間 (Dive Data & Time)
                // ═════════════════════════════════════════════════════════
                Section(header: Text("Dive Data & Time")) {
                    // 潛水時間（分鐘）
                    HStack {
                        Text(String(localized: "Dive Time"))
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("45", value: $durationMinutes,
                                  format: .number)
                            .labelsHidden()
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            .focused($focusedField, equals: .durationMinutes)
                        Text("min")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        String(format: String(localized: "Duration: %d minutes"), durationMinutes)
                    )

                    // 入水時間（可編輯）
                    DatePicker(
                        String(localized: "Entry Time"),
                        selection: $entryTime,
                        displayedComponents: [.hourAndMinute]
                    )

                    // 出水時間（自動計算，唯讀）
                    HStack {
                        Text(String(localized: "Exit Time"))
                            .foregroundStyle(.primary)
                        Spacer()
                        if let exit = Calendar.current.date(
                            byAdding: .minute,
                            value: durationMinutes,
                            to: entryTime
                        ) {
                            Text(formatTime(exit))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        } else {
                            Text("—")
                                .foregroundStyle(.tertiary)
                        }
                    }

                    // 最大深度
                    HStack {
                        Text("Max Depth")
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("0.0", value: $maxDepth,
                                  format: .number.precision(.fractionLength(1)))
                            .labelsHidden()
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

                    // 水溫
                    HStack {
                        Text("Water Temp")
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("0.0", value: $waterTemperature,
                                  format: .number.precision(.fractionLength(1)))
                            .labelsHidden()
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

                // ── 氣體混合（Gas Mix 配置在此）─────────────
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

                // ═════════════════════════════════════════════════════════
                // BLOCK 3: 環境 (Environment)
                // ═════════════════════════════════════════════════════════
                Section(header: Text("Environment")) {
                    Picker(String(localized: "Water Type"), selection: $environmentType) {
                        Text("Seawater").tag("seawater")
                        Text("Freshwater").tag("freshwater")
                        Text("Altitude").tag("altitude")
                    }

                    // 天氣
                    Picker(String(localized: "Weather"), selection: $weather) {
                        Text(LocalizedStringKey("Sunny")).tag("sunny")
                        Text(LocalizedStringKey("Cloudy")).tag("cloudy")
                        Text(LocalizedStringKey("Rainy")).tag("rainy")
                        Text(LocalizedStringKey("Clear")).tag("clear")
                    }

                    // 氣溫
                    HStack {
                        Text(String(localized: "Air Temperature"))
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("25", value: $airTemperature,
                                  format: .number.precision(.fractionLength(1)))
                            .labelsHidden()
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("°C")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        String(format: String(localized: "Air Temperature: %.1f degrees Celsius"),
                               airTemperature)
                    )

                    // 水面狀況
                    Picker(String(localized: "Surface Condition"), selection: $surfaceCondition) {
                        Text(LocalizedStringKey("Calm")).tag("calm")
                        Text(LocalizedStringKey("Slight")).tag("slight")
                        Text(LocalizedStringKey("Moderate")).tag("moderate")
                        Text(LocalizedStringKey("Rough")).tag("rough")
                    }

                    // 水流
                    Picker(String(localized: "Water Flow"), selection: $waterflow) {
                        Text(LocalizedStringKey("None")).tag("none")
                        Text(LocalizedStringKey("Slight")).tag("slight")
                        Text(LocalizedStringKey("Moderate")).tag("moderate")
                        Text(LocalizedStringKey("Strong")).tag("strong")
                    }

                    // 能見度
                    HStack {
                        Text(String(localized: "Visibility"))
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("12", value: $visibility,
                                  format: .number.precision(.fractionLength(1)))
                            .labelsHidden()
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("m")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        String(format: String(localized: "Visibility: %.1f metres"), visibility)
                    )
                }

                // ═════════════════════════════════════════════════════════
                // BLOCK 4: 潛水裝備 (Equipment)
                // ═════════════════════════════════════════════════════════
                Section(header: Text("Equipment")) {
                    // 防寒衣厚度（只輸入數字，mm 單位固定）
                    HStack {
                        Text(String(localized: "Wetsuit"))
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("", text: $wetsuitThickness)
                            .labelsHidden()
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                            // 確保只儲存數字（移除任何非數字字符）
                            .onChange(of: wetsuitThickness) { _, newValue in
                                wetsuitThickness = newValue.filter { $0.isNumber || $0 == "." }
                            }
                        Text("mm")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "Wetsuit"))

                    // 配重總重量
                    HStack {
                        Text(String(localized: "Weight"))
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("0", value: $weightTotal,
                                  format: .number.precision(.fractionLength(1)))
                            .labelsHidden()
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        String(format: String(localized: "Weight: %.1f kilograms"), weightTotal)
                    )

                    // 氣瓶材質
                    Picker(String(localized: "Cylinder Material"), selection: $cylinderMaterial) {
                        Text(LocalizedStringKey("Aluminum")).tag("aluminum")
                        Text(LocalizedStringKey("Steel")).tag("steel")
                    }

                    // 氣瓶規格（預定義選項）
                    Picker(String(localized: "Cylinder Size"), selection: $cylinderSize) {
                        Text("S80 (12L)").tag("S80(12L)")
                        Text("S63 (8.6L)").tag("S63(8.6L)")
                        Text("AL100 (14L)").tag("AL100(14L)")
                        Text("12L (Steel)").tag("12L(Steel)")
                        Text("10L (Steel)").tag("10L(Steel)")
                    }

                    // 氣瓶起始壓力（預設 200 bar）
                    HStack {
                        Text(String(localized: "Start Pressure"))
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("200", value: $cylinderStartPressure,
                                  format: .number.precision(.fractionLength(0)))
                            .labelsHidden()
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("bar")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        String(format: String(localized: "Start Pressure: %.0f bar"), cylinderStartPressure)
                    )

                    // 氣瓶結束壓力（預設 50 bar）
                    HStack {
                        Text(String(localized: "End Pressure"))
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("50", value: $cylinderEndPressure,
                                  format: .number.precision(.fractionLength(0)))
                            .labelsHidden()
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("bar")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        String(localized: "End Pressure")
                    )
                }

                // ═════════════════════════════════════════════════════════
                // BLOCK 5: 潛水備註 (Dive Notes)
                // ═════════════════════════════════════════════════════════
                Section(header: Text("Dive Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80, maxHeight: 200)
                        .accessibilityLabel(String(localized: "Notes"))
                        .focused($focusedField, equals: .notes)
                }
            }
            .navigationTitle(titleText)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .formStyle(.grouped) // iOS 會自動呈現 Inset-Grouped 質感；macOS 原生分組表單
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

        // 計算出水時間：基於入水時間 + 潛水時間
        let calculatedExitTime = Calendar.current.date(
            byAdding: .minute,
            value: durationMinutes,
            to: entryTime
        )

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
            dive.sourceFormat = "manual"

            // Environment Details
            dive.weather = weather
            dive.airTemperature = airTemperature
            dive.surfaceCondition = surfaceCondition
            dive.waterflow = waterflow
            dive.visibility = visibility

            // Time Details
            dive.entryTime = entryTime
            dive.exitTime = calculatedExitTime

            // Equipment Details
            dive.wetsuitThickness = wetsuitThickness
            dive.weightTotal = weightTotal
            dive.cylinderMaterial = cylinderMaterial
            dive.cylinderSize = cylinderSize
            dive.cylinderStartPressure = cylinderStartPressure
            dive.cylinderEndPressure = cylinderEndPressure

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

            // Environment Details
            dive.weather = weather
            dive.airTemperature = airTemperature
            dive.surfaceCondition = surfaceCondition
            dive.waterflow = waterflow
            dive.visibility = visibility

            // Time Details
            dive.entryTime = entryTime
            dive.exitTime = calculatedExitTime

            // Equipment Details
            dive.wetsuitThickness = wetsuitThickness
            dive.weightTotal = weightTotal
            dive.cylinderMaterial = cylinderMaterial
            dive.cylinderSize = cylinderSize
            dive.cylinderStartPressure = cylinderStartPressure
            dive.cylinderEndPressure = cylinderEndPressure

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
