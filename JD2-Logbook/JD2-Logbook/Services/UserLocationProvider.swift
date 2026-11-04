// UserLocationProvider.swift — JD2-Logbook/Services/
// v1.1 #11 — 地圖「回到我的位置」recenter 按鈕
//
// 設計原則：定位權限只在使用者於 Settings 明確開啟「GPS 定位」開關時才請求
// （對齊 logbook/privacy.md 的承諾）。開關狀態存在 UserDefaults（isEnabledKey），
// SettingsView 的 Toggle 與 MapView 的 recenter 按鈕都讀寫同一個 key，天然同步。
//
// 一次性定位：recenter 只需要「按一下、飛過去」，不需要持續追蹤，
// 所以用 requestLocation()（單次）而非 startUpdatingLocation()（持續）。

import Foundation
import CoreLocation
import Observation

// 原生 macOS 沒有 `.authorizedWhenInUse` case（該 case 只存在於 iOS / Catalyst /
// tvOS / watchOS），macOS 授權成功一律回報 `.authorizedAlways`。集中在此處理平台差異，
// 避免各處直接比較 `.authorizedWhenInUse` 導致 macOS 編譯失敗。
extension CLAuthorizationStatus {
    var isAuthorizedForRecenter: Bool {
        #if os(macOS)
        self == .authorizedAlways
        #else
        self == .authorizedWhenInUse || self == .authorizedAlways
        #endif
    }
}

@MainActor
@Observable
final class UserLocationProvider: NSObject, CLLocationManagerDelegate {

    /// SettingsView 與 MapView 共用的 UserDefaults key（App 層級的「是否允許使用定位」開關）。
    static let isEnabledKey = "gpsLocationEnabled"

    private let manager = CLLocationManager()

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var lastLocation: CLLocation?

    /// 定位成功時通知呼叫端（MapView 用來觸發地圖置中）。
    var onLocationUpdate: ((CLLocation) -> Void)?

    /// v1.4（PM 2026-11-04）：使用者按了「回到我的位置」、因此觸發授權詢問，正在等結果。
    /// 只有這種情況，授權通過後才抓位置（見 `shouldRequestLocationAfterAuthorizationChange`）。
    /// 不設 private：測試要直接設定等待狀態，避免呼叫 `requestOneShotLocation()` 在測試主機上彈出真正的授權詢問。
    var recenterPendingAuthorization = false

    /// 實際抓位置的動作；nil＝呼叫 `CLLocationManager.requestLocation()`。測試換成計數用的閉包，
    /// 才能驗證「授權回呼」這條呼叫路徑本身（不只驗判斷函式）。2026-11-04 故障注入發現：
    /// 回呼若繞過判斷函式直接抓位置，原本 3 支測試全綠（判斷函式本身沒變）。
    var requestLocationAction: (() -> Void)?

    /// 授權狀態改變時要不要抓位置：只在「按鈕發起、等待授權中」且已授權時。
    /// v1.1 #11 規格只有按鈕；原本建立 provider 時的授權回呼只要已授權就抓位置，
    /// 等於「開地圖就自動移到使用者位置」，還會蓋掉「在地圖上顯示」的縮放與首次全覽——屬副作用，PM 2026-11-04 裁示移除。
    nonisolated static func shouldRequestLocationAfterAuthorizationChange(
        status: CLAuthorizationStatus, recenterPendingAuthorization: Bool
    ) -> Bool {
        recenterPendingAuthorization && status.isAuthorizedForRecenter
    }

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Settings 開關剛被打開時呼叫：若系統權限尚未詢問過，才彈出授權對話框。
    func requestAuthorizationIfNeeded() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    /// 地圖 recenter 按鈕按下時呼叫。
    func requestOneShotLocation() {
        if authorizationStatus == .notDetermined {
            recenterPendingAuthorization = true
            manager.requestWhenInUseAuthorization()
        } else if authorizationStatus.isAuthorizedForRecenter {
            performLocationRequest()
        }
        // .denied / .restricted：呼叫端負責導去系統設定
    }

    /// 授權狀態改變後的處理。delegate 回呼只負責跳回 MainActor 再呼叫這裡，判斷與狀態更新都在這裡（可測）。
    func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        if Self.shouldRequestLocationAfterAuthorizationChange(
            status: status, recenterPendingAuthorization: recenterPendingAuthorization) {
            performLocationRequest()
        }
        // 有結果（允許或拒絕）就結束等待；仍是 notDetermined 表示使用者還沒回應。
        if status != .notDetermined { recenterPendingAuthorization = false }
    }

    private func performLocationRequest() {
        if let requestLocationAction {
            requestLocationAction()
        } else {
            manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate
    // Swift 6 strict concurrency：delegate 方法不隸屬 MainActor，故標 nonisolated，
    // 內部 Task 跳回 MainActor 再碰 @Observable 狀態。

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.handleAuthorizationChange(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.lastLocation = location
            self.onLocationUpdate?(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[UserLocationProvider] failed: \(error)")
    }
}
