// DiveLogEditSheet.swift — JD2-Logbook/Views/Logbook/
// Week 11 — 新增 & 編輯潛水日誌共用 Sheet

import SwiftUI
import SwiftData
import DiveKit

// MARK: - 編輯模式

enum DiveEditMode {
    case new
    case edit(DiveLog)
}

// MARK: - Sheet

struct DiveLogEditSheet: View {
    @Environment(AppLanguageManager.self) private var languageManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // v1.2 #4：公制／英制單位系統，@State 內部儲存值永遠是公制，
    // 這裡只負責輸入欄位的雙向換算（顯示值 ↔ 公制儲存值）。
    @AppStorage(UnitSystem.storageKey) private var unitSystem = UnitSystem.metric

    let mode: DiveEditMode

    // MARK: Form State
    @State private var location: String
    @State private var maxDepth: Double
    @State private var durationMinutes: Int     // 儲存為整數分鐘（精度足夠手動輸入）
    @State private var waterTemperature: Double
    @State private var environmentType: String
    @State private var notes: String

    // Gas mix
    private enum GasMixPickerType: String, CaseIterable, Identifiable {
        case air    = "Air"
        case nitrox = "Nitrox"
        var id: String { rawValue }
    }
    @State private var gasMixType: GasMixPickerType
    @State private var nitroxO2Percent: Double  // 22–40

    // ⚠️ Trimix 目前不支援手動編輯（picker 只有 Air/Nitrox 兩個選項），原本 save()
    // 一律用 gasMixType/nitroxO2Percent 重新組字串寫回 dive.gasMixJSON，導致只是
    // 想改地點/備註的使用者，儲存後 Trimix 氣體資料被靜默且不可逆地覆寫成 Air。
    // 記住原始 gasMixJSON 是否為 trimix，save() 時比照處理：不動這個欄位，維持原樣。
    private let originalTrimixGasMixJSON: String?

    // MARK: - Environment Details（Optional：nil = 未記錄）
    @State private var weather: String?
    @State private var airTemperature: Double?
    @State private var surfaceCondition: String?
    @State private var waterflow: String?
    @State private var visibility: Double?

    // MARK: - Time Details
    @State private var entryTime: Date       // 使用者可填入的入水時間（時:分）
    @State private var exitTime: Date?       // 自動計算的出水時間（只讀）

    // MARK: - Equipment Details
    @State private var wetsuitThickness: String
    @State private var weightTotal: Double?
    @State private var cylinderMaterial: String
    @State private var cylinderSize: String
    @State private var cylinderStartPressure: Double?
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
            _location           = State(initialValue: "")
            // maxDepth 不給預設值：0 是唯一在潛水裡真正「不可能」的深度（沒有人潛到
            // 表面等於沒下潛），沿用既有 isSaveEnabled（maxDepth > 0）擋掉未填就存檔，
            // 不會把假的英制換算數字（原本 18.0m→59.1ft）誤植成使用者沒填過的資料。
            _maxDepth           = State(initialValue: 0)
            _durationMinutes    = State(initialValue: 45)
            _waterTemperature   = State(initialValue: 28.0)
            _environmentType    = State(initialValue: "seawater")
            _notes              = State(initialValue: "")
            _gasMixType         = State(initialValue: .air)
            _nitroxO2Percent    = State(initialValue: 32.0)
            originalTrimixGasMixJSON = nil

            // Environment Details（新增潛水：nil = 使用者尚未填入）
            _weather            = State(initialValue: nil)
            _airTemperature     = State(initialValue: nil)
            _surfaceCondition   = State(initialValue: nil)
            _waterflow          = State(initialValue: nil)
            _visibility         = State(initialValue: nil)

            // Time Details
            _entryTime          = State(initialValue: now)
            _exitTime           = State(initialValue: nil)

            // Equipment Details
            _wetsuitThickness   = State(initialValue: "3")
            // weightTotal 不給預設值：0 沒辦法區分「使用者還沒填」跟「真的配重 0」
            // （例如乾式衣配重靠身體浮力調整），比照 cylinderStartPressure 同一批修正。
            _weightTotal        = State(initialValue: nil)
            _cylinderMaterial   = State(initialValue: "aluminum")
            _cylinderSize       = State(initialValue: "S80(12L)")
            // 不給預設值：200 bar／50 bar 換算成英制會出現 2,901 psi／725 psi 這種
            // 假精確度的零頭數字，讓使用者誤以為是有意義的量測值。比照 airTemperature／
            // visibility 的作法，改成 nil = 未填入，由使用者自己輸入。
            _cylinderStartPressure  = State(initialValue: nil)
            _cylinderEndPressure    = State(initialValue: nil)

