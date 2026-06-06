// DiveRowView.swift — JD2-Logbook/Views/Logbook/
// Week 9 — 潛水日誌列表卡片元件

import SwiftUI

struct DiveRowView: View {
    let dive: DiveLog
    /// macOS：是否為目前選取的卡片（畫在卡片邊框上，取代 List 系統選取框）
    var isSelected: Bool = false

    // MARK: - Computed properties

    var locationText: String {
        dive.location.isEmpty
            ? String(localized: "Unknown Location")
            : dive.location
    }

    var durationText: String {
        let minutes = dive.diveTimeSeconds / 60
        let hours   = minutes / 60
        let mins    = minutes % 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, mins)
        } else {
            return String(format: "%d min", mins)
        }
    }

    var gasMixText: String {
        gasMixDisplayName(dive.gasMixJSON)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // ── 左側：日期區塊 ──────────────────────────
            dateBlock

            // ── 分隔線 ─────────────────────────────────
            Rectangle()
                .fill(Color.accentColor.opacity(0.35))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)

            // ── 右側：潛水資訊 ─────────────────────────
            diveInfo

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.12)
                : Color.platformSecondaryGroupedBackground
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        // 選取時在卡片邊框畫 accent 框（與圓角完全對齊，取代 List 偏移粗藍框）
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        // WCAG: 整張卡片作為可點選元素
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Sub-views

    private var dateBlock: some View {
        VStack(spacing: 1) {
            Text(dive.dateTime, format: .dateTime.day())
                .font(.title2.bold())
                .monospacedDigit()

            Text(dive.dateTime, format: .dateTime.month(.abbreviated))
                .font(.caption.uppercaseSmallCaps())
                .foregroundStyle(.secondary)

            Text(dive.dateTime, format: .dateTime.year())
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 46)
    }

    private var diveInfo: some View {
        VStack(alignment: .leading, spacing: 5) {
            // 地點
            Label(locationText, systemImage: "location.fill")
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            // 主要數據：深度 + 時間
            // 注意：使用明確 HStack{Image+Text} 取代 Label()，
            // 避免 Label 在 NavigationLink+List 環境下只渲染 icon 不渲染 title 的 SwiftUI 渲染問題
            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.to.line")
                    Text(String(format: "%.1f m", dive.maxDepth))
                }
                .font(.callout.bold())
                .foregroundStyle(.tint)
                .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "timer")
                    Text(durationText)
                }
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(1)
            }

            // 次要數據：水溫 + 氣體
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "thermometer.medium")
                    Text(String(format: "%.0f°C", dive.waterTemperature))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                Text(gasMixText)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let dateStr = dateFormatter.string(from: dive.dateTime)
        return "\(dateStr), \(locationText), \(String(format: "%.1f", dive.maxDepth)) metres, \(durationText)"
    }

    // MARK: - Gas Mix Helpers

    private func gasMixDisplayName(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let gasMix = try? JSONDecoder().decode(GasMix.self, from: data) else {
            return String(localized: "Air")
        }
        switch gasMix {
        case .air:
            return String(localized: "Air")
        case .nitrox(let fO2):
            return String(format: "EANx%d", Int(fO2 * 100))
        case .trimix(let fO2, let fHe):
            return String(format: "Tx%.0f/%.0f", fO2 * 100, fHe * 100)
        }
    }
}

#Preview {
    let dive = DiveLog(
        dateTime: Date(),
        location: "Small Island, Komodo",
        maxDepth: 52.3,
        diveTimeSeconds: 5640,
        gasMixJSON: "\"air\"",
        waterTemperature: 28.0
    )
    return List {
        DiveRowView(dive: dive)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
    .listStyle(.plain)
}
