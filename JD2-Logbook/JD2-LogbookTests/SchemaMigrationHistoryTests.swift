// SchemaMigrationHistoryTests.swift — JD2-LogbookTests
// v1.4（PM 2026-10-26 裁示 A 方案）：每一個上架版本的 store 都要能用 App 的開檔路徑（含遷移計劃）打開。
// 背景：只列 v1.3 時，v1.2 store 直接裝 v1.4 ⇒ 開檔失敗（模擬器實測，`docs/V1_4_AUDIT_TEST_PLAN.md` T1）。
//
// ⚠️ 這裡的舊版 store 由 `DiveLogSchemaV1_x` 凍結拷貝寫出——它只證明「計劃涵蓋這份拷貝」。
// 拷貝是否等於當年上架的模型，靠模擬器用**當年 build** 實測（T1／T2／T3），兩者缺一不可。

import XCTest
import Foundation
import SwiftData
@testable import JoyDive_

@MainActor
final class SchemaMigrationHistoryTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SchemaMigrationHistoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func openWithAppPath(_ url: URL) throws -> [DiveLog] {
        let schema = Schema(versionedSchema: DiveLogSchemaV1_4.self)
        let result = DiveLogDatabase.openPersistentContainer(
            schema: schema, configuration: ModelConfiguration(schema: schema, url: url))
        guard case .success(let container) = result else {
            XCTFail("舊版 store 應可遷移到目前版本，實際：\(result)")
            throw XCTSkip("open failed")
        }
        return try ModelContext(container).fetch(FetchDescriptor<DiveLog>(sortBy: [SortDescriptor(\.dateTime)]))
    }

    /// v1.0 (Build 2) store → 目前版本：既有值保留；新增欄位取預設值（avgDepth 0、importExtras "{}"、diveMode scuba）。
    func testV1_0StoreMigratesToCurrent() throws {
        let url = tempDir.appendingPathComponent("v1_0.store")
        do {
            let schema = Schema(versionedSchema: DiveLogSchemaV1_0.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = ModelContext(container)
            let old = DiveLogSchemaV1_0.DiveLog(dateTime: Date(timeIntervalSince1970: 1_000), location: "v1.0",
                                                maxDepth: 18, diveTimeSeconds: 2400, waterTemperature: 26)
            old.environmentType = "altitude"
            old.surfacePressureBar = 1.0
            old.notes = "keep me"
            context.insert(old)
            try context.save()
        }
        let dives = try openWithAppPath(url)
        XCTAssertEqual(dives.count, 1)
        let dive = try XCTUnwrap(dives.first)
        XCTAssertEqual(dive.location, "v1.0")
        XCTAssertEqual(dive.waterTemperature, 26)
        XCTAssertEqual(dive.environmentType, "altitude", "既有值不得改寫")
        XCTAssertEqual(dive.notes, "keep me")
        XCTAssertEqual(dive.avgDepth, 0)
        XCTAssertEqual(dive.importExtrasJSON, "{}")
        XCTAssertEqual(dive.diveModeValue, .scuba)
        XCTAssertTrue(dive.isReplayBlockedByLegacyAltitude, "v1.0 的 altitude＋1.0 一樣走閘門")
    }

    /// v1.2 (Build 3) store → 目前版本。
    func testV1_2StoreMigratesToCurrent() throws {
        let url = tempDir.appendingPathComponent("v1_2.store")
        do {
            let schema = Schema(versionedSchema: DiveLogSchemaV1_2.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = ModelContext(container)
            let old = DiveLogSchemaV1_2.DiveLog(dateTime: Date(timeIntervalSince1970: 2_000), location: "v1.2",
                                                maxDepth: 14, diveTimeSeconds: 3000, waterTemperature: 15)
            old.environmentType = "freshwater"
            old.metersPerBar = 10.3
            old.avgDepth = 9
            old.importExtrasJSON = #"{"buddy":"Amy"}"#
            context.insert(old)
            try context.save()
        }
        let dives = try openWithAppPath(url)
        XCTAssertEqual(dives.count, 1)
        let dive = try XCTUnwrap(dives.first)
        XCTAssertEqual(dive.environmentType, "freshwater")
        XCTAssertEqual(dive.metersPerBar, 10.3)
        XCTAssertEqual(dive.avgDepth, 9)
        XCTAssertEqual(dive.waterTemperature, 15)
        XCTAssertTrue(dive.matchesSearch("amy"), "v1.2 匯入的潛伴遷移後可搜尋")
        XCTAssertEqual(dive.diveModeValue, .scuba)
    }
}
