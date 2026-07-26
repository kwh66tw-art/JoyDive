// DiveSiteSheetView.swift — JD2-Logbook/Views/Map/
// Week 10 — Medium Detent Sheet shown when a map pin is tapped
//
// Detent behaviour (set by caller in MapView):
//   .fraction(0.35) → peekSection visible: location name + date + 3-col stats
//   .large          → peekSection + fullDetailsSection fully visible
//
// Layout uses ScrollView (not List) to avoid scroll-conflict inside a sheet.
// All helper structs are file-private to keep the surface area minimal.

import SwiftUI
import DiveKit
import DiveKitUI

struct DiveSiteSheetView: View {

    let dive: DiveLog

    // v1.2 #4：公制／英制單位系統，儲存值永遠是公制，這裡只負責顯示層換算。
    @AppStorage(UnitSystem.storageKey) private var unitSystem = UnitSystem.metric

    // ⚠️ 這裡全面改用 languageManager.localized(_:) 而非 String(localized:)：
    // 這些 computed property 回傳的是 String（餵給 SheetDetailRow(label:value:) /
    // accessibility label），不是 Text，無法靠 `.environment(\.locale)` 即時跟隨
    // in-app 語言切換——String(localized:) 讀的是系統 Locale.current，語言切換後
    // 不重開 App 就會殘留切換前的語言（本次真機回報的 bug 根因）。比照
    // AppLanguageManager.swift 文件註解的「四段式解法」③，全面改走
    // languageManager.localized(_:) 手動查表。
    @Environment(AppLanguageManager.self) private var languageManager

    // MARK: - Computed helpers

    private var locationName: String {
        dive.location.isEmpty
            ? languageManager.localized("Unknown Location")
            : dive.location
    }

    private var durationFormatted: String {
        // 一律以總分鐘顯示（捨棄時/秒），例如 1h15m → 75 min
        let minutes = Int((Double(dive.diveTimeSeconds) / 60.0).rounded())
        return "\(minutes) min"
    }

    private var gasMixText: String {
        guard let data = dive.gasMixJSON.data(using: .utf8),
              let gas  = try? JSONDecoder().decode(GasMix.self, from: data) else {
            return languageManager.localized("Air")
        }
        return gas.localizedDisplayName(languageManager)
    }

    private var environmentText: String {
        switch dive.environmentType {
        case "freshwater": return languageManager.localized("Freshwater")
        case "altitude":   return languageManager.localized("Altitude")
        default:           return languageManager.localized("Seawater")
        }
    }

    private var coordinatesText: String? {
        guard let lat = dive.latitude, let lon = dive.longitude else { return nil }
        return String(format: "%.5f°, %.5f°", lat, lon)
    }

