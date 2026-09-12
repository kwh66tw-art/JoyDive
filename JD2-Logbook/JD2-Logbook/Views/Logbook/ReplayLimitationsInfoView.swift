// ReplayLimitationsInfoView.swift — JD2-Logbook/Views/Logbook/
//
// 互動剖面／組織艙重放的限制說明頁（提示列與組織艙區塊的 ⓘ 目的地）。
//
// 🔑 **為什麼要「全部羅列」而不是只講這次那一條**（PM 2026-09-12 裁示 4.5）：
//   · 使用者在一筆潛水上看到「不支援」，第一個問題是「那我哪些潛水會這樣」——
//     只講這一條答不了，他得自己一筆一筆試。
//   · 但全部羅列又有反效果：8 條裡要自己對號入座。⇒ **同時標出「本次適用」**
//     （`activeAnomaly`），成本很低。
//
// 🔴 下方兩項「一般性限制」與異常無關，**重放完全正常時同樣成立**，所以這一頁的
// 入口不能只在異常時出現（見 `DiveAnalysisView.hintRow`）。
//
// 文案定版：`../_JD2-family/decisions/2026-09-12_重放異常的文案細分與UI重新設計-PM裁示.md`
// ⚠️ 該檔取代 `V1_2_BACKLOG.md` #24 的 2026-08-22 定版。

// ⚠️ 本檔所有字串一律走 `languageManager.localized(_:)`，不用 `Text("字面量")`
// ——後者讀系統 Locale，App 內語言切換器切換後不重開 App 會殘留舊語言（v1.2 #17
// 同一個 bug 已在別處修過一輪）。

import SwiftUI
import DiveKit

struct ReplayLimitationsInfoView: View {
    /// 本次這筆潛水觸發的異常；nil ⇒ 重放正常（只標一般性限制）
    let activeAnomaly: DiveReplayEngine.Anomaly?

    @Environment(AppLanguageManager.self) private var languageManager
    @Environment(\.dismiss) private var dismiss

    /// 羅列順序＝`DiveReplayEngine.Anomaly` 的宣告順序，讓兩邊好對照。
    /// 🔴 **不要在這裡重新分類成 A/B/C 三組**：分類只決定
    /// `DiveAnalysisView` 那一句用 available 還是 applicable，
    /// 這一頁是「所有情況的清單」，多一層分組只會讓使用者多一層要理解的東西。
    private enum Item: String, CaseIterable {
        case technicalDive
        case unknownGasMix
        case overlappingDives
        case implausibleTiming
        case seriesIndexMismatch
        case precedingProfileSamplesMissing
        case breathHoldTarget
        case inconsistentEnvironment

        var textKey: String {
            switch self {
            case .technicalDive:
                return "Technical dive: replay models a single gas for the whole dive, so multi-gas and rebreather profiles are excluded."
            case .unknownGasMix:
                return "The gas mix could not be determined from the imported record."
            case .overlappingDives:
                return "Two records cover the same clock time — two devices on one dive, or a duplicate import."
            case .implausibleTiming:
                return "The record's own timing is implausible, such as a zero-length duration or an invalid timestamp."
            case .seriesIndexMismatch:
                return "The device's dive-series number does not match the order rebuilt from the timestamps."
            case .precedingProfileSamplesMissing:
                return "An earlier dive in the same series has no depth profile, so its remaining nitrogen cannot be replayed."
            case .breathHoldTarget:
                return "Breath-hold dive: the model assumes continuous breathing at depth, so it does not apply."
            case .inconsistentEnvironment:
                return "An earlier dive in the series used a different surface pressure or water type, so remaining nitrogen cannot be carried over."
            }
        }

        /// Kit 的 `Anomaly` 帶 payload（chainIndex 等）⇒ 不能直接比對相等，用 switch。
        init(_ anomaly: DiveReplayEngine.Anomaly) {
            switch anomaly {
            case .technicalDive:                   self = .technicalDive
            case .unknownGasMix:                   self = .unknownGasMix
            case .overlappingDives:                self = .overlappingDives
            case .implausibleTiming:               self = .implausibleTiming
            case .seriesIndexMismatch:             self = .seriesIndexMismatch
            case .precedingProfileSamplesMissing:  self = .precedingProfileSamplesMissing
            case .breathHoldTarget:                self = .breathHoldTarget
            case .inconsistentEnvironment:         self = .inconsistentEnvironment
            }
        }
    }

    private var activeItem: Item? { activeAnomaly.map(Item.init) }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(verbatim: languageManager.localized("When tissue loading cannot be shown"))) {
                    ForEach(Item.allCases, id: \.rawValue) { item in
                        row(text: languageManager.localized(item.textKey),
                            isActive: item == activeItem)
                    }
                }

                // 一般性限制：**與本次是否異常無關，永遠成立**。文案沿用既有 key
                // （已有 18 語翻譯），不另造新句——同一件事兩種說法會讓翻譯校對
                // 與術語一致性檢查各自維護一份。
                Section(header: Text(verbatim: languageManager.localized("Always applies"))) {
                    row(text: languageManager.localized("Replay is simulated using the conservative GF High ceiling baseline, so the ceiling shown may be more optimistic (shallower) than what your dive computer displayed at the time."),
                        isActive: false)
                    row(text: languageManager.localized("This app can't read the original device's dive-series index, so replay-anomaly detection here has narrower coverage than in ultra or immersion."),
                        isActive: false)
                }
            }
            .navigationTitle(Text(verbatim: languageManager.localized("Interactive Profile Limitations")))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) { Text(verbatim: languageManager.localized("Done")) }
                }
            }
        }
        .accessibilityIdentifier("replayLimitationsInfo")
    }

    private func row(text: String, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if isActive {
                // 只標「本次適用」，不加重風險色彩——加重視覺權重本身隱含風險提示，
                // 而那需要可查證出處（PM 2026-09-12 裁示 4：C 類暫定同樣低調）。
                Text(verbatim: languageManager.localized("Applies to this dive"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(verbatim: text)
                .font(.footnote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
