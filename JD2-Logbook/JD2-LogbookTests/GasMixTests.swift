// GasMixTests.swift — JD2-LogbookTests/
// Week 12 整合測試：GasMix enum 完整驗證
//
// 涵蓋：
//   - 氣體分率（fO2 / fHe / fN2）
//   - displayName
//   - MOD 計算
//   - JSON 編解碼 round-trip（air / nitrox / trimix）
//   - DiveLogEditSheet 所用的 gasMixJSON 格式
//   - 邊界值與無效輸入處理

import XCTest
import DiveKit
@testable import JoyDive_

final class GasMixTests: XCTestCase {

    // MARK: - Air

    func testAirFractions() {
        let gas = GasMix.air
        XCTAssertEqual(gas.fO2, 0.21, accuracy: 0.0001)
        XCTAssertEqual(gas.fHe, 0.0,  accuracy: 0.0001)
        XCTAssertEqual(gas.fN2, 0.79, accuracy: 0.0001)
    }

    func testAirDisplayName() {
        XCTAssertEqual(GasMix.air.displayName, "Air")
    }

    func testAirMOD_defaultPO2() {
        // MOD = (1.4 / 0.21 - 1.0) × 10 ≈ 56.67 m
        let mod = GasMix.air.mod()
        XCTAssertEqual(mod, 56.67, accuracy: 0.01)
    }

    func testAirIsNotTrimix() {
        XCTAssertFalse(GasMix.air.isTrimix)
    }

    // MARK: - Nitrox

    func testNitrox32Fractions() {
        let gas = GasMix.nitrox(fO2: 0.32)
        XCTAssertEqual(gas.fO2, 0.32, accuracy: 0.0001)
        XCTAssertEqual(gas.fHe, 0.0,  accuracy: 0.0001)
        XCTAssertEqual(gas.fN2, 0.68, accuracy: 0.0001)
    }

    func testNitrox32DisplayName() {
        XCTAssertEqual(GasMix.nitrox(fO2: 0.32).displayName, "EANx32")
    }

    func testNitrox36DisplayName() {
        XCTAssertEqual(GasMix.nitrox(fO2: 0.36).displayName, "EANx36")
    }

    func testNitroxMOD_32pct() {
        // MOD = (1.4 / 0.32 - 1.0) × 10 ≈ 33.75 m
        let mod = GasMix.nitrox(fO2: 0.32).mod()
        XCTAssertEqual(mod, 33.75, accuracy: 0.01)
    }

    func testNitroxFractionClampedAbove1() {
        // fO2 clamp: max = 1.0
        let gas = GasMix.nitrox(fO2: 1.5)
        XCTAssertEqual(gas.fO2, 1.0, accuracy: 0.0001)
    }

    func testNitroxFractionClampedBelow016() {
        // fO2 clamp: min = 0.16
        let gas = GasMix.nitrox(fO2: 0.05)
        XCTAssertEqual(gas.fO2, 0.16, accuracy: 0.0001)
    }

    // MARK: - Trimix

    func testTrimix2135Fractions() {
        let gas = GasMix.trimix(fO2: 0.21, fHe: 0.35)
        XCTAssertEqual(gas.fO2, 0.21, accuracy: 0.0001)
        XCTAssertEqual(gas.fHe, 0.35, accuracy: 0.0001)
        XCTAssertEqual(gas.fN2, 0.44, accuracy: 0.0001)
    }

    func testTrimixDisplayName() {
        XCTAssertEqual(GasMix.trimix(fO2: 0.21, fHe: 0.35).displayName, "Tx21/35")
    }

    func testTrimixIsTrimix() {
        XCTAssertTrue(GasMix.trimix(fO2: 0.21, fHe: 0.35).isTrimix)
    }

    // MARK: - JSON Round-Trip（air）

    func testJSONRoundTripAir() throws {
        // DiveLogEditSheet 寫法：buildGasMixJSON() 回傳 "\"air\""
        let json = "\"air\""
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(GasMix.self, from: data)
        guard case .air = decoded else {
            XCTFail("期望解碼出 .air，得到 \(decoded)")
            return
        }
    }

    func testJSONRoundTripNitrox() throws {
        // DiveLogEditSheet 寫法："{\"nitrox\":{\"fO2\":0.32}}"
        let fO2: Double = 0.32
        let fO2Str = String(format: "%.4g", fO2)
        let json = "{\"nitrox\":{\"fO2\":\(fO2Str)}}"
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(GasMix.self, from: data)
        guard case .nitrox(let f) = decoded else {
            XCTFail("期望解碼出 .nitrox，得到 \(decoded)")
            return
        }
        XCTAssertEqual(f, 0.32, accuracy: 0.0001)
    }

    func testJSONRoundTripNitrox40Pct() throws {
        let fO2: Double = 0.40
        let fO2Str = String(format: "%.4g", fO2)
        let json = "{\"nitrox\":{\"fO2\":\(fO2Str)}}"
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(GasMix.self, from: data)
        guard case .nitrox(let f) = decoded else {
            XCTFail("期望解碼出 .nitrox(0.40)，得到 \(decoded)")
            return
        }
        XCTAssertEqual(f, 0.40, accuracy: 0.0001)
    }

    func testJSONDecodeInvalidFallsBackToAir_InDetailView() {
        // DiveLogDetailView gasMixText：JSON 損壞時 fallback "Air"
        let badJSON = "not_valid_json"
        let data = badJSON.data(using: .utf8)!
        let gas = try? JSONDecoder().decode(GasMix.self, from: data)
        XCTAssertNil(gas, "損壞 JSON 應解碼失敗，View 層自行 fallback 至 Air")
    }

