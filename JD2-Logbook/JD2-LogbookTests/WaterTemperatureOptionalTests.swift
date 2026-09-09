// WaterTemperatureOptionalTests.swift — JD2-LogbookTests
// C2（2026-09-07）：水溫 optional 化——App 層測試。
//
// 權威裁示：`_JD2-family/decisions/2026-09-07_PM裁示-水溫序列與摘要分層處理.md`。
// Kit 側（DiveImportKit）的「摘要＝真實樣本 min，零真實值→nil」邏輯已在 Kit 自己的
// `WaterTemperatureOptionalTests`（9 支）覆蓋，不在本檔重複。本檔只驗證 App 層
// 自己的三個責任範圍，逐一對應派工單「新增測試」四項要求的前三項：
//   ① 整趟/整筆無溫度 ⇒ 摘要 nil、顯示留空
//   ② 部分有溫度 ⇒ 摘要＝真實值（本檔驗證 App 層「原樣傳遞 Kit 算好的摘要，不
//      重新填入編造值」；真正的「取 min」計算屬 Kit 責任，已由 Kit 側測試覆蓋）
//   ③ 表單不填水溫 ⇒ 存 nil
// 第④項（Premium 價格未載入不出現任何幣別數字）見 PurchasePriceDisplayTests.swift。
//
// 本檔案刻意不 `import DiveImportKit`（原因與 DiveImportKitAdapterRoundtripDedupeTests
// 檔頭記載一致：macOS destination 的 explicit module build 下會出現
// `unable to resolve module dependency` 錯誤），改用 `DiveImportKitAdapter.swift`
// 內的 `makeTestParsedDiveLog(...)` 測試專用建構器（本次為它新增 waterTemperature
// 參數，預設 nil）。

import XCTest
import Foundation
@testable import JoyDive_

final class WaterTemperatureOptionalTests: XCTestCase {

    // MARK: - ①②「摘要」在 App 層 adapter（makeDiveLog(from:)）原樣傳遞，不回填假值

    /// 零個真實溫度樣本（Kit 已算出 nil）⇒ App 層 `makeDiveLog(from:)` 必須把 nil
    /// 原樣傳進 `DiveLog.waterTemperature`，不得用 `?? 15.0` 之類的邏輯補回一個數字
    /// （C1 之前的 `DiveImportKitAdapter.swift:36` 正是這種曾經編譯不過、被迫補
    /// 假值的位置——見 `decisions/2026-09-07_C1_水溫optional化-Kit側結果.md` 5.1）。
    func testImportedDiveWithNoRealTemperatureSamplesResultsInNilSummary() throws {
        let parsed = makeTestParsedDiveLog(
            dateTime: Date(timeIntervalSince1970: 1_700_000_000),
            location: "No Temp Site",
            maxDepth: 18.0,
            diveTimeSeconds: 1800,
            roundtripID: nil,
            waterTemperature: nil
        )
        let dive = makeDiveLog(from: parsed)
        XCTAssertNil(dive.waterTemperature,
            "零個真實溫度樣本時，摘要必須是 nil，不得回填任何假數字")
    }

    /// 有真實溫度樣本時（Kit 已算出「真實值的 min」，本測試用 24.5°C 代表該計算結果），
    /// App 層 adapter 必須原封不動傳遞，不得覆寫或四捨五入成其他常數。
    func testImportedDiveWithRealTemperatureResultsInThatSummaryValue() throws {
        let parsed = makeTestParsedDiveLog(
            dateTime: Date(timeIntervalSince1970: 1_700_000_000),
            location: "Real Temp Site",
            maxDepth: 18.0,
            diveTimeSeconds: 1800,
            roundtripID: nil,
            waterTemperature: 24.5
        )
        let dive = makeDiveLog(from: parsed)
        XCTAssertEqual(dive.waterTemperature, 24.5,
            "有真實溫度樣本時，摘要應等於 Kit 算出的值，App 層不得覆寫")
    }

    // MARK: - ③ 手動新增日誌：不填水溫 ⇒ 存 nil
    //
    // `DiveLogEditSheet` 是 SwiftUI View，本專案沒有 view-inspection 測試設施，
    // 無法直接驅動 `@State`/`save()`。改為鎖定它實際依賴的模型層契約：
    // `.new` 模式下 `_waterTemperature = State(initialValue: nil)`
    // （`DiveLogEditSheet.swift:101`），`save()` 呼叫 `DiveLog(..., waterTemperature:
    // waterTemperature)`（`:726`）原樣把這個 `@State` 存回去——本測試驗證的正是
    // 這條路徑最終落地的那一步：`DiveLog` 初始化時省略/傳入 nil 應得到 nil，
    // 不像舊版 init 預設 `15.0` 那樣把「沒填」悄悄變成「填了 15.0」。

    func testDiveLogInitOmittingWaterTemperatureDefaultsToNil() {
        let dive = DiveLog(
            dateTime: Date(timeIntervalSince1970: 1_700_000_000),
            location: "Manual Entry",
            maxDepth: 20.0,
            diveTimeSeconds: 3600
            // waterTemperature 省略 —— 比照表單使用者「存檔前沒動過水溫欄位」
        )
        XCTAssertNil(dive.waterTemperature,
            "省略 waterTemperature 時應預設為 nil（C2 之前預設 15.0，屬編造值）")
    }

