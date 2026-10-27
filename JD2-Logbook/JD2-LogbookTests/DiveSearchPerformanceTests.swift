// DiveSearchPerformanceTests.swift — JD2-LogbookTests
// v1.4 稽核 T26（F9，`docs/V1_4_AUDIT_TEST_PLAN.md`）：A2 搜尋每次按鍵都對全部紀錄解析一次 `importExtrasJSON`。
// 2,000 筆（含 extras）、從 SwiftData 取出（同列表 `@Query` 的物件），逐字輸入時量 `filteredDives` 同一個 filter 的耗時。
//
// 目標：每次按鍵 < 16 ms（一幀）——**門檻為本專案決定**（60 Hz 一幀），不是外部規範。
// 本測試**只記錄數字、不以門檻判紅綠**（模擬器負載會讓計時抖動）；超過門檻時回報 PM，不自行加快取（稽核計劃 T26）。
// 取數：以 `TEST_RUNNER_JD2_T18_OUT=<主機路徑>` 執行時另寫一份報告。
// ⚠️ 量的是 Debug build（測試預設），Release 通常更快 ⇒ 這是偏保守的數字。

import XCTest
import Foundation
import SwiftData
@testable import JoyDive_

@MainActor
final class DiveSearchPerformanceTests: XCTestCase {

    func testFilterTimePerKeystrokeWith2000Dives() throws {
        let container = try ModelContainer(for: DiveLog.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let sites = ["Green Island", "Kenting", "Orchid Island", "Xiaoliuqiu", "Okinawa"]
        let buddies = ["Amy Chen", "Ben", "Dirk, Linus", "Tomaz", ""]
        for i in 0..<2000 {
            let dive = DiveLog(dateTime: Date(timeIntervalSince1970: 1_600_000_000 + Double(i) * 3600),
                               location: "\(sites[i % sites.count]) #\(i)", maxDepth: 18, diveTimeSeconds: 2400)
            dive.notes = i % 3 == 0 ? "Saw a turtle near the wall, current mild" : ""
            var extras = ["diveComputerSerial": "SN\(i)", "firmware": "1.2.\(i % 10)",
                          "diveNumber": "\(i)", "gasMixConfidence": "confirmed"]
            if !buddies[i % buddies.count].isEmpty { extras["buddy"] = buddies[i % buddies.count] }
            if i % 4 == 0 { extras["tags"] = "wreck, night" }
            dive.importExtrasJSON = String(data: try JSONEncoder().encode(extras), encoding: .utf8)!
            context.insert(dive)
        }
        try context.save()
        let dives = try context.fetch(FetchDescriptor<DiveLog>(sortBy: [SortDescriptor(\.dateTime, order: .reverse)]))
        XCTAssertEqual(dives.count, 2000)

        // 逐字輸入：兩個查詢——一個命中地點（多數筆提早結束）、一個只命中潛伴（每筆都要解析 extras，最壞情況）。
        var report = "T26 filter time per keystroke (2000 dives, Debug)\n"
        var worstMs = 0.0
        for query in ["Green Isl", "linus"] {
            for length in 1...query.count {
                let prefix = String(query.prefix(length))
                let clock = ContinuousClock()
                var matched = 0
                let elapsed = clock.measure {
                    matched = dives.filter { $0.matchesSearch(prefix) }.count
                }
                let ms = Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1000
                worstMs = max(worstMs, ms)
                report += String(format: "  %-10@ matched=%4d  %.2f ms\n", prefix as NSString, matched, ms)
            }
        }
        report += String(format: "  worst = %.2f ms (target < 16 ms, 本專案決定)\n", worstMs)

        // 對照：A2 前的比對（只有地點＋備註、不解析 extras），同一批物件、同一個最壞查詢——分出 A2 新增的成本。
        let clock = ContinuousClock()
        let baseline = clock.measure {
            _ = dives.filter { $0.location.localizedCaseInsensitiveContains("linus")
                || $0.notes.localizedCaseInsensitiveContains("linus") }.count
        }
        let extrasOnly = clock.measure { _ = dives.map { $0.importExtras.count } }
        let msOf = { (d: Duration) in Double(d.components.attoseconds) / 1e15 + Double(d.components.seconds) * 1000 }
        report += String(format: "  baseline (location+notes only, pre-A2) linus = %.2f ms\n", msOf(baseline))
        report += String(format: "  importExtras decode only x2000 = %.2f ms\n", msOf(extrasOnly))
        XCTAssertEqual(dives.filter { $0.matchesSearch("linus") }.count, 400, "潛伴 Dirk, Linus 每 5 筆一筆")
        if let out = ProcessInfo.processInfo.environment["JD2_T18_OUT"], !out.isEmpty {
            try? report.write(toFile: out, atomically: true, encoding: .utf8)
        }
    }
}
