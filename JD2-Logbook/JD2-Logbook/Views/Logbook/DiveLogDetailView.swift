// DiveLogDetailView.swift — JD2-Logbook/Views/Logbook/
// Week 9 — 單筆潛水詳情頁（唯讀，Week 11 加入編輯）

import SwiftUI
import SwiftData
import Charts
import DiveKit
import DiveKitUI

struct DiveLogDetailView: View {
    let dive: DiveLog
    /// macOS：刪除後通知容器清空右側詳情欄（iOS 用 dismiss 返回）
    var onDeleted: (() -> Void)? = nil

    @Environment(AppLanguageManager.self) private var languageManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet     = false
    @State private var showDeleteConfirm = false

    // v1.2 #4：公制／英制單位系統，儲存值永遠是公制，這裡只負責顯示層換算。
    @AppStorage(UnitSystem.storageKey) private var unitSystem = UnitSystem.metric

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
        case "freshwater": return languageManager.localized("Freshwater")
        case "altitude":   return languageManager.localized("Altitude")
        default:           return languageManager.localized("Seawater")
        }
    }

    private var gasMixText: String {
        guard let data = dive.gasMixJSON.data(using: .utf8),
              let gas = try? JSONDecoder().decode(GasMix.self, from: data) else {
            return languageManager.localized("Air")
        }
        return gas.localizedDisplayName(languageManager)
    }

    private var coordinatesText: String? {
        guard let lat = dive.latitude, let lon = dive.longitude else { return nil }
        return String(format: "%.5f°, %.5f°", lat, lon)
    }

    /// v1.1 #4/#5：解碼氣體配置供 DiveAnalysisView 重放使用
    private var diveGasMix: GasMix {
        guard let data = dive.gasMixJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(GasMix.self, from: data)
        else { return .air }
        return decoded
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

            // ── 深度剖面圖 + 組織艙飽和度（v1.1 #4/#5：合併為單一互動單元）──
            // 拖曳剖面任一點才顯示組織艙長條（省視覺空間，比照 JD2-Ultra companion）；
            // ≥2 個樣本才有意義的重放結果，否則退回純剖面圖（無互動查點）。
            let profileSamples = dive.profileSamples
            if !profileSamples.isEmpty {
                Section(
                    header: Text("Dive Profile"),
                    footer: profileSamples.count >= 2
                        ? Text("Estimated using Bühlmann ZHL-16C from the imported profile only. Not a substitute for your dive computer or certified decompression software.")
                        : nil
                ) {
                    if profileSamples.count >= 2 {
                        DiveAnalysisView(samples: profileSamples, gasMix: diveGasMix)
                            .id(dive.persistentModelID)   // 換一筆 dive 時強制重建，選取狀態不跨潛水殘留
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    } else {
                        DiveProfileChartView(samples: profileSamples)
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    }
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
                if dive.avgDepth > 0 {
                    DetailRow(icon: "water.waves",   label: "Avg Depth",     value: unitSystem.formatDepth(dive.avgDepth))
                }
                DetailRow(icon: "doc.text",          label: "Source Format", value: sourceFormatDisplayName(dive.sourceFormat))
            }

            // ── 環境詳細資訊（僅顯示有來源資料的欄位；nil = 未記錄不顯示）──
            let hasConditions = dive.weather != nil || dive.airTemperature != nil
                || dive.surfaceCondition != nil || dive.waterflow != nil || dive.visibility != nil
            if hasConditions {
                Section(header: Text("Conditions")) {
                    if let w = dive.weather {
                        DetailRow(icon: "sun.max.fill",   label: "Weather",           value: weatherDisplayName(w))
                    }
                    if let t = dive.airTemperature {
                        DetailRow(icon: "thermometer.medium", label: "Air Temperature", value: unitSystem.formatTemperature(t))
                    }
                    if let sc = dive.surfaceCondition {
                        DetailRow(icon: "water.waves",    label: "Surface Condition", value: surfaceConditionDisplayName(sc))
                    }
                    if let wf = dive.waterflow {
                        DetailRow(icon: "wind",           label: "Water Flow",        value: waterFlowDisplayName(wf))
                    }
                    if let vis = dive.visibility {
                        DetailRow(icon: "eye.fill",       label: "Visibility",        value: unitSystem.formatDepth(vis))
                    }
                }
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

            // ── 原始資料（v1.1 #6/#7：匯入來源無對應欄位的原始資料，可折疊）──
            let extras = dive.importExtras
            if !extras.isEmpty {
                Section {
                    DisclosureGroup(languageManager.localized("Raw Import Data")) {
                        ForEach(extras.keys.sorted(), id: \.self) { key in
                            DetailRow(icon: "shippingbox", label: importExtraKeyLabel(key), value: extras[key] ?? "")
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .navigationTitle(Text(verbatim: languageManager.localized("Dive Details")))
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
                .accessibilityLabel(languageManager.localized("Delete Dive"))
            }
            // ── Edit 按鈕 ────────────────────────────────────
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showEditSheet = true
                } label: {
                    Text("Edit")
                }
                .accessibilityLabel(languageManager.localized("Edit Dive"))
            }
        }
        // ── 刪除確認 ──────────────────────────────────────────
        .confirmationDialog(
            languageManager.localized("Delete this dive log?"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(languageManager.localized("Delete"), role: .destructive) { deleteDive() }
            Button(languageManager.localized("Cancel"), role: .cancel) { }
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
                     ? languageManager.localized("Unknown Location")
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
            DiveKitUI.DiveStatCell(
                value: String(format: "%.1f", unitSystem.convertDepth(metersValue: dive.maxDepth)),
                unit: unitSystem.depthSymbol,
                label: "Max Depth",
                icon: "arrow.down.to.line",
                color: .accentColor,
                secondaryColor: .accessibleSecondary
            )

            Divider().frame(height: 48)

            DiveKitUI.DiveStatCell(
                value: durationFormatted,
                unit: "",
                label: "Dive Time",
                icon: "timer",
                color: .orange,
                secondaryColor: .accessibleSecondary
            )

            Divider().frame(height: 48)

            DiveKitUI.DiveStatCell(
                value: String(format: "%.0f", unitSystem.convertTemperature(celsiusValue: dive.waterTemperature)),
                unit: unitSystem.temperatureSymbol,
                label: "Water Temp",
                icon: "thermometer.medium",
                color: .cyan,
                secondaryColor: .accessibleSecondary
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
        case "sunny":  return languageManager.localized("Sunny")
        case "cloudy": return languageManager.localized("Cloudy")
        case "rainy":  return languageManager.localized("Rainy")
        case "clear":  return languageManager.localized("Clear")
        default:       return raw
        }
    }

    private func surfaceConditionDisplayName(_ raw: String) -> String {
        switch raw.lowercased() {
        case "calm":     return languageManager.localized("Calm")
        case "slight":   return languageManager.localized("Slight")
        case "moderate": return languageManager.localized("Moderate")
        case "rough":    return languageManager.localized("Rough")
        default:         return raw
        }
    }

    private func waterFlowDisplayName(_ raw: String) -> String {
        switch raw.lowercased() {
        case "none":     return languageManager.localized("None")
        case "slight":   return languageManager.localized("Slight")
        case "moderate": return languageManager.localized("Moderate")
        case "strong":   return languageManager.localized("Strong")
        default:         return raw
        }
    }

    // Optional overloads — 供上方 if let 模式呼叫
    private func weatherDisplayName(_ raw: String?) -> String { raw.map { weatherDisplayName($0) } ?? "" }
    private func surfaceConditionDisplayName(_ raw: String?) -> String { raw.map { surfaceConditionDisplayName($0) } ?? "" }
    private func waterFlowDisplayName(_ raw: String?) -> String { raw.map { waterFlowDisplayName($0) } ?? "" }

    private func cylinderMaterialDisplayName(_ raw: String) -> String {
        switch raw.lowercased() {
        case "aluminum": return languageManager.localized("Aluminum")
        case "steel":    return languageManager.localized("Steel")
        default:         return raw
        }
    }

    /// importExtrasJSON 的 key（英文，見 DiveLogImporter.swift 各 parser）→ 顯示用標籤
    private func importExtraKeyLabel(_ key: String) -> String {
        switch key {
        case "buddy":          return languageManager.localized("Buddy")
        case "tags":           return languageManager.localized("Tags")
        case "diveNumber":     return languageManager.localized("Dive Number")
        case "deviceModel":    return languageManager.localized("Device Model")
        case "deviceSerial":   return languageManager.localized("Device Serial")
        case "deviceFirmware": return languageManager.localized("Device Firmware")
        default:               return key
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
        case "garmin-json":    return "Garmin Connect"
        case "seabear",
             "seabear-csv":    return "Seabear CSV"
        case "shearwater":     return "Shearwater XML"
        case "suunto-dm5":     return "Suunto DM5"
        case "suunto-sml":     return "Suunto SML"
        case "dan-dl7":        return "DAN DL7"
        case "divesoft-dlf":   return "Divesoft DLF"
        case "suunto-sde":     return "Suunto SDE"
        case "reefnet-sensus": return "Reefnet Sensus"
        case "divinglog":      return "Diving Log 6.0"
        case "manual":         return "Manual Entry"
        default:               return raw.isEmpty ? "—" : raw
        }
    }
}

// MARK: - Key Stat Cell

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
