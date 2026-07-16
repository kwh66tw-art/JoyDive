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
            manager.requestWhenInUseAuthorization()
        } else if authorizationStatus.isAuthorizedForRecenter {
            manager.requestLocation()
        }
        // .denied / .restricted：呼叫端負責導去系統設定
    }

    // MARK: - CLLocationManagerDelegate
    // Swift 6 strict concurrency：delegate 方法不隸屬 MainActor，故標 nonisolated，
    // 內部 Task 跳回 MainActor 再碰 @Observable 狀態。

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status.isAuthorizedForRecenter {
                manager.requestLocation()
            }
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
