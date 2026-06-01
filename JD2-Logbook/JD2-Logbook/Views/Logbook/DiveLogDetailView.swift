// DiveLogDetailView.swift — JD2-Logbook/Views/Logbook/
// Week 9 — 單筆潛水詳情頁（唯讀，Week 11 加入編輯）

import SwiftUI
import SwiftData
import Charts

struct DiveLogDetailView: View {
    let dive: DiveLog
    /// macOS：刪除後通知容器清空右側詳情欄（iOS 用 dismiss 返回）
    var onDeleted: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet     = false
    @State private var showDeleteConfirm = false

    // MARK: - Computed

    private var durationFormatted: String {
        // 一律以總分鐘顯示（捨棄時/秒），例如 1h15m → 75 min
        let minutes = Int((Double(dive.diveTimeSeconds) / 60.0).rounded())
        return "\(minutes) min"
    }

    /// 是否有任何裝備欄位有值（皆無則整個 Equipment 區塊隱藏）
    private var hasEquipment: Bool {
        (dive.wetsuitThickness?.isEmpty == false)
            || dive.weightTotal != nil
            || (dive.cylinderMaterial?.isEmpty == false)
            || (dive.cylinderSize?.isEmpty == false)
            || dive.cylinderStartPressure != nil
            || dive.cylinderEndPressure != nil
    }

    private var environmentText: String {
        switch dive.environmentType {
        case "freshwater": return String(localized: "Freshwater")
        case "altitude":   return String(localized: "Altitude")
        default:           return String(localized: "Seawater")
        }
    }

    private var gasMixText: String {
        guard let data = dive.gasMixJSON.data(using: .utf8),
              let gas = try? JSONDecoder().decode(GasMix.self, from: data) else {
            return String(localized: "Air")
        }
        switch gas {
        case .air:
            return String(localized: "Air")
        case .nitrox(let fO2):
            let eanxLabel = String(localized: "EANx")
            return String(format: "%@ (EANx%d)", eanxLabel, Int(fO2 * 100))
        case .trimix(let fO2, let fHe):
            let trimixLabel = String(localized: "Trimix")
            return String(format: "%@ (Trimix%.0f/%.0f)", trimixLabel, fO2 * 100, fHe * 100)
        }
    }

    private var coordinatesText: String? {
        guard let lat = dive.latitude, let lon = dive.longitude else { return nil }
        return String(format: "%.5f°, %.5f°", lat, lon)
    }

    // MARK: - Body

