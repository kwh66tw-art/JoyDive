// DiveSiteAnnotation.swift — JD2-Logbook/Views/Map/
// Week 10 — MKAnnotation + annotation view classes
//
// iOS:   UIImage / UIColor / UILabel
// macOS: NSImage / NSColor / NSTextField（label style）
//
// DiveSiteAnnotation（純資料 class）無平台相依，兩平台共用。
// DiveSiteAnnotationView / DiveClusterAnnotationView 依平台使用對應 API。

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

    init(dive: DiveLog) {
        self.dive       = dive
        self.coordinate = CLLocationCoordinate2D(
            latitude:  dive.latitude  ?? 0,
            longitude: dive.longitude ?? 0
        )
        self.title    = dive.location.isEmpty
            ? String(localized: "Unknown Location")
            : dive.location
        self.subtitle = String(format: "%.1f m", dive.maxDepth)
        super.init()
    }
}

// MARK: - DiveSiteAnnotationView

/// 單一潛點的藍色 marker pin。
/// `clusteringIdentifier` 啟用 MapKit 原生聚類；`canShowCallout = false`，
/// 點擊事件完全交由 Medium Detent Sheet 處理。
final class DiveSiteAnnotationView: MKMarkerAnnotationView {

    static let reuseID = "DiveSiteAnnotationView"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = "diveCluster"
        canShowCallout       = false

#if os(iOS)
        glyphImage      = UIImage(systemName: "figure.open.water.swim")
        markerTintColor = .systemBlue
#else
        // macOS 11+：NSImage 不有 init(systemName:)，正確 API 是 systemSymbolName
        glyphImage      = NSImage(systemSymbolName: "figure.open.water.swim",
                                  accessibilityDescription: nil)
        markerTintColor = NSColor.systemBlue
#endif
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}

// MARK: - DiveClusterAnnotationView

/// 多個潛點聚集時顯示的圓形 badge，顯示成員數量。
final class DiveClusterAnnotationView: MKAnnotationView {

    static let reuseID = MKMapViewDefaultClusterAnnotationViewReuseIdentifier

    // MARK: Badge Label（平台差異：UILabel vs NSTextField）

#if os(iOS)
    private let badgeLabel: UILabel = {
        let label = UILabel()
        label.textColor                          = .white
        label.font                               = .systemFont(ofSize: 14, weight: .bold)
        label.textAlignment                      = .center
        label.adjustsFontSizeToFitWidth          = true
        label.minimumScaleFactor                 = 0.7
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
#else
    private let badgeLabel: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.textColor                          = .white
        field.font                               = .systemFont(ofSize: 14, weight: .bold)
        field.alignment                          = .center
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
#endif

    // MARK: Init

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupBadge()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: Layout

    private func setupBadge() {
        let size: CGFloat = 44
        frame = CGRect(x: 0, y: 0, width: size, height: size)

#if os(iOS)
        // UIView：layer 為非 optional
        backgroundColor     = .systemBlue
        layer.cornerRadius  = size / 2
        layer.borderWidth   = 2.5
        layer.borderColor   = UIColor.white.cgColor
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius  = 4
        layer.shadowOffset  = CGSize(width: 0, height: 2)
#else
        // NSView：需先啟用 layer，layer 為 optional
        wantsLayer              = true
        layer?.backgroundColor  = NSColor.systemBlue.cgColor
        layer?.cornerRadius     = size / 2
        layer?.borderWidth      = 2.5
        layer?.borderColor      = NSColor.white.cgColor
        layer?.shadowColor      = NSColor.black.cgColor
        layer?.shadowOpacity    = 0.25
        layer?.shadowRadius     = 4
#endif

        addSubview(badgeLabel)
        NSLayoutConstraint.activate([
            badgeLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            badgeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            badgeLabel.widthAnchor.constraint(
                lessThanOrEqualTo: widthAnchor, multiplier: 0.85
            )
        ])

        canShowCallout = false
        collisionMode  = .circle
    }

    // MARK: Content Update

    override func prepareForDisplay() {
        super.prepareForDisplay()
        guard let cluster = annotation as? MKClusterAnnotation else { return }
        let count = cluster.memberAnnotations.count
        let text  = count < 100 ? "\(count)" : "99+"

#if os(iOS)
        badgeLabel.text        = text
        accessibilityLabel     = "\(count) dive sites"
#else
        badgeLabel.stringValue = text
        // macOS NSView：accessibilityLabel 是 method，需用 setter
        setAccessibilityLabel("\(count) dive sites")
#endif
    }
}
