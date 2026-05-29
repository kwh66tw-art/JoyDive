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

struct DiveSiteSheetView: View {

    let dive: DiveLog

    // MARK: - Computed helpers

    private var locationName: String {
        dive.location.isEmpty
            ? String(localized: "Unknown Location")
            : dive.location
    }

    private var durationFormatted: String {
        let total = dive.diveTimeSeconds
        let h = total / 3600
        let m = (total % 3600) / 60
        return h > 0
            ? String(format: "%dh %02dm", h, m)
            : String(format: "%d min", m)
    }

    private var gasMixText: String {
        guard let data = dive.gasMixJSON.data(using: .utf8),
              let gas  = try? JSONDecoder().decode(GasMix.self, from: data) else {
            return String(localized: "Air")
        }
        switch gas {
        case .air:
            return String(localized: "Air")
        case .nitrox(let o2):
            return String(format: "EANx%d", Int(o2 * 100))
        case .trimix(let o2, let he):
            return String(format: "Tx%.0f/%.0f", o2 * 100, he * 100)
        }
    }

    private var environmentText: String {
        switch dive.environmentType {
        case "freshwater": return String(localized: "Freshwater")
        case "altitude":   return String(localized: "Altitude")
        default:           return String(localized: "Seawater")
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
        case "manual":                      return String(localized: "Manual Entry")
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
            "\(locationName), \(String(format: "%.1f", dive.maxDepth)) m, \(durationFormatted)"
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
            SheetStatCell(
                value: String(format: "%.1f", dive.maxDepth),
                unit:  "m",
                label: String(localized: "Max Depth"),
                icon:  "arrow.down.to.line",
                color: .accentColor
            )

            Divider().frame(height: 44)

            SheetStatCell(
                value: durationFormatted,
                unit:  "",
                label: String(localized: "Duration"),
                icon:  "timer",
                color: .orange
            )

            Divider().frame(height: 44)

            SheetStatCell(
                value: String(format: "%.0f", dive.waterTemperature),
                unit:  "°C",
                label: String(localized: "Water Temp"),
                icon:  "thermometer.medium",
                color: .cyan
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
            SheetSectionHeader(title: String(localized: "Dive Info"))

            SheetDetailRow(icon:  "drop.fill",
                           label: String(localized: "Gas"),
                           value: gasMixText)
            SheetDetailRow(icon:  "waveform.path",
                           label: String(localized: "Environment"),
                           value: environmentText)
            SheetDetailRow(icon:  "doc.text",
                           label: String(localized: "Source Format"),
                           value: sourceFormatText)

            // ── Location ─────────────────────────────────────────────
            if !dive.location.isEmpty || coordinatesText != nil {
                SheetSectionHeader(title: String(localized: "Location"))

                if !dive.location.isEmpty {
                    SheetDetailRow(icon:  "location.fill",
                                   label: String(localized: "Location"),
                                   value: dive.location)
                }
                if let coords = coordinatesText {
                    SheetDetailRow(icon:  "globe",
                                   label: String(localized: "Coordinates"),
                                   value: coords)
                }
            }

            // ── Notes ────────────────────────────────────────────────
            SheetSectionHeader(title: String(localized: "Notes"))

            Text(dive.notes.isEmpty
                 ? String(localized: "No notes recorded.")
                 : dive.notes)
                .font(.subheadline)
                .foregroundStyle(dive.notes.isEmpty ? .secondary : .primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - SheetStatCell

private struct SheetStatCell: View {
    let value: String
    let unit:  String
    let label: String
    let icon:  String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(value)
                    .font(.callout.bold().monospacedDigit())
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)\(unit)")
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
                .foregroundStyle(.secondary)

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
