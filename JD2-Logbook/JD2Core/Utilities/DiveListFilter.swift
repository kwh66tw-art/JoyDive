// DiveListFilter.swift — JD2Core/Utilities
// v1.4 A3（PM 2026-11-01）：潛水列表篩選——氣體、潛水類型、組織負荷。
// 規格（App-u 亦照此做）：`docs/decisions/D-2026-11-01-A3-列表篩選規格.md`。
// 同一類多選 OR、不同類 AND；與搜尋再 AND（在 `DiveLogListView`）。統計列與地圖不跟篩選（D5）。

import Foundation
import SwiftData
import DiveKit

/// 篩選用的氣體分類。**與列表那一列的氣體標籤同源**（`DiveLog.displayGasMix`）。
enum DiveGasCategory: String, CaseIterable, Hashable, Sendable {
    case air, nitrox, trimix, unknown

    /// 選項文字的字串鍵（`Air`／`Nitrox`／`Unknown Gas` 既有；`Trimix` 譯文取 F-10 `trimix` 條目）。
    var labelKey: String {
        switch self {
        case .air:     return "Air"
        case .nitrox:  return "Nitrox"
        case .trimix:  return "Trimix"
        case .unknown: return "Unknown Gas"
        }
    }
}

/// 組織負荷分類：詳細頁實際有沒有畫出組織負荷（判定見 `TissueLoadingSupport`）。
enum TissueLoadingCategory: String, CaseIterable, Hashable, Sendable {
    case available, unavailable

    var labelKey: String {
        switch self {
        case .available:   return "With Tissue Loading"
        case .unavailable: return "No Tissue Loading"
        }
    }
}

extension DiveLogMode {
    /// 選項文字的字串鍵（與編輯頁同一批鍵，F-10 `scuba`／`freedive`／`snorkel`）。
    var labelKey: String {
        switch self {
        case .scuba:   return "Scuba"
        case .free:    return "Freedive"
        case .snorkel: return "Snorkel"
        }
    }
}

extension DiveLog {
    /// 氣體分類；閉氣潛水（自由潛水／浮潛）回 nil——列表本來就不顯示它們的氣體（`showsGas`），不屬於任何氣體選項。
    var gasCategory: DiveGasCategory? {
        guard showsGas else { return nil }
        switch displayGasMix {
        case .air?:     return .air
        case .nitrox?:  return .nitrox
        case .trimix?:  return .trimix
        case nil:       return .unknown
        }
    }
}

struct DiveListFilter: Equatable {
    var gases: Set<DiveGasCategory> = []
    var modes: Set<DiveLogMode> = []
    var tissue: Set<TissueLoadingCategory> = []

    var isActive: Bool { !gases.isEmpty || !modes.isEmpty || !tissue.isEmpty }
    var needsTissueJudgement: Bool { !tissue.isEmpty }

    /// - Parameter tissueSupported: 這筆的組織負荷判定；nil＝還沒算出來。
    ///   有組織負荷條件時，**還沒算出來的紀錄不顯示**（只顯示算好的正確結果，不先猜）。
    func matches(_ dive: DiveLog, tissueSupported: Bool?) -> Bool {
        if !gases.isEmpty {
            guard let gas = dive.gasCategory, gases.contains(gas) else { return false }
        }
        if !modes.isEmpty, !modes.contains(dive.diveModeValue) { return false }
        if !tissue.isEmpty {
            guard let supported = tissueSupported else { return false }
            if !tissue.contains(supported ? .available : .unavailable) { return false }
        }
        return true
    }

    /// 只列資料裡實際存在的選項（組織負荷兩項恆列——要跑過 Kit 才知道，先列出才不會跳動）。
    static func availableGases(in dives: [DiveLog]) -> [DiveGasCategory] {
        let present = Set(dives.compactMap(\.gasCategory))
        return DiveGasCategory.allCases.filter(present.contains)
    }

    static func availableModes(in dives: [DiveLog]) -> [DiveLogMode] {
        let present = Set(dives.map(\.diveModeValue))
        return DiveLogMode.allCases.filter(present.contains)
    }

    /// 已勾選但資料裡已不存在的選項自動取消，不留下看不見的條件。
    func pruned(gases availableGases: [DiveGasCategory], modes availableModes: [DiveLogMode]) -> DiveListFilter {
        var copy = self
        copy.gases.formIntersection(availableGases)
        copy.modes.formIntersection(availableModes)
        return copy
    }
}