        case .edit(let dive):
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
                    originalTrimixGasMixJSON = nil
                case .nitrox(let fO2):
                    _gasMixType      = State(initialValue: .nitrox)
                    _nitroxO2Percent = State(initialValue: (fO2 * 100).rounded())
                    originalTrimixGasMixJSON = nil
                case .trimix:
                    // Trimix 目前不支援手動編輯（picker 只有 Air/Nitrox），僅用 Air 當
                    // picker 顯示佔位；真正存回資料庫時 save() 會維持原始 JSON 不動，
                    // 不能把這個 .air 顯示值反寫回去。
                    _gasMixType      = State(initialValue: .air)
                    _nitroxO2Percent = State(initialValue: 32.0)
                    originalTrimixGasMixJSON = dive.gasMixJSON
                }
            } else {
                _gasMixType      = State(initialValue: .air)
                _nitroxO2Percent = State(initialValue: 32.0)
                originalTrimixGasMixJSON = nil
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
            _wetsuitThickness   = State(initialValue: dive.wetsuitThickness ?? "")
            _weightTotal        = State(initialValue: dive.weightTotal)
            _cylinderMaterial   = State(initialValue: dive.cylinderMaterial ?? "")
            _cylinderSize       = State(initialValue: dive.cylinderSize ?? "")
            _cylinderStartPressure  = State(initialValue: dive.cylinderStartPressure)
            _cylinderEndPressure    = State(initialValue: dive.cylinderEndPressure)
        }
    }

    // MARK: - Unit-aware Bindings（顯示值 ↔ 公制儲存值）

    private var maxDepthDisplay: Binding<Double> {
        Binding(
            get: { unitSystem.convertDepth(metersValue: maxDepth) },
            set: { maxDepth = unitSystem.metersValue(fromDisplay: $0) }
        )
    }

    private var waterTemperatureDisplay: Binding<Double> {
        Binding(
            get: { unitSystem.convertTemperature(celsiusValue: waterTemperature) },
            set: { waterTemperature = unitSystem.celsiusValue(fromDisplay: $0) }
        )
    }

    private var airTemperatureDisplay: Binding<Double?> {
        Binding(
            get: { airTemperature.map { unitSystem.convertTemperature(celsiusValue: $0) } },
            set: { airTemperature = $0.map { unitSystem.celsiusValue(fromDisplay: $0) } }
        )
    }

    private var visibilityDisplay: Binding<Double?> {
        Binding(
            get: { visibility.map { unitSystem.convertDepth(metersValue: $0) } },
            set: { visibility = $0.map { unitSystem.metersValue(fromDisplay: $0) } }
        )
    }

    private var weightTotalDisplay: Binding<Double?> {
        Binding(
            get: { weightTotal.map { unitSystem.convertWeight(kgValue: $0) } },
            set: { weightTotal = $0.map { unitSystem.kgValue(fromDisplay: $0) } }
        )
    }

    private var cylinderStartPressureDisplay: Binding<Double?> {
        Binding(
            get: { cylinderStartPressure.map { unitSystem.convertPressure(barValue: $0) } },
            set: { cylinderStartPressure = $0.map { unitSystem.barValue(fromDisplay: $0) } }
        )
    }

    private var cylinderEndPressureDisplay: Binding<Double?> {
        Binding(
            get: { cylinderEndPressure.map { unitSystem.convertPressure(barValue: $0) } },
            set: { cylinderEndPressure = $0.map { unitSystem.barValue(fromDisplay: $0) } }
        )
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        languageManager.numericDateTimeFormatter().string(from: date)
    }

    // MARK: - Validation

    private var isSaveEnabled: Bool {
        maxDepth > 0 && durationMinutes > 0
    }

    private var titleText: String {
        switch mode {
        case .new:  return languageManager.localized("New Dive")
        case .edit: return languageManager.localized("Edit Dive")
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // ═════════════════════════════════════════════════════════
                // BLOCK 1: 潛水數據與時間 (Dive Data & Time)
                // ═════════════════════════════════════════════════════════
                Section {
                    // 潛水時間（分鐘）
                    HStack {
                        Text(languageManager.localized("Dive Time"))
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField(String("45"), value: $durationMinutes,
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
                        String(format: languageManager.localized("Duration: %d minutes"), durationMinutes)
                    )

                    // 入水時間（可編輯，日期 + 時間）
                    // DatePicker 內部的 VoiceOver 朗讀值不吃 \.environment(\.locale)
                    // （跟 DateFormatter/Calendar 同一種病，但這次是 Apple 元件內部行為，
                    // 不是我們的程式碼），畫面顯示正確但 VoiceOver 唸英文——真機走查抓到。
                    // 用 accessibilityValue 蓋掉系統算出來的朗讀值，強制用我們自己的
                    // locale-aware formatter。
                    DatePicker(
                        languageManager.localized("Entry Time"),
                        selection: $entryTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .accessibilityValue(languageManager.numericDateTimeFormatter().string(from: entryTime))

                    // 出水時間（自動計算，唯讀）
                    HStack {
                        Text(languageManager.localized("Exit Time"))
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
                            Text(verbatim: "—")
                                .foregroundStyle(.secondary)
                        }
                    }

                    // 最大深度 —— 必填欄位，紅色星號是通用慣例，不用額外翻譯一整句話
                    // （之前用整句英文提示，語系切不過去，PM 抓到後改這個做法）。
                    HStack {
                        Text("Max Depth").foregroundStyle(.primary)
                            + Text(" *").foregroundStyle(.red)
                        Spacer()
                        TextField(String("0.0"), value: maxDepthDisplay,
                                  format: .number.precision(.fractionLength(1)))
                            .labelsHidden()
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            .focused($focusedField, equals: .maxDepth)
                            .foregroundStyle(maxDepth == 0 ? .secondary : .primary)
                        Text(unitSystem.depthSymbol)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        maxDepth == 0
                            ? "\(languageManager.localized("Max Depth")) (\(languageManager.localized("Required")))"
                            : String(format: languageManager.localized("Max Depth: %@"), unitSystem.formatDepth(maxDepth))
                    )

                    // 水溫
                    HStack {
                        Text("Water Temp")
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField(String("0.0"), value: waterTemperatureDisplay,
                                  format: .number.precision(.fractionLength(1)))
                            .labelsHidden()
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            .focused($focusedField, equals: .waterTemp)
                        Text(unitSystem.temperatureSymbol)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        String(format: languageManager.localized("Water Temperature: %@"),
                               unitSystem.formatTemperature(waterTemperature))
                    )
                } header: {
                    Text("Dive Data & Time")
                } footer: {
                    // 「儲存」按鈕在 maxDepth == 0 時會靜默停用，沒有任何視覺/VoiceOver
                    // 提示——真機 VoiceOver 走查回報「無法儲存」，其實是不知道深度必填。
                    // 用紅色星號（通用慣例，不用翻譯）+ 已 18 語言翻譯的「必填」字樣，
                    // 不要再用整句英文（PM 指出英文提示不隨語系切換）。
                    if maxDepth == 0 {
                        Text("* \(languageManager.localized("Required"))")
                            .foregroundStyle(.red)
                    }
                }

                // ── 氣體混合（Gas Mix 配置在此）─────────────
                Section {
                    Picker(languageManager.localized("Gas"), selection: $gasMixType) {
                        ForEach(GasMixPickerType.allCases) { type in
                            Text(LocalizedStringKey(type.rawValue)).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .disabled(originalTrimixGasMixJSON != nil)

                    if gasMixType == .nitrox {
                        HStack(spacing: 12) {
                            Text("O₂")
                                .foregroundStyle(.primary)
                            Slider(
                                value: $nitroxO2Percent,
                                in: 22...40,
                                step: 1
                            ) {
                                EmptyView()
                            }
                            Text("\(Int(nitroxO2Percent))%")
                                .monospacedDigit()
                                .frame(width: 44, alignment: .trailing)
                                .foregroundStyle(.primary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            String(format: languageManager.localized("Nitrox O2: %d percent"),
                                   Int(nitroxO2Percent))
                        )
                    }
                } header: {
                    Text("Gas Mix")
                } footer: {
                    if originalTrimixGasMixJSON != nil {
                        Text(languageManager.localized("Trimix gas mix isn't editable here — the original mix is preserved."))
                    }
                }

                // ═════════════════════════════════════════════════════════
                // BLOCK 3: 環境 (Environment)
                // ═════════════════════════════════════════════════════════
                Section(header: Text("Conditions")) {
                    Picker(languageManager.localized("Water Type"), selection: $environmentType) {
                        Text("Seawater").tag("seawater")
                        Text("Freshwater").tag("freshwater")
                        Text("Altitude").tag("altitude")
                    }

                    // 天氣（nil = 未記錄）
                    Picker(languageManager.localized("Weather"), selection: $weather) {
                        Text(languageManager.localized("Not Recorded")).tag(String?.none)
                        Text(LocalizedStringKey("Sunny")).tag(String?.some("sunny"))
                        Text(LocalizedStringKey("Cloudy")).tag(String?.some("cloudy"))
                        Text(LocalizedStringKey("Rainy")).tag(String?.some("rainy"))
                        Text(LocalizedStringKey("Clear")).tag(String?.some("clear"))
                    }

                    // 氣溫（nil = 未記錄）
                    HStack {
                        Text(languageManager.localized("Air Temperature"))
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField(String("–"),
                                  value: airTemperatureDisplay,
                                  format: .number.precision(.fractionLength(1)))
                            .labelsHidden()
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            .foregroundStyle(airTemperature == nil ? .secondary : .primary)
                        Text(unitSystem.temperatureSymbol)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        airTemperature.map {
                            String(format: languageManager.localized("Air Temperature: %@"), unitSystem.formatTemperature($0))
                        } ?? languageManager.localized("Air Temperature: Not recorded")
                    )

                    // 水面狀況（nil = 未記錄）
                    Picker(languageManager.localized("Surface Condition"), selection: $surfaceCondition) {
                        Text(languageManager.localized("Not Recorded")).tag(String?.none)
                        Text(LocalizedStringKey("Calm")).tag(String?.some("calm"))
                        Text(LocalizedStringKey("Slight")).tag(String?.some("slight"))
                        Text(LocalizedStringKey("Moderate")).tag(String?.some("moderate"))
                        Text(LocalizedStringKey("Rough")).tag(String?.some("rough"))
                    }

                    // 水流（nil = 未記錄）
                    Picker(languageManager.localized("Water Flow"), selection: $waterflow) {
                        Text(languageManager.localized("Not Recorded")).tag(String?.none)
                        Text(LocalizedStringKey("None")).tag(String?.some("none"))
                        Text(LocalizedStringKey("Slight")).tag(String?.some("slight"))
                        Text(LocalizedStringKey("Moderate")).tag(String?.some("moderate"))
                        Text(LocalizedStringKey("Strong")).tag(String?.some("strong"))
                    }

                    // 能見度（nil = 未記錄）
                    HStack {
                        Text(languageManager.localized("Visibility"))
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField(String("–"),
                                  value: visibilityDisplay,
                                  format: .number.precision(.fractionLength(1)))
                            .labelsHidden()
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            .foregroundStyle(visibility == nil ? .secondary : .primary)
                        Text(unitSystem.depthSymbol)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        visibility.map {
                            String(format: languageManager.localized("Visibility: %@"), unitSystem.formatDepth($0))
                        } ?? languageManager.localized("Visibility: Not recorded")
                    )
                }

                // ═════════════════════════════════════════════════════════
                // BLOCK 4: 潛水裝備 (Equipment)
                // ═════════════════════════════════════════════════════════
                Section(header: Text("Equipment")) {
                    // 防寒衣厚度（只輸入數字，mm 單位固定）
                    HStack {
                        Text(languageManager.localized("Wetsuit"))
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField(String(""), text: $wetsuitThickness)
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
                    .accessibilityLabel(languageManager.localized("Wetsuit"))

                    // 配重總重量（nil = 未填入）
                    HStack {
                        Text(languageManager.localized("Weight"))
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField(String("–"), value: weightTotalDisplay,
                                  format: .number.precision(.fractionLength(1)))
                            .labelsHidden()
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            .foregroundStyle(weightTotal == nil ? .secondary : .primary)
                        Text(unitSystem.weightSymbol)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        weightTotal.map {
                            unitSystem == .metric
                                ? String(format: languageManager.localized("Weight: %.1f kilograms"), $0)
                                : String(format: languageManager.localized("Weight: %.1f pounds"),
                                         unitSystem.convertWeight(kgValue: $0))
                        } ?? languageManager.localized("Weight: Not recorded")
                    )

                    // 氣瓶材質
                    Picker(languageManager.localized("Cylinder Material"), selection: $cylinderMaterial) {
                        Text(LocalizedStringKey("Aluminum")).tag("aluminum")
                        Text(LocalizedStringKey("Steel")).tag("steel")
                    }

                    // 氣瓶規格（預定義選項）
                    Picker(languageManager.localized("Cylinder Size"), selection: $cylinderSize) {
                        Text("S80 (12L)").tag("S80(12L)")
                        Text("S63 (8.6L)").tag("S63(8.6L)")
                        Text("AL100 (14L)").tag("AL100(14L)")
                        Text("12L (Steel)").tag("12L(Steel)")
                        Text("10L (Steel)").tag("10L(Steel)")
                    }

                    // 氣瓶起始壓力（nil = 未填入，見 init 註解）
                    HStack {
                        Text(languageManager.localized("Start Pressure"))
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField(String("–"), value: cylinderStartPressureDisplay,
                                  format: .number.precision(.fractionLength(0)))
                            .labelsHidden()
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            .foregroundStyle(cylinderStartPressure == nil ? .secondary : .primary)
                        Text(unitSystem.pressureSymbol)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        cylinderStartPressure.map {
                            unitSystem == .metric
                                ? String(format: languageManager.localized("Start Pressure: %.0f bar"), $0)
                                : String(format: languageManager.localized("Start Pressure: %.0f psi"),
                                         unitSystem.convertPressure(barValue: $0))
                        } ?? languageManager.localized("Start Pressure: Not recorded")
                    )

                    // 氣瓶結束壓力（nil = 未填入，見 init 註解）
                    HStack {
                        Text(languageManager.localized("End Pressure"))
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField(String("–"), value: cylinderEndPressureDisplay,
                                  format: .number.precision(.fractionLength(0)))
                            .labelsHidden()
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            .foregroundStyle(cylinderEndPressure == nil ? .secondary : .primary)
                        Text(unitSystem.pressureSymbol)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        languageManager.localized("End Pressure")
                    )
                }

                // ═════════════════════════════════════════════════════════
                // BLOCK 5: 地點（對齊詳情頁：Location 置於 Equipment 後）
                // ═════════════════════════════════════════════════════════
                Section(header: Text("Location")) {
                    // 日期改由「入水時間」的 date+time picker 統一選取
                    TextField(languageManager.localized("Dive Site"), text: $location)
                        .textContentType(.addressCity)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .location)
                }

                // ═════════════════════════════════════════════════════════
                // BLOCK 6: 潛水備註 (Dive Notes)
                // ═════════════════════════════════════════════════════════
                Section(header: Text("Dive Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80, maxHeight: 200)
                        .accessibilityLabel(languageManager.localized("Notes"))
                        .focused($focusedField, equals: .notes)
                }
            }
            .navigationTitle(Text(verbatim: titleText))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .formStyle(.grouped) // iOS 會自動呈現 Inset-Grouped 質感；macOS 原生分組表單
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageManager.localized("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageManager.localized("Save")) { save() }
                        .disabled(!isSaveEnabled)
                        .fontWeight(.semibold)
                        .accessibilityHint(
                            isSaveEnabled ? "" : "\(languageManager.localized("Max Depth")): \(languageManager.localized("Required"))"
                        )
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
        // Trimix 潛水：picker 不支援編輯，維持原始 JSON，不用 Air/Nitrox picker 的
        // 顯示值覆寫（見 originalTrimixGasMixJSON 宣告處說明）。
        let gasMixJSON   = originalTrimixGasMixJSON ?? buildGasMixJSON()

        // 計算出水時間：基於入水時間 + 潛水時間
        let calculatedExitTime = Calendar.current.date(
            byAdding: .minute,
            value: durationMinutes,
            to: entryTime
        )

        switch mode {
        case .new:
            let dive = DiveLog(
                dateTime:        entryTime,
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
            dive.wetsuitThickness = wetsuitThickness.isEmpty ? nil : wetsuitThickness
            dive.weightTotal = weightTotal
            dive.cylinderMaterial = cylinderMaterial.isEmpty ? nil : cylinderMaterial
            dive.cylinderSize = cylinderSize.isEmpty ? nil : cylinderSize
            dive.cylinderStartPressure = cylinderStartPressure
            dive.cylinderEndPressure = cylinderEndPressure

            modelContext.insert(dive)

        case .edit(let dive):
            dive.dateTime         = entryTime
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
            dive.wetsuitThickness = wetsuitThickness.isEmpty ? nil : wetsuitThickness
            dive.weightTotal = weightTotal
            dive.cylinderMaterial = cylinderMaterial.isEmpty ? nil : cylinderMaterial
            dive.cylinderSize = cylinderSize.isEmpty ? nil : cylinderSize
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