    var body: some View {
        List {
            // ── Hero：地點 + 日期 ───────────────────────
            Section {
                heroHeader
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            // ── 深度剖面圖（有樣本才顯示）──────────────────
            let profileSamples = dive.profileSamples
            if !profileSamples.isEmpty {
                Section(header: Text("Dive Profile")) {
                    DiveProfileChartView(samples: profileSamples)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }
            }

            // ── 關鍵數據 ────────────────────────────────
            Section(header: Text("Key Stats")) {
                keyStatsRow
            }

            // ── 潛水資訊 ────────────────────────────────
            Section(header: Text("Dive Info")) {
                DetailRow(icon: "bubbles.and.sparkles.fill", label: "Gas",      value: gasMixText)
                DetailRow(icon: "water.waves",       label: "Environment",   value: environmentText)
                DetailRow(icon: "doc.text",          label: "Source Format", value: sourceFormatDisplayName(dive.sourceFormat))
            }

            // ── 環境詳細資訊 ──────────────────────────
            Section(header: Text("Conditions")) {
                DetailRow(icon: "sun.max.fill",        label: "Weather",           value: weatherDisplayName(dive.weather))
                DetailRow(icon: "thermometer.medium",  label: "Air Temperature",   value: String(format: "%.0f°C", dive.airTemperature))
                DetailRow(icon: "water.waves",         label: "Surface Condition", value: surfaceConditionDisplayName(dive.surfaceCondition))
                DetailRow(icon: "wind",                label: "Water Flow",        value: waterFlowDisplayName(dive.waterflow))
                DetailRow(icon: "eye.fill",            label: "Visibility",        value: String(format: "%.1f m", dive.visibility))
            }

            // ── 時間詳細資訊 ──────────────────────────
            // 匯入的潛水通常未填 entryTime/exitTime；以 dateTime（入水）與
            // diveTimeSeconds（時長）推導，確保兩個欄位皆有值可顯示。
            Section(header: Text("Entry & Exit")) {
                let entry = dive.entryTime ?? dive.dateTime
                let exit  = dive.exitTime ?? Calendar.current.date(
                    byAdding: .second, value: dive.diveTimeSeconds, to: entry)
                DetailRow(icon: "arrow.right.to.line",
                          label: "Entry Time",
                          value: formatTime(entry))
                if let exit {
                    DetailRow(icon: "arrow.left.to.line",
                              label: "Exit Time",
                              value: formatTime(exit))
                }
            }

            // ── 裝備詳細資訊（僅顯示有提供的欄位；匯入未提供者留空隱藏）──
            if hasEquipment {
                Section(header: Text("Equipment")) {
                    if let w = dive.wetsuitThickness, !w.isEmpty {
                        // 儲存值為純數字（如 "2.5"）；顯示時補回 mm 單位（舊資料若已含 mm 則不重複）
                        DetailRow(icon: "tshirt.fill",         label: "Wetsuit",
                                  value: w.lowercased().contains("mm") ? w : "\(w) mm")
                    }
                    if let weight = dive.weightTotal {
                        DetailRow(icon: "scalemass.fill",      label: "Weight",            value: String(format: "%.1f kg", weight))
                    }
                    if let m = dive.cylinderMaterial, !m.isEmpty {
                        DetailRow(icon: "waterbottle.fill",    label: "Cylinder Material", value: cylinderMaterialDisplayName(m))
                    }
                    if let s = dive.cylinderSize, !s.isEmpty {
                        DetailRow(icon: "waterbottle.fill",    label: "Cylinder Size",     value: s)
                    }
                    if let sp = dive.cylinderStartPressure {
                        DetailRow(icon: "gauge",               label: "Start Pressure",    value: String(format: "%.0f bar", sp))
                    }
                    if let ep = dive.cylinderEndPressure {
                        DetailRow(icon: "gauge",               label: "End Pressure",      value: String(format: "%.0f bar", ep))
                    }
                }
            }

            // ── 地點 ────────────────────────────────────
            Section(header: Text("Location")) {
                if !dive.location.isEmpty {
                    DetailRow(icon: "location.fill",  label: "Location", value: dive.location)
                }
                if let coords = coordinatesText {
                    DetailRow(icon: "globe",           label: "Coordinates", value: coords)
                }
            }

            // ── 備註 ────────────────────────────────────
            Section(header: Text("Notes")) {
                if dive.notes.isEmpty {
                    Text("No notes recorded.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    Text(dive.notes)
                        .font(.subheadline)
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .navigationTitle("Dive Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            // ── Delete 按鈕 ──────────────────────────────────
            ToolbarItem(placement: .automatic) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(String(localized: "Delete Dive"))
            }
            // ── Edit 按鈕 ────────────────────────────────────
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showEditSheet = true
                } label: {
                    Text("Edit")
                }
                .accessibilityLabel(String(localized: "Edit Dive"))
            }
        }
        // ── 刪除確認 ──────────────────────────────────────────
        .confirmationDialog(
            String(localized: "Delete this dive log?"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete"), role: .destructive) { deleteDive() }
            Button(String(localized: "Cancel"), role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        // ── Edit Sheet ───────────────────────────────────────
        .sheet(isPresented: $showEditSheet) {
            DiveLogEditSheet(mode: .edit(dive))
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 地點名稱
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)   // 裝飾性圖示，避免 VoiceOver 讀出無意義 label
                Text(dive.location.isEmpty
                     ? String(localized: "Unknown Location")
                     : dive.location)
                    .font(.title3.bold())
                    .lineLimit(2)
            }
            .accessibilityElement(children: .combine)

            // 日期時間
            Text(dive.dateTime, format: .dateTime
                .weekday(.wide)
                .day()
                .month(.wide)
                .year()
                .hour()
                .minute()
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Key Stats Row (深度 / 時間 / 水溫)

    private var keyStatsRow: some View {
        HStack(spacing: 0) {
            KeyStatCell(
                value: String(format: "%.1f", dive.maxDepth),
                unit: "m",
                label: "Max Depth",
                icon: "arrow.down.to.line",
                color: .accentColor
            )

            Divider().frame(height: 48)

            KeyStatCell(
                value: durationFormatted,
                unit: "",
                label: "Dive Time",
                icon: "timer",
                color: .orange
            )

            Divider().frame(height: 48)

            KeyStatCell(
                value: String(format: "%.0f", dive.waterTemperature),
                unit: "°C",
                label: "Water Temp",
                icon: "thermometer.medium",
                color: .cyan
            )
        }
        .padding(.vertical, 8)
    }

    // MARK: - Delete

    private func deleteDive() {
        modelContext.delete(dive)
        try? modelContext.save()
        // macOS：清空右側詳情欄；iOS：返回上一頁
        onDeleted?()
        dismiss()
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func weatherDisplayName(_ raw: String) -> String {
        switch raw.lowercased() {
        case "sunny":  return String(localized: "Sunny")
        case "cloudy": return String(localized: "Cloudy")
        case "rainy":  return String(localized: "Rainy")
        case "clear":  return String(localized: "Clear")
        default:       return raw
        }
    }

    private func surfaceConditionDisplayName(_ raw: String) -> String {
        switch raw.lowercased() {
        case "calm":     return String(localized: "Calm")
        case "slight":   return String(localized: "Slight")
        case "moderate": return String(localized: "Moderate")
        case "rough":    return String(localized: "Rough")
        default:         return raw
        }
    }

    private func waterFlowDisplayName(_ raw: String) -> String {
        switch raw.lowercased() {
        case "none":     return String(localized: "None")
        case "slight":   return String(localized: "Slight")
        case "moderate": return String(localized: "Moderate")
        case "strong":   return String(localized: "Strong")
        default:         return raw
        }
    }

    private func cylinderMaterialDisplayName(_ raw: String) -> String {
        switch raw.lowercased() {
        case "aluminum": return String(localized: "Aluminum")
        case "steel":    return String(localized: "Steel")
        default:         return raw
        }
    }

    private func sourceFormatDisplayName(_ raw: String) -> String {
        switch raw.lowercased() {
        case "uddf":            return "UDDF"
        case "subsurface",
             "subsurfacexml":  return "Subsurface XML"
        case "csv",
             "subsurfacecsv":  return "Subsurface CSV"
        case "suunto",
             "suunto-json":    return "Suunto JSON"
        case "garmin",
             "garmin-fit":     return "Garmin Descent"
        case "seabear",
             "seabear-csv":    return "Seabear CSV"
        case "manual":         return "Manual Entry"
        default:               return raw.isEmpty ? "—" : raw
        }
    }
}

// MARK: - Key Stat Cell

private struct KeyStatCell: View {
    let value: String
    let unit: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(value)
                    .font(.title3.bold().monospacedDigit())
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.accessibleSecondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6) // 「27 min 22 sec」等長值改縮放保持單行，不換行

            Text(LocalizedStringKey(label))
                .font(.caption2)
                .foregroundStyle(Color.accessibleSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)\(unit)")
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 20)

            Text(LocalizedStringKey(label))
                .foregroundStyle(Color.accessibleSecondary)

            Spacer()

            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

#Preview {
    NavigationStack {
        DiveLogDetailView(dive: DiveLog(
            dateTime: Date(),
            location: "Small Island, Komodo",
            maxDepth: 52.3,
            diveTimeSeconds: 5640,
            gasMixJSON: "\"air\"",
            waterTemperature: 28.0
        ))
    }
}
