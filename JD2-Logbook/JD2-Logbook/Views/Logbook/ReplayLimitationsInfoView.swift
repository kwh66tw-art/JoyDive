// ReplayLimitationsInfoView.swift — JD2-Logbook/Views/Logbook/
//
// 組織負荷重放的說明頁（提示列「Limited support ⓘ」與組織負荷區塊 ⓘ 的目的地）。
// PM 2026-10-05：只正面說明支援範圍、精簡；不列逐項排除清單、不提其他 App。
// 字串一律走 `languageManager.localized(_:)`（App 內語言切換即時生效）。

import SwiftUI

struct ReplayLimitationsInfoView: View {
    @Environment(AppLanguageManager.self) private var languageManager
    @Environment(\.dismiss) private var dismiss

    private let lines = [
        "Tissue loading uses the Bühlmann ZHL-16C model to calculate reference values for recreational scuba dives.",
        "Repetitive dives in the same series include residual nitrogen from the earlier dives.",
        "Ceilings are calculated at the GF High setting throughout the dive.",
        // PM 2026-10-03 定稿的建模揭露（F-20 節點 1），保留。
        "The Bühlmann decompression model used by this app tracks residual nitrogen between dives, but it does not add extra conservatism for repetitive or multi-day diving. Follow the more conservative of your dive computer and this app.",
        "Other dives show the depth profile only.",
    ]

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(verbatim: languageManager.localized("What tissue loading covers"))) {
                    ForEach(lines, id: \.self) { key in
                        Text(verbatim: languageManager.localized(key))
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .navigationTitle(Text(verbatim: languageManager.localized("About Tissue Loading")))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) { Text(verbatim: languageManager.localized("Done")) }
                }
            }
        }
        .accessibilityIdentifier("replayLimitationsInfo")
    }
}
