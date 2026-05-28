// DiveLogDetailView.swift — JD2-Logbook/Views/Logbook/
// Week 9 — 單筆潛水詳情頁（唯讀，Week 11 加入編輯）

import SwiftUI
import Charts

struct DiveLogDetailView: View {
    let dive: DiveLog
    @State private var showEditSheet          = false
    @State private var purchaseManager        = PurchaseManager.shared
    @State private var showPremiumSheet       = false
    @State private var showExportFormatPicker = false
    @State private var exportItem: ExportItem?

    // MARK: - Computed

    private var durationFormatted: String {
        let total = dive.diveTimeSeconds
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%dh %02dm %02ds", h, m, s)
        } else {
            return String(format: "%d min %02d sec", m, s)
        }
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
            return String(format: "EANx%d (%.0f%% O₂)", Int(fO2 * 100), fO2 * 100)
        case .trimix(let fO2, let fHe):
            return String(format: "Tx%.0f/%.0f (%.0f%% O₂, %.0f%% He)",
                          fO2 * 100, fHe * 100, fO2 * 100, fHe * 100)
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
                DetailRow(icon: "drop.fill",         label: "Gas",           value: gasMixText)
                DetailRow(icon: "waveform.path",     label: "Environment",   value: environmentText)
                DetailRow(icon: "doc.text",          label: "Source Format", value: sourceFormatDisplayName(dive.sourceFormat))
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

            // ── 潛伴 ────────────────────────────────────
            if let buddy = dive.buddy, !buddy.isEmpty {
                Section(header: Text("Buddy")) {
                    Label(buddy, systemImage: "person.2.fill")
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
            // ── Export 按鈕 ──────────────────────────────────
            ToolbarItem(placement: .automatic) {
                Button {
                    if purchaseManager.isPremium {
                        showExportFormatPicker = true
                    } else {
                        showPremiumSheet = true
                    }
                } label: {
                    // 非 Premium：圖示半透明 + 右下角小鎖頭
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "square.and.arrow.up")
                            .opacity(purchaseManager.isPremium ? 1.0 : 0.4)
                        if !purchaseManager.isPremium {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.secondary)
                                .offset(x: 3, y: 3)
                        }
                    }
                }
                .accessibilityLabel(
                    purchaseManager.isPremium
                        ? String(localized: "Export Dive")
                        : String(localized: "Export Dive — Premium Required")
                )
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
        // ── Format 選擇 ──────────────────────────────────────
        .confirmationDialog(
            String(localized: "Export Format"),
            isPresented: $showExportFormatPicker,
            titleVisibility: .visible
        ) {
            Button("UDDF (.uddf)") { triggerExport(format: .uddf) }
            Button("CSV (.csv)")   { triggerExport(format: .csv)  }
            Button(String(localized: "Cancel"), role: .cancel) { }
        }
        // ── Share Sheet ──────────────────────────────────────
        .sheet(item: $exportItem) { item in
            ActivityView(url: item.url)
        }
        // ── Premium Upgrade ──────────────────────────────────
        .sheet(isPresented: $showPremiumSheet) {
            PremiumUpgradeSheet()
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
                Text(dive.location.isEmpty
                     ? String(localized: "Unknown Location")
                     : dive.location)
                    .font(.title3.bold())
                    .lineLimit(2)
            }

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
                label: "Duration",
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

    // MARK: - Export

    private func triggerExport(format: ExportFormat) {
        do {
            let url = try DiveExporter.exportToTempFile([dive], as: format)
            exportItem = ExportItem(url: url)
        } catch {
            // 生成失敗時靜默處理（儲存空間不足等極端情況）
            print("[DiveLogDetailView] Export failed: \(error)")
        }
    }

    // MARK: - Helpers

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
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6) // 「27 min 22 sec」等長值改縮放保持單行，不換行

            Text(LocalizedStringKey(label))
                .font(.caption2)
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)

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
