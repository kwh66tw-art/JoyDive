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

    // Gas mix
    private enum GasMixPickerType: String, CaseIterable, Identifiable {
        case air    = "Air"
        case nitrox = "Nitrox"
        var id: String { rawValue }
    }
    @State private var gasMixType: GasMixPickerType
    @State private var nitroxO2Percent: Double  // 22–40

    // MARK: - Init

    init(mode: DiveEditMode) {
        self.mode = mode

        switch mode {
        case .new:
            _dateTime           = State(initialValue: Date())
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
            _dateTime           = State(initialValue: dive.dateTime)
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
                Section {
                    DatePicker(
                        String(localized: "Date & Time"),
                        selection: $dateTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .accessibilityLabel(String(localized: "Date & Time"))
                }

                // ── 地點 ─────────────────────────────────
                Section(header: Text("Location")) {
                    TextField(String(localized: "Dive Site"), text: $location)
                        .textContentType(.addressCity)
                        .autocorrectionDisabled()
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
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
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
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
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
                }

                // ── 備註 ─────────────────────────────────
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80, maxHeight: 200)
                        .accessibilityLabel(String(localized: "Notes"))
                }
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
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