    func testDiveLogInitExplicitNilWaterTemperature() {
        // 對應表單 .new 模式的 @State 起始值（nil）直接存入的情況。
        let dive = DiveLog(
            dateTime: Date(timeIntervalSince1970: 1_700_000_000),
            location: "Manual Entry",
            maxDepth: 20.0,
            diveTimeSeconds: 3600,
            gasMixJSON: "\"air\"",
            waterTemperature: nil
        )
        XCTAssertNil(dive.waterTemperature)
    }

    // MARK: - 顯示層留空：三個唯讀顯示點與表單共用的 nil → "—" 樣式
    //
    // 直接測試 DiveRowView/DiveLogDetailView/DiveSiteSheetView 三處實際使用的運算式
    // `dive.waterTemperature.map { unitSystem.formatTemperature($0) } ?? "—"`
    // （沿用 DiveAnalysisView.calloutRow 既有的「—」佔位樣式，見派工單）。
    // 三處寫法邏輯完全相同，測一次代表三處。

    func testWaterTemperatureDisplayFormatFallsBackToDashWhenNil() {
        let dive = DiveLog(
            dateTime: Date(timeIntervalSince1970: 1_700_000_000),
            location: "Test",
            maxDepth: 20.0,
            diveTimeSeconds: 3600
        )
        // 🔴 2026-09-09 修正（稽核發現③）：本測試原本把 View 裡的運算式**重打一遍**
        // 再斷言自己那份拷貝——測試與生產是兩份獨立實作，改 View 對它零影響，
        // 注入編造值時 140 支全綠。現在改為呼叫生產程式碼實際使用的具名函式。
        let unitSystem = UnitSystem.metric
        XCTAssertEqual(
            WaterTemperatureDisplay.rowValue(dive.waterTemperature, unitSystem: unitSystem),
            "—",
            "未記錄水溫時必須顯示佔位符，不得顯示任何編造的度數"
        )
    }

    func testWaterTemperatureDisplayFormatShowsValueWhenPresent() {
        let dive = DiveLog(
            dateTime: Date(timeIntervalSince1970: 1_700_000_000),
            location: "Test",
            maxDepth: 20.0,
            diveTimeSeconds: 3600,
            gasMixJSON: "\"air\"",
            waterTemperature: 24.0
        )
        let unitSystem = UnitSystem.metric
        let displayed = dive.waterTemperature.map { unitSystem.formatTemperature($0) } ?? "—"
        XCTAssertNotEqual(displayed, "—")
        XCTAssertTrue(displayed.contains("24"), "應顯示真實量測值，非佔位符")
    }

    // MARK: - 備份 round-trip：nil 水溫也要能正確還原（DiveLogBackupEntry）

    func testDiveLogBackupEntryRoundTripsNilWaterTemperature() {
        let original = DiveLog(
            dateTime: Date(timeIntervalSince1970: 1_700_000_000),
            location: "Backup Test",
            maxDepth: 15.0,
            diveTimeSeconds: 1200
            // waterTemperature 省略 → nil
        )
        let entry = DiveLogBackupEntry(from: original)
        XCTAssertNil(entry.waterTemperature, "備份 DTO 應保留 nil，不回填假值")

        let restored = entry.makeDiveLog()
        XCTAssertNil(restored.waterTemperature, "還原後仍應是 nil")
    }

    func testDiveLogBackupJSONRoundTripPreservesNilWaterTemperature() throws {
        let dive = DiveLog(
            dateTime: Date(timeIntervalSince1970: 1_700_000_000),
            location: "Backup JSON Test",
            maxDepth: 15.0,
            diveTimeSeconds: 1200
        )
        let backup = DiveLogBackup(appVersion: "test", dives: [DiveLogBackupEntry(from: dive)])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DiveLogBackup.self, from: data)

        XCTAssertEqual(decoded.dives.count, 1)
        XCTAssertNil(decoded.dives[0].waterTemperature,
            "JSON round-trip（匯出/匯入備份檔）不應把 nil 憑空變成一個數字")
    }

    // MARK: - 統計格：數值與單位的 nil 規則必須一致（稽核發現③）

    func testStatCellShowsPlaceholderAndBlankUnitWhenNotRecorded() {
        let u = UnitSystem.metric
        XCTAssertEqual(
            WaterTemperatureDisplay.statValue(nil, unitSystem: u, locale: Locale(identifier: "en_US")),
            "—")
        XCTAssertEqual(
            WaterTemperatureDisplay.statUnit(nil, unitSystem: u), "",
            "未記錄時單位必須留空——否則畫面會顯示「— °C」，那是看起來像有讀數的組合")
    }

    func testStatCellShowsValueAndUnitWhenRecorded() {
        let u = UnitSystem.metric
        XCTAssertEqual(
            WaterTemperatureDisplay.statValue(28.0, unitSystem: u, locale: Locale(identifier: "en_US")),
            "28")
        XCTAssertFalse(
            WaterTemperatureDisplay.statUnit(28.0, unitSystem: u).isEmpty,
            "有讀數時單位不得留空")
    }
}