    private var sourceFormatText: String {
        switch dive.sourceFormat.lowercased() {
        case "uddf":                        return "UDDF"
        case "subsurface", "subsurfacexml": return "Subsurface XML"
        case "csv", "subsurfacecsv":        return "Subsurface CSV"
        case "suunto", "suunto-json":       return "Suunto JSON"
        case "garmin", "garmin-fit":        return "Garmin Descent"
        case "seabear", "seabear-csv":      return "Seabear CSV"
        case "manual":                      return languageManager.localized("Manual Entry")
        default:
            return dive.sourceFormat.isEmpty ? "—" : dive.sourceFormat
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Peek Section ────────────────────────────────────────
                // Always fully visible at 0.35 detent
                peekSection
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 16)

                Divider()
                    .padding(.horizontal, 20)

                // ── Full Details Section ────────────────────────────────
                // Revealed when user pulls sheet to .large
                fullDetailsSection
                    .padding(.top, 8)
                    .padding(.bottom, 40)
            }
        }
        .accessibilityLabel(
            "\(locationName), \(unitSystem.formatDepth(dive.maxDepth)), \(durationFormatted)"
        )
    }

    // MARK: - Peek Section

    private var peekSection: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Location name (up to 2 lines)
            Text(locationName)
                .font(.title3.bold())
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Date + time — locale-aware
            Text(dive.dateTime, format: .dateTime
                .weekday(.abbreviated)
                .day()
                .month(.abbreviated)
                .year()
                .hour()
                .minute()
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            // 3-column key stats
            keyStatsRow
                .padding(.top, 4)
        }
    }

    // MARK: - Key Stats Row

    private var keyStatsRow: some View {
        HStack(spacing: 0) {
            DiveKitUI.DiveStatCell(
                value: String(format: "%.1f", unitSystem.convertDepth(metersValue: dive.maxDepth)),
                unit:  unitSystem.depthSymbol,
                label: "Max Depth",
                icon:  "arrow.down.to.line",
                color: .accentColor,
                secondaryColor: .accessibleSecondary,
                style: .compact
            )

            Divider().frame(height: 44)

            DiveKitUI.DiveStatCell(
                value: durationFormatted,
                unit:  "",
                label: "Dive Time",
                icon:  "timer",
                color: .orange,
                secondaryColor: .accessibleSecondary,
                style: .compact
            )

            Divider().frame(height: 44)

            DiveKitUI.DiveStatCell(
                value: String(format: "%.0f", unitSystem.convertTemperature(celsiusValue: dive.waterTemperature)),
                unit:  unitSystem.temperatureSymbol,
                label: "Water Temp",
                icon:  "thermometer.medium",
                color: .cyan,
                secondaryColor: .accessibleSecondary,
                style: .compact
            )
        }
        .padding(.vertical, 6)
        #if os(iOS)
        .background(Color(.secondarySystemGroupedBackground))
        #else
        .background(Color(NSColor.controlBackgroundColor))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Full Details Section

    private var fullDetailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Dive Info ────────────────────────────────────────────
            SheetSectionHeader(title: languageManager.localized("Dive Info"))

            SheetDetailRow(icon:  "drop.fill",
                           label: languageManager.localized("Gas"),
                           value: gasMixText)
            SheetDetailRow(icon:  "waveform.path",
                           label: languageManager.localized("Environment"),
                           value: environmentText)
            SheetDetailRow(icon:  "doc.text",
                           label: languageManager.localized("Source Format"),
                           value: sourceFormatText)

            // ── Location ─────────────────────────────────────────────
            if !dive.location.isEmpty || coordinatesText != nil {
                SheetSectionHeader(title: languageManager.localized("Location"))

                if !dive.location.isEmpty {
                    SheetDetailRow(icon:  "location.fill",
                                   label: languageManager.localized("Location"),
                                   value: dive.location)
                }
                if let coords = coordinatesText {
                    SheetDetailRow(icon:  "globe",
                                   label: languageManager.localized("Coordinates"),
                                   value: coords)
                }
            }

            // ── Notes ────────────────────────────────────────────────
            SheetSectionHeader(title: languageManager.localized("Notes"))

            Text(dive.notes.isEmpty
                 ? languageManager.localized("No notes recorded.")
                 : dive.notes)
                .font(.subheadline)
                .foregroundStyle(dive.notes.isEmpty ? .secondary : .primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - SheetDetailRow

private struct SheetDetailRow: View {
    let icon:  String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 20)

            Text(label)
                .foregroundStyle(Color.accessibleSecondary)

            Spacer()

            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
        .font(.subheadline)
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - SheetSectionHeader

private struct SheetSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Preview

#Preview("Medium Detent") {
    let dive = DiveLog(
        dateTime:         Date(),
        location:         "Small Island, Komodo",
        maxDepth:         52.3,
        diveTimeSeconds:  5640,
        gasMixJSON:       "\"air\"",
        waterTemperature: 28.0
    )
    dive.latitude  = -8.54321
    dive.longitude = 119.48765
    dive.notes     = "Fantastic drift dive. Visibility 20 m. Saw manta rays."

    return DiveSiteSheetView(dive: dive)
        .presentationDetents([.fraction(0.35), .large])
        .presentationDragIndicator(.visible)
}