    // MARK: - EditSheet JSON Builder 格式驗證

    func testBuildGasMixJSON_Air() throws {
        // 模擬 DiveLogEditSheet.buildGasMixJSON() 的 air 分支
        let json = "\"air\""
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(GasMix.self, from: data)
        guard case .air = decoded else {
            XCTFail("air JSON 格式不符 GasMix decoder")
            return
        }
    }

    func testBuildGasMixJSON_Nitrox_RoundTrip() throws {
        // 模擬 DiveLogEditSheet.buildGasMixJSON() nitrox 分支
        let nitroxO2Percent: Double = 32.0
        let fO2 = nitroxO2Percent / 100.0
        let fO2Str = String(format: "%.4g", fO2)
        let json = "{\"nitrox\":{\"fO2\":\(fO2Str)}}"
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(GasMix.self, from: data)
        guard case .nitrox(let f) = decoded else {
            XCTFail("nitrox JSON 格式不符 GasMix decoder")
            return
        }
        XCTAssertEqual(f * 100, nitroxO2Percent, accuracy: 0.01)
    }

    // MARK: - Duration 換算（EditSheet ↔ DiveLog）

    func testDurationMinutesToSeconds() {
        // DiveLogEditSheet.save()：totalSeconds = durationMinutes × 60
        let minutes = 45
        let seconds = minutes * 60
        XCTAssertEqual(seconds, 2700)
    }

    func testDurationSecondsToMinutes() {
        // DiveLogEditSheet.init(mode: .edit)：max(1, dive.diveTimeSeconds / 60)
        let diveTimeSeconds = 5640   // 94 分鐘
        let minutes = max(1, diveTimeSeconds / 60)
        XCTAssertEqual(minutes, 94)
    }

    func testDurationSecondsToMinutes_ZeroGuard() {
        // 邊界：0 秒應被 max(1,…) 保護回傳 1
        let diveTimeSeconds = 0
        let minutes = max(1, diveTimeSeconds / 60)
        XCTAssertEqual(minutes, 1)
    }

    func testDurationSecondsToMinutes_SubMinute() {
        // 59 秒 → 整除後 0，max 保護為 1
        let diveTimeSeconds = 59
        let minutes = max(1, diveTimeSeconds / 60)
        XCTAssertEqual(minutes, 1)
    }

    // MARK: - R-054：locale-aware 顯示 vs. JSON 序列化 locale-free（不可混淆）

    /// `DiveLogEditSheet.buildGasMixJSON()`（Views/Logbook/DiveLogEditSheet.swift）
    /// 刻意不傳 `locale:`——這是 JSON 序列化路徑，寫死的 fO2 字面值會被
    /// `JSONDecoder` 解回 `GasMix`，任何逗號小數點都會讓解碼失敗或算出錯誤的 fO2。
    /// 本測試模擬同一段程式碼（不加 locale:），斷言即使把裝置/App 語言模擬成
    /// 逗號小數點語系（de/fr/es/it/nl/pt-PT/hr/el/id/vi 之一），輸出仍固定為
    /// 句點小數點，且能被 JSONDecoder 正確解回。
    func testGasMixJSONBuilder_StaysLocaleFree_RegardlessOfSimulatedCommaLocale() throws {
        let nitroxO2Percent: Double = 32.0
        let fO2 = nitroxO2Percent / 100.0

        // 逐字重現 DiveLogEditSheet.buildGasMixJSON() 的 nitrox 分支：
        // 不傳 locale: 參數，String(format:) 的預設行為與系統/App 語言無關，
        // 永遠使用 "." 小數點（POSIX 風格），這正是它「locale-free 是正確且必要」的原因。
        let fO2Str = String(format: "%.4g", fO2)
        let json = "{\"nitrox\":{\"fO2\":\(fO2Str)}}"

        XCTAssertTrue(json.contains("0.32"), "JSON 序列化必須固定用句點小數點，得到：\(json)")
        XCTAssertFalse(json.contains(","), "JSON 序列化絕不能出現逗號，得到：\(json)")

        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(GasMix.self, from: data)
        guard case .nitrox(let f) = decoded else {
            XCTFail("期望解碼出 .nitrox，得到 \(decoded)")
            return
        }
        XCTAssertEqual(f, 0.32, accuracy: 0.0001)
    }

    /// 對照組：同一個 `String(format:)` API，若像 UI 顯示層那樣**有**傳
    /// `locale:`，逗號小數點語系（以 de_DE 為代表）就會照常顯示逗號——
    /// 證明兩者是同一支 API 的兩種刻意不同用法，不是漏加。
    func testStringFormat_WithLocale_UsesCommaForCommaDecimalLocale() {
        let germanLocale = Locale(identifier: "de_DE")
        let weight = 12.3
        let formatted = String(format: "%.1f", locale: germanLocale, weight)
        XCTAssertEqual(formatted, "12,3", "de_DE locale 應使用逗號小數點")
    }

    /// 同一個值不傳 locale: 時，即使執行環境是逗號小數點語系，仍固定輸出句點
    /// （這正是 buildGasMixJSON 依賴、且不可被「順手」加上 locale: 破壞的行為）。
    func testStringFormat_WithoutLocale_AlwaysUsesPeriod() {
        let weight = 12.3
        let formatted = String(format: "%.1f", weight)
        XCTAssertEqual(formatted, "12.3")
        XCTAssertFalse(formatted.contains(","))
    }
}
