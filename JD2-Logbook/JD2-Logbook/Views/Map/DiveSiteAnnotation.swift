// DiveSiteAnnotation.swift — JD2-Logbook/Views/Map/
// Week 10 — MKAnnotation + annotation view classes
//
// iOS:   UIImage / UIColor / UILabel
// macOS: NSImage / NSColor / NSTextField（label style）
//
// DiveSiteAnnotation（純資料 class）無平台相依，兩平台共用。
// DiveSiteAnnotationView 為單一潛點釘（含值變更防護）；
// 聚合徽章不自訂，交由 MapKit 原生預設 view（viewFor 回傳 nil）自動算繪數字。

import MapKit

#if os(iOS)
import UIKit
#else
import AppKit
#endif

// MARK: - DiveSiteAnnotation（共用）

/// 將單筆 DiveLog 包裝為 MKAnnotation，供 MKMapView 顯示。
/// `@objc dynamic` on `coordinate` 是 MapKit KVO 觀察的必要條件。
final class DiveSiteAnnotation: NSObject, MKAnnotation {

    let dive: DiveLog

    @objc dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?

    // ⚠️ 不在這裡用 String(localized:)：這是純 NSObject/MKAnnotation，沒有 SwiftUI
    // Environment 可用，String(localized:) 讀系統 Locale，語言切換後不重開 App 會
    // 殘留舊語言。改由呼叫端（DiveMapRepresentable，有 languageManager）把已解析好
    // 的字串傳進來。
    init(dive: DiveLog, unknownLocationText: String) {
        self.dive       = dive
        self.coordinate = CLLocationCoordinate2D(
            latitude:  dive.latitude  ?? 0,
            longitude: dive.longitude ?? 0
        )
        self.title    = dive.location.isEmpty
            ? unknownLocationText
            : dive.location
        // v1.2 #4：非 SwiftUI View，不能用 @AppStorage，直接讀同一個 UserDefaults key。
        let unitSystem = UnitSystem(rawValue: UserDefaults.standard.string(forKey: UnitSystem.storageKey) ?? "") ?? .metric
        self.subtitle = unitSystem.formatDepth(dive.maxDepth)
        super.init()
    }
}

// MARK: - DiveSiteAnnotationView

/// 單一潛點的藍色標準地圖釘（乾淨 marker，不帶人形字符）。
/// `clusteringIdentifier` 啟用 MapKit 原生聚類；`canShowCallout = false`，
/// 點擊事件完全交由詳情面板處理。
final class DiveSiteAnnotationView: MKMarkerAnnotationView {

    static let reuseID = "DiveSiteAnnotationView"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = "diveCluster"
        canShowCallout       = false
        applyStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    /// 👑 關鍵：MapKit 為效能會「原地重指派」既有 view 的 annotation（不觸發 viewFor／
    /// 不一定觸發 prepareForDisplay），此時 clusteringIdentifier 會被重置為 nil，
    /// 該 pin 就退出聚合、導致整個聚合解體（看起來像數字/徽章消失）。
    /// 只有 annotation 的 didSet 是必觸發節點，在此重套 clusteringIdentifier 才能守住聚合。
    override var annotation: MKAnnotation? {
        didSet { applyStyle() }
    }

    /// MKMarkerAnnotationView 在 reuse 時會把 glyph/tint 重設回預設（紅色）。
    /// 因此每次顯示都重套樣式，確保所有潛點外觀一致（藍色標準釘）。
    override func prepareForDisplay() {
        super.prepareForDisplay()
        applyStyle()
    }

    private func applyStyle() {
        // 值變更防護：只有屬性真正改變時才寫入，避免重複 setter 觸發 VectorKit 冗餘重繪。
        if clusteringIdentifier != "diveCluster" {
            clusteringIdentifier = "diveCluster"
        }
        if glyphImage != nil {
            glyphImage = nil          // 維持乾淨標準釘（無人形字符）
        }
        if displayPriority != .defaultLow {
            displayPriority = .defaultLow  // 啟用 MapKit 原生聚合
        }
#if os(iOS)
        let target = UIColor.systemBlue
#else
        let target = NSColor.systemBlue
#endif
        if markerTintColor != target {
            markerTintColor = target
        }
    }
}

// 聚合徽章（cluster）完全交給 MapKit 原生預設 view 管理（viewFor 回傳 nil），
// 由系統自動算繪成員數量，避免自訂子類別在 reuse / 重聚合時數字消失的問題。
