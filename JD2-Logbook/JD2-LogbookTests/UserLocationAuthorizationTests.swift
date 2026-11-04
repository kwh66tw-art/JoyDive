// UserLocationAuthorizationTests.swift — JD2-LogbookTests
// v1.4（PM 2026-11-04）：授權回呼只在「使用者按了回到我的位置、等待授權中」才抓位置；
// 開地圖（建立 provider）時的授權回呼不得自動置中。

import XCTest
import CoreLocation
@testable import JoyDive_

final class UserLocationAuthorizationTests: XCTestCase {

    private func shouldRequest(_ status: CLAuthorizationStatus, pending: Bool) -> Bool {
        UserLocationProvider.shouldRequestLocationAfterAuthorizationChange(
            status: status, recenterPendingAuthorization: pending)
    }

    /// 開地圖時 provider 建立、回呼帶回「已授權」：沒有按鈕請求 ⇒ 不抓位置。
    func testAuthorizedWithoutButtonRequestDoesNotRequestLocation() {
        #if os(iOS)
        XCTAssertFalse(shouldRequest(.authorizedWhenInUse, pending: false))
        #endif
        XCTAssertFalse(shouldRequest(.authorizedAlways, pending: false))
    }

    /// 按鈕觸發授權詢問、使用者允許 ⇒ 抓位置（只此一次，由呼叫端清除等待狀態）。
    func testAuthorizedAfterButtonRequestRequestsLocation() {
        #if os(iOS)
        XCTAssertTrue(shouldRequest(.authorizedWhenInUse, pending: true))
        #endif
        XCTAssertTrue(shouldRequest(.authorizedAlways, pending: true))
    }

    func testDeniedOrUndeterminedNeverRequestsLocation() {
        for status in [CLAuthorizationStatus.denied, .restricted, .notDetermined] {
            XCTAssertFalse(shouldRequest(status, pending: true), "\(status.rawValue)")
            XCTAssertFalse(shouldRequest(status, pending: false), "\(status.rawValue)")
        }
    }

    // MARK: - 授權回呼的呼叫路徑本身（2026-11-04 故障注入：繞過判斷函式時上面 3 支全綠，補這兩支）

    /// 測試中不得釋放 `@MainActor @Observable` 實例（會 SIGABRT）⇒ static 共用。
    @MainActor private static let provider = UserLocationProvider()

    /// 開地圖時的授權回呼（已授權、沒有按鈕請求）⇒ 實際抓位置的動作一次都不能被呼叫。
    @MainActor func testAuthorizationCallbackWithoutButtonRequestNeverRequestsLocation() {
        let provider = Self.provider
        var requests = 0
        provider.requestLocationAction = { requests += 1 }
        defer { provider.requestLocationAction = nil }
        provider.recenterPendingAuthorization = false

        provider.handleAuthorizationChange(.authorizedAlways)

        XCTAssertEqual(requests, 0)
    }

    /// 按鈕觸發授權詢問、使用者允許 ⇒ 抓一次位置並結束等待；之後的回呼不再抓。
    @MainActor func testAuthorizationCallbackAfterButtonRequestRequestsExactlyOnce() {
        let provider = Self.provider
        var requests = 0
        provider.requestLocationAction = { requests += 1 }
        defer { provider.requestLocationAction = nil }
        provider.recenterPendingAuthorization = true

        provider.handleAuthorizationChange(.authorizedAlways)
        XCTAssertEqual(requests, 1)
        XCTAssertFalse(provider.recenterPendingAuthorization)

        provider.handleAuthorizationChange(.authorizedAlways)
        XCTAssertEqual(requests, 1)
    }
}
