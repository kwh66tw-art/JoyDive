// DiveRowView.swift — JD2-Logbook/Views/Logbook/
// Week 9 — 潛水日誌列表卡片元件

import SwiftUI
import DiveKit

struct DiveRowView: View {
    let dive: DiveLog
    /// macOS：是否為目前選取的卡片（畫在卡片邊框上，取代 List 系統選取框）
    var isSelected: Bool = false

    // v1.2 #4：公制／英制單位系統，儲存值永遠是公制，這裡只負責顯示層換算。
    @AppStorage(UnitSystem.storageKey) private var unitSystem = UnitSystem.metric

    // ⚠️ languageManager.localized(_:) 而非 String(localized:)：這裡回傳的是 String
    // （餵給 accessibility label 等），String(localized:) 讀系統 Locale，語言切換後
    // 不重開 App 會殘留舊語言，同 DiveSiteSheetView 那個 bug。
    @Environment(AppLanguageManager.self) private var languageManager

    // MARK: - Computed properties

    var locationText: String {
        dive.location.isEmpty
            ? languageManager.localized("Unknown Location")
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

    /// 縮寫月份語系：
    /// - CJK（中/日/韓）：年月日習慣，「3月」「3월」提供文化標記
    /// - English：M/D/Y 與 D/M/Y 習慣混用，「Mar」消除數字歧義
    /// - Thai：有自己月份縮寫（ม.ค. / ก.พ. 等），字短不折行，保留本地習慣
    /// - 其餘（歐洲、越南等）：日/月/年習慣，純數字已足夠清楚
    private var useAbbreviatedMonth: Bool {
        let code = languageManager.locale.language.languageCode?.identifier ?? ""
        return ["zh", "ja", "ko", "en", "th"].contains(code)
    }

    private var dateBlock: some View {
        VStack(spacing: 1) {
            // 純數字日期，避免 CJK「日」/「일」後綴在 46pt 框內折行
            Text(String(Calendar.current.component(.day, from: dive.dateTime)))
                .font(.title2.bold())
                .monospacedDigit()

            // CJK + 英文：縮寫月份；其他語系：純數字
            // 用 accessibleSecondary 不用系統 .secondary：Dark Mode 真機截圖用 WCAG
            // 公式實測 .secondary 在這個 caption 字級只有 3.91:1，低於 4.5:1 門檻
            // （2026-06-01 稽核已在 DetailRow/StatsHeader 等處修過同款問題，這個
            // dateBlock 當時漏掉，2026-07-27 模擬器像素取色複查抓到）。
            if useAbbreviatedMonth {
                Text(dive.dateTime, format: .dateTime.month(.abbreviated))
                    .font(.caption.uppercaseSmallCaps())
                    .foregroundStyle(Color.accessibleSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text(String(Calendar.current.component(.month, from: dive.dateTime)))
                    .font(.caption.uppercaseSmallCaps())
                    .foregroundStyle(Color.accessibleSecondary)
            }

            // 純數字年份，避免各語系「年」後綴折行
            Text(String(Calendar.current.component(.year, from: dive.dateTime)))
                .font(.caption2)
                .foregroundStyle(Color.accessibleSecondary)
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
                    Text(unitSystem.formatDepth(dive.maxDepth))
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
                    Text(unitSystem.formatTemperature(dive.waterTemperature))
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
        let dateStr = languageManager.dateFormatter(dateStyle: .medium).string(from: dive.dateTime)
        return "\(dateStr), \(locationText), \(unitSystem.formatDepth(dive.maxDepth)), \(durationText)"
    }

    // MARK: - Gas Mix Helpers

    private func gasMixDisplayName(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let gasMix = try? JSONDecoder().decode(GasMix.self, from: data) else {
            return languageManager.localized("Air")
        }
        return gasMix.localizedDisplayName(languageManager)
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
