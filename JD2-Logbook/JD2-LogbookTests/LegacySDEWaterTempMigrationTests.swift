// LegacySDEWaterTempMigrationTests.swift — JD2-LogbookTests
// v1.3（PM 2026-10-06 裁示 A）：舊版 SDE 匯入存成 0 °C 的水溫，首次啟動改為「未記錄」，只跑一次。
// 依據：`_JD2-family/decisions/2026-10-06_匯入格式全面稽核與DIK-v0.7.3修正計畫.md` §十三。

import XCTest
import Foundation
import SwiftData
@testable import JoyDive_

@MainActor
final class LegacySDEWaterTempMigrationTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "LegacySDEWaterTempMigrationTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([DiveLog.self])
        let container = try ModelContainer(for: schema,
                                           configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    private func insert(_ context: ModelContext, format: String, temp: Double?) -> DiveLog {
        let log = DiveLog(dateTime: Date(), location: format, maxDepth: 20, diveTimeSeconds: 2400, waterTemperature: temp)
        log.sourceFormat = format
        context.insert(log)
        return log
    }

    /// 只改 `suunto-sde` 且恰為 0 的紀錄；其他格式的 0、SDE 的非 0、nil 都不動。
    func testOnlySDEZeroBecomesNil() throws {
        let context = try makeContext()
        let sdeZero = insert(context, format: "suunto-sde", temp: 0)
        let sdeReal = insert(context, format: "suunto-sde", temp: 24)
        let sdeNil = insert(context, format: "suunto-sde", temp: nil)
        let uddfZero = insert(context, format: "uddf", temp: 0)
        let manualZero = insert(context, format: "manual", temp: 0)
        try context.save()

        let fixed = DiveLogDatabase.migrateLegacySDEZeroWaterTemperature(context: context, defaults: defaults)

        XCTAssertEqual(fixed, 1)
        XCTAssertNil(sdeZero.waterTemperature)
        XCTAssertEqual(sdeReal.waterTemperature, 24)
        XCTAssertNil(sdeNil.waterTemperature)
        XCTAssertEqual(uddfZero.waterTemperature, 0, "非 SDE 的 0 °C 不在裁示範圍")
        XCTAssertEqual(manualZero.waterTemperature, 0, "使用者手動輸入的 0 °C 不得被改")
        XCTAssertTrue(defaults.bool(forKey: DiveLogDatabase.sdeZeroTempMigrationKey))
    }

    /// 跑過一次後不再執行：之後使用者手動把 SDE 紀錄改成 0 °C 也不會被清掉。
    func testRunsOnlyOnce() throws {
        let context = try makeContext()
        XCTAssertEqual(DiveLogDatabase.migrateLegacySDEZeroWaterTemperature(context: context, defaults: defaults), 0)

        let later = insert(context, format: "suunto-sde", temp: 0)
        try context.save()
        XCTAssertNil(DiveLogDatabase.migrateLegacySDEZeroWaterTemperature(context: context, defaults: defaults))
        XCTAssertEqual(later.waterTemperature, 0)
    }
}
