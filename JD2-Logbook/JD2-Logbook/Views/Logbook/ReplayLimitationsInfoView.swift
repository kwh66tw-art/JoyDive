// ReplayLimitationsInfoView.swift — JD2-Logbook/Views/Logbook/
//
// 組織負荷重放的說明頁（提示列「Limited support ⓘ」與組織負荷區塊 ⓘ 的目的地）。
// PM 2026-10-05：只正面說明支援範圍、精簡；不列逐項排除清單、不提其他 App。
// 字串一律走 `languageManager.localized(_:)`（App 內語言切換即時生效）。

import SwiftUI

struct ReplayLimitationsInfoView: View {
    @Environment(AppLanguageManager.self) private var languageManager
    @Environment(\.dismiss) private var dismiss

    // PM 2026-10-05 晚：只留一段（原第 1、2 條合併）；GF High、建模保守度揭露、「其他潛水僅顯示剖面」三條移除。
    private let lines = [
        "Tissue loading uses the Bühlmann ZHL-16C model to calculate reference values for recreational scuba dives. Repetitive dives in the same series include residual nitrogen from the earlier dives.",
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
        #if os(macOS)
        // macOS 的 sheet 不會替 List 撐出高度，沒有這行內容會被壓成 0（PM 10/07 回報 ⓘ 視窗空白）。尺寸為本專案決定。
        .frame(minWidth: 420, minHeight: 240)
        #endif
        .accessibilityIdentifier("replayLimitationsInfo")
    }
}
