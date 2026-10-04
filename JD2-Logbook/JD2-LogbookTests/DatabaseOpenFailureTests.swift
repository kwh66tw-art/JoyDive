// DatabaseOpenFailureTests.swift — JD2-LogbookTests
// v1.3 P0-1／D2（PM 2026-10-04 核准）：資料庫打不開時不得閃退、不得刪除或覆寫磁碟上的資料檔。
//
// 背景：原本 `DiveLogDatabase.init` 開資料庫失敗即 `fatalError` ⇒ 升級失敗的使用者每次開 App 都閃退。
// v1.2 → v1.3 的升級已於 2026-10-04 實測通過（模擬器：v1.2 建 105 筆 → 覆蓋安裝 v1.3 → 指紋逐欄相同），
// 本檔守的是「萬一還是打不開」時的行為：開檔失敗 ⇒ 回報錯誤、資料檔位元組不變、記憶體內備援可用。
// 計劃：`docs/V1_3_WORK_PLAN.md` P0-1。

import XCTest
import Foundation
import SwiftData
@testable import JoyDive_

@MainActor
final class DatabaseOpenFailureTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DatabaseOpenFailureTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    /// 損毀的資料檔 ⇒ 開檔回報失敗（不閃退），且資料檔**位元組完全不變**（沒有被刪除、重建或覆寫）。
    func testCorruptStoreReportsFailureAndLeavesFileUntouched() throws {
        let storeURL = tempDir.appendingPathComponent("corrupt.store")
        let garbage = Data(repeating: 0x5A, count: 4096)
        try garbage.write(to: storeURL)

        let schema = Schema([DiveLog.self])
        let config = ModelConfiguration(schema: schema, url: storeURL, allowsSave: true)
        let result = DiveLogDatabase.openPersistentContainer(schema: schema, configuration: config)

        guard case .failure = result else {
            return XCTFail("損毀的資料檔應回報開檔失敗，實際卻成功開啟")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path), "資料檔不得被刪除")
        XCTAssertEqual(try Data(contentsOf: storeURL), garbage, "資料檔內容不得被覆寫或重建")
    }

    /// 正常的新路徑 ⇒ 開檔成功（反向驗證：上一支的失敗不是因為函式本身壞掉）。
    func testFreshStoreOpensSuccessfully() throws {
        let storeURL = tempDir.appendingPathComponent("fresh.store")
        let schema = Schema([DiveLog.self])
        let config = ModelConfiguration(schema: schema, url: storeURL, allowsSave: true)
        guard case .success = DiveLogDatabase.openPersistentContainer(schema: schema, configuration: config) else {
            return XCTFail("全新的資料檔路徑應可開啟")
        }
    }

    /// 開檔失敗時的記憶體內備援：可正常建立、只在記憶體、不碰任何磁碟路徑。
    func testInMemoryFallbackIsUsable() throws {
        let container = DiveLogDatabase.inMemoryFallback(schema: Schema([DiveLog.self]))
        XCTAssertTrue(container.configurations.allSatisfy { $0.isStoredInMemoryOnly })
        let context = container.mainContext
        context.insert(DiveLog(dateTime: Date(), location: "test", maxDepth: 10, diveTimeSeconds: 600))
        XCTAssertNoThrow(try context.save())
    }
}
