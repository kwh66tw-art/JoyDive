// DiveSiteAnnotation.swift — JD2-Logbook/Views/Map/
// Week 10 — MKAnnotation + annotation view classes for dive site pins and clusters
//
// Three classes in this file:
//   DiveSiteAnnotation        – data model, one DiveLog per pin
//   DiveSiteAnnotationView    – blue marker pin, no callout (Sheet handles interaction)
//   DiveClusterAnnotationView – 44 pt circular badge with dive count

import MapKit

// MARK: - DiveSiteAnnotation

/// Wraps a single DiveLog as an MKAnnotation for display on MKMapView.
/// `@objc dynamic` on `coordinate` is required for MapKit's KVO observation.
final class DiveSiteAnnotation: NSObject, MKAnnotation {

    let dive: DiveLog

    @objc dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?

    init(dive: DiveLog) {
        self.dive = dive
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

/// Blue marker pin for a single dive site.
///
/// - `clusteringIdentifier = "diveCluster"` enables MapKit's native clustering.
/// - `canShowCallout = false`: tapping a pin is handled entirely by the
///   Medium Detent Sheet in MapView — no UIKit callout is shown.
final class DiveSiteAnnotationView: MKMarkerAnnotationView {

    static let reuseID = "DiveSiteAnnotationView"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = "diveCluster"
        glyphImage           = UIImage(systemName: "figure.open.water.swim")
        markerTintColor      = .systemBlue
        canShowCallout       = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}

// MARK: - DiveClusterAnnotationView

/// Circular badge displayed when multiple dive sites are clustered together.
///
/// Shows the member count ("N" for < 100, "99+" otherwise).
/// Registered for `MKMapViewDefaultClusterAnnotationViewReuseIdentifier` so
/// MapKit automatically uses it for every cluster annotation on this map.
final class DiveClusterAnnotationView: MKAnnotationView {

    static let reuseID = MKMapViewDefaultClusterAnnotationViewReuseIdentifier

    // MARK: - Badge Label

    private let badgeLabel: UILabel = {
        let label = UILabel()
        label.textColor              = .white
        label.font                   = .systemFont(ofSize: 14, weight: .bold)
        label.textAlignment          = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor     = 0.7
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Init

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupBadge()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Layout

    private func setupBadge() {
        let size: CGFloat = 44
        frame = CGRect(x: 0, y: 0, width: size, height: size)

        backgroundColor     = .systemBlue
        layer.cornerRadius  = size / 2
        layer.borderWidth   = 2.5
        layer.borderColor   = UIColor.white.cgColor
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius  = 4
        layer.shadowOffset  = CGSize(width: 0, height: 2)

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

    // MARK: - Content Update

    override func prepareForDisplay() {
        super.prepareForDisplay()
        guard let cluster = annotation as? MKClusterAnnotation else { return }
        let count = cluster.memberAnnotations.count
        badgeLabel.text      = count < 100 ? "\(count)" : "99+"
        accessibilityLabel   = "\(count) dive sites"
    }
}
