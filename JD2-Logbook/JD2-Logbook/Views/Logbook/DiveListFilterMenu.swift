// DiveListFilterMenu.swift — JD2-Logbook/Views/Logbook/
// v1.4 A3（PM 2026-11-01）：列表篩選選單。iOS 放導覽列、macOS 放搜尋欄旁（`DiveLogListView`）。
// 篩選中按鈕改實心。放法與圖示為本專案決定（家族無前例，未引用設計規範原文）。
// 規格：`docs/decisions/D-2026-11-01-A3-列表篩選規格.md`。

import SwiftUI

struct DiveListFilterMenu: View {
    @Environment(AppLanguageManager.self) private var languageManager
    @Binding var filter: DiveListFilter
    /// 只列資料裡實際存在的選項（`DiveListFilter.availableGases/availableModes`）。
    let gases: [DiveGasCategory]
    let modes: [DiveLogMode]

    var body: some View {
        Menu {
            if !gases.isEmpty {
                Section(languageManager.localized("Gas")) {
                    ForEach(gases, id: \.self) { gas in
                        Toggle(languageManager.localized(gas.labelKey), isOn: binding(for: gas, in: \.gases))
                    }
                }
            }
            if !modes.isEmpty {
                Section(languageManager.localized("Dive Mode")) {
                    ForEach(modes, id: \.self) { mode in
                        Toggle(languageManager.localized(mode.labelKey), isOn: binding(for: mode, in: \.modes))
                    }
                }
            }
            Section(languageManager.localized("Tissue Loading")) {
                ForEach(TissueLoadingCategory.allCases, id: \.self) { category in
                    Toggle(languageManager.localized(category.labelKey), isOn: binding(for: category, in: \.tissue))
                }
            }
            if filter.isActive {
                Section {
                    Button(languageManager.localized("Clear Filters"), role: .destructive) {
                        filter = DiveListFilter()
                    }
                }
            }
        } label: {
            // v1.4（PM 11/05「比照 Apple HIG」）：工具列用無外框符號——HIG〈Toolbars〉"Prefer system-provided symbols
            // without borders … Borders (like outlined circle symbols) aren't necessary"。啟用中以強調色表示——
            // HIG〈SF Symbols〉"a toolbar takes the outline variant"、fill 適合 "places where you use an accent color to
            // communicate selection"；此符號無不帶外框的 fill 變體 ⇒ 只用強調色（本專案決定，取代 D-2026-11-01 的 .circle／.fill）。
            Image(systemName: "line.3.horizontal.decrease")
                .imageScale(.medium)
                .foregroundStyle(filter.isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        }
        #if os(iOS)
        .menuActionDismissBehavior(.disabled)   // 多選時選單不要每勾一項就關（macOS 無此選項）
        #endif
        .accessibilityLabel(languageManager.localized("Filter"))
        .help(languageManager.localized("Filter"))
        .accessibilityIdentifier("diveListFilterMenu")
    }

    private func binding<T: Hashable>(for value: T, in keyPath: WritableKeyPath<DiveListFilter, Set<T>>) -> Binding<Bool> {
        Binding(
            get: { filter[keyPath: keyPath].contains(value) },
            set: { isOn in
                if isOn { filter[keyPath: keyPath].insert(value) } else { filter[keyPath: keyPath].remove(value) }
            }
        )
    }
}
