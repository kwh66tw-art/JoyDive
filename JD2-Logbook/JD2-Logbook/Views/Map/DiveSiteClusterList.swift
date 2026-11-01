// DiveSiteClusterList.swift — JD2-Logbook/Views/Map/
// v1.4 B2（PM 2026-10-26，D7）：聚合點拆不開時（座標完全相同，或已到最大縮放仍聚合）列出該處的潛水，
// 點一筆進既有的 `DiveSiteSheetView`。iOS 放在地圖底部卡片、macOS 放在右側面板（`MapView`）。
// 不錯開圖釘：錯開會在地圖上顯示不存在的位置。

import SwiftUI

struct DiveSiteClusterList: View {
    @Environment(AppLanguageManager.self) private var languageManager
    @AppStorage(UnitSystem.storageKey) private var unitSystem: UnitSystem = .metric

    let dives: [DiveLog]
    let onSelect: (DiveLog) -> Void

    /// 新的在上（與日誌列表一致）。
    private var sortedDives: [DiveLog] { dives.sorted { $0.dateTime > $1.dateTime } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: languageManager.localized("Dives at This Site"))
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)

            List(sortedDives) { dive in
                Button { onSelect(dive) } label: { row(dive) }
                    .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
        .accessibilityIdentifier("diveSiteClusterList")
    }

    private func row(_ dive: DiveLog) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: dive.location.isEmpty ? languageManager.localized("Unknown Location") : dive.location)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(dive.dateTime.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened)
                    .locale(languageManager.locale)))
                    .font(.caption)
                    .foregroundStyle(Color.accessibleSecondary)
            }
            Spacer(minLength: 8)
            Text(verbatim: unitSystem.formatDepth(dive.maxDepth))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}
