// DiveImportKitAdapterRoundtripDedupeTests.swift — JD2-LogbookTests
// R-070 App 半（2026-09-03）：驗證 `DiveImportKitAdapter.dedupeAgainstExisting`
// 正確接上 round-trip 指紋 ID（`DiveImportKit.jd2RoundtripIDKey`），不再
// 100% 依賴地點/時間/深度模糊比對。
//
// 本檔案刻意不 `import DiveImportKit`：`DiveImportKitAdapter.swift` 檔頭明確
// 記載「本檔是全 App 唯一 import DiveImportKit 的檔案」，目的是讓該檔案內的
// `UDDFParser` 等同名 struct 靠 Swift 同模組遮蔽規則解析為本地薄包裝型別，不受
// Kit 同名型別干擾。實測發現：若本檔案也直接 `import DiveImportKit` 來建構
// `DiveImportKit.ParsedDiveLog` 測試資料，在 iOS Simulator 目的地一切正常，
// 但在 macOS（`-destination platform=macOS`）目的地的 explicit module build
// 下會穩定重現 `error: unable to resolve module dependency: 'JoyDive_'`（連續
// 三次乾淨重建，含清空 DerivedData，皆重現，排除是暫時性建置快取問題）。
// 改用 `DiveImportKitAdapter.swift` 內新增的 `makeTestParsedDiveLog(...)` 測試
// 專用建構器（回傳型別靠推斷，呼叫端不必拼出 `DiveImportKit.` 前綴），本檔案
// 完全不需要 import Kit 就能建構測試資料，兩個平台皆可正常編譯執行。
//
// R-070 的家族層規範本體（`DiveFingerprint.matches` 精確 ID 比對優先於模糊
// 比對）已在 DiveImportKit 套件自己的測試裡覆蓋；這裡只驗證 App 這一側「把既有
// `DiveLog.importExtrasJSON` 裡的 round-trip ID 正確接進 `DiveFingerprint`」
// 這段接線邏輯。

import XCTest
import Foundation
@testable import JoyDive_

final class DiveImportKitAdapterRoundtripDedupeTests: XCTestCase {

    // MARK: - 輔助：建立最小合法既有 `DiveLog`

    /// 可選擇性帶上 `importExtrasJSON`（模擬既有記錄的 round-trip 指紋 ID
    /// 已持久化在資料庫裡；預設 `"{}"` 模擬 R-070 之前匯入、沒有這個欄位的舊資料）。
    private func makeExistingDive(
        dateTime: Date,
        location: String,
        depth: Double,
        importExtrasJSON: String = "{}"
    ) -> DiveLog {
        let dive = DiveLog(
            dateTime: dateTime,
            location: location,
            maxDepth: depth,
            diveTimeSeconds: 3600,
            gasMixJSON: "\"air\"",
            waterTemperature: 25.0
        )
        dive.sourceFormat = "test"
        dive.importExtrasJSON = importExtrasJSON
        return dive
    }

    // MARK: - roundtripID(fromImportExtrasJSON:) 輔助函式本身

    /// 空字典、缺少該 key、無效 JSON 皆應回傳 nil，不應 crash；
    /// 有該 key 時應正確解出對應值。
    func testRoundtripIDHelperReturnsNilForMissingOrInvalidJSON() {
        XCTAssertNil(roundtripID(fromImportExtrasJSON: "{}"))
        XCTAssertNil(roundtripID(fromImportExtrasJSON: "{\"otherKey\":\"value\"}"))
        XCTAssertNil(roundtripID(fromImportExtrasJSON: "not valid json"))
        XCTAssertEqual(
            roundtripID(fromImportExtrasJSON: "{\"jd2RoundtripID\":\"abc-123\"}"),
            "abc-123"
        )
    }

    // MARK: - dedupeAgainstExisting：精確 ID 比對優先於模糊比對

    /// 主場景：既有記錄與候選記錄帶有相同 round-trip ID，但地點/時間/深度
    /// 全部不同（模擬 UDDF round-trip 匯出過程改寫了地點名稱、時間、深度）。
    /// 應被判定為重複——證明抓到的是精確 ID 比對，不是模糊比對誤判命中。
    func testDedupeAgainstExistingMatchesByRoundtripIDDespiteDifferentFields() throws {
        let sharedID = "11111111-1111-1111-1111-111111111111"
        let existingJSON = "{\"jd2RoundtripID\":\"\(sharedID)\"}"

        let existing = makeExistingDive(
            dateTime: Date(timeIntervalSince1970: 1_700_000_000),
            location: "Original Site Name",
            depth: 20.0,
            importExtrasJSON: existingJSON
        )

        // 候選記錄：地點、時間（相差超過 60 秒模糊比對窗口）、深度全部不同，
        // 只有 round-trip ID 相同。
        let candidate = makeTestParsedDiveLog(
            dateTime: Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(7200),
            location: "Rewritten Site Name",
            maxDepth: 35.5,
            diveTimeSeconds: 3600,
            roundtripID: sharedID
        )

        let result = dedupeAgainstExisting([candidate], existing: [existing])

        XCTAssertEqual(result.kept.count, 0,
            "round-trip ID 相同時應判定為重複，即使地點/時間/深度皆不同")
        XCTAssertEqual(result.skippedCount, 1)
    }

    // MARK: - dedupeAgainstExisting：向後相容（缺 ID 時退回模糊比對）

    /// 既有記錄沒有 round-trip ID（R-070 之前匯入的舊資料，或 Kit round-trip
    /// 機制導入前的記錄），候選記錄帶了 ID 但完全不相關。應完全退回既有的
    /// 地點/時間/深度模糊比對，不能因為候選有 ID 就誤判或崩潰。
    func testDedupeAgainstExistingFallsBackToFuzzyMatchWhenExistingHasNoRoundtripID() throws {
        let existing = makeExistingDive(
            dateTime: Date(timeIntervalSince1970: 1_700_000_000),
            location: "Reef A",
            depth: 20.0
            // importExtrasJSON 預設 "{}"：沒有 roundtripID
        )

        // 候選記錄帶著 ID，但地點/時間/深度與既有記錄不同（模糊比對不會命中），
        // 應該保留下來（不是誤判為重複）。
        let unrelatedCandidate = makeTestParsedDiveLog(
            dateTime: Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(7200),
            location: "Unrelated Site",
            maxDepth: 50.0,
            diveTimeSeconds: 3600,
            roundtripID: "unrelated-id"
        )

        let keptResult = dedupeAgainstExisting([unrelatedCandidate], existing: [existing])
        XCTAssertEqual(keptResult.kept.count, 1,
            "既有記錄無 round-trip ID 時，不相關的候選記錄不應被誤判為重複")

        // 候選記錄與既有記錄地點/時間/深度都相同（模糊比對本應命中），但候選帶了
        // ID、既有記錄沒有——matches() 任一邊為 nil 時應退回模糊比對，仍判定為重複。
        let fuzzyMatchCandidate = makeTestParsedDiveLog(
            dateTime: Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(5),
            location: "Reef A",
            maxDepth: 20.0,
            diveTimeSeconds: 3600,
            roundtripID: "some-id"
        )

        let skippedResult = dedupeAgainstExisting([fuzzyMatchCandidate], existing: [existing])
        XCTAssertEqual(skippedResult.kept.count, 0,
            "既有記錄無 ID 時應退回模糊比對；地點/時間/深度皆吻合仍應判定為重複")
        XCTAssertEqual(skippedResult.skippedCount, 1)
    }
}
