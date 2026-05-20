// DiveMapRepresentable.swift — JD2-Logbook/Views/Map/
// Week 10 — UIViewRepresentable wrapping MKMapView
//
// Responsibilities:
//   - Register DiveSiteAnnotationView + DiveClusterAnnotationView
//   - Diff annotations via PersistentIdentifier (add/remove without full reload)
//   - Zoom-to-fit on first data load (single flag in Coordinator)
//   - Forward single-pin taps to SwiftUI via onAnnotationTapped callback
//   - Cluster tap → showAnnotations zoom-in-to-fit

import SwiftUI
import SwiftData
import MapKit

struct DiveMapRepresentable: UIViewRepresentable {

    // MARK: - Inputs

    /// Dives already filtered to those with valid GPS coordinates.
    let dives: [DiveLog]

    @Binding var mapType: MKMapType

    /// Called on the main thread when a single DiveSiteAnnotation is tapped.
    var onAnnotationTapped: (DiveLog) -> Void

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(onAnnotationTapped: onAnnotationTapped)
    }

    // MARK: - makeUIView

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate        = context.coordinator
        mapView.mapType         = mapType
        mapView.showsUserLocation = false
        mapView.showsCompass    = true
        mapView.showsScale      = true

        mapView.register(
            DiveSiteAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: DiveSiteAnnotationView.reuseID
        )
        mapView.register(
            DiveClusterAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: DiveClusterAnnotationView.reuseID
        )

        return mapView
    }

    // MARK: - updateUIView

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Refresh callback on every update to prevent stale closure captures
        context.coordinator.onAnnotationTapped = onAnnotationTapped

        // ── Map type ─────────────────────────────────────────────────
        if mapView.mapType != mapType {
            mapView.mapType = mapType
        }

        // ── Annotation diff ──────────────────────────────────────────
        let existing = mapView.annotations.compactMap { $0 as? DiveSiteAnnotation }
        let newIDs   = Set(dives.map { $0.persistentModelID })

        // Remove stale annotations
        let toRemove = existing.filter { !newIDs.contains($0.dive.persistentModelID) }
        if !toRemove.isEmpty {
            mapView.removeAnnotations(toRemove)
        }

        // Add new annotations (re-query current set after removal)
        let currentIDs = Set(
            mapView.annotations
                .compactMap { $0 as? DiveSiteAnnotation }
                .map { $0.dive.persistentModelID }
        )
        let toAdd = dives
            .filter { !currentIDs.contains($0.persistentModelID) }
            .map  { DiveSiteAnnotation(dive: $0) }

        guard !toAdd.isEmpty else { return }
        mapView.addAnnotations(toAdd)

        // ── Zoom-to-fit on first load ─────────────────────────────────
        guard !context.coordinator.hasZoomedToFit else { return }
        context.coordinator.hasZoomedToFit = true

        DispatchQueue.main.async {
            let all = mapView.annotations.filter { !($0 is MKUserLocation) }
            guard !all.isEmpty else { return }

            if all.count == 1 {
                // Single pin: zoom to a comfortable viewing span
                let region = MKCoordinateRegion(
                    center: all[0].coordinate,
                    span:   MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                mapView.setRegion(region, animated: true)
            } else {
                mapView.showAnnotations(all, animated: true)
            }
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {

        var onAnnotationTapped: (DiveLog) -> Void
        /// Prevents repeated zoom-to-fit on subsequent data updates.
        var hasZoomedToFit = false

        init(onAnnotationTapped: @escaping (DiveLog) -> Void) {
            self.onAnnotationTapped = onAnnotationTapped
        }

        // MARK: viewFor annotation

        func mapView(_ mapView: MKMapView,
                     viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            if annotation is MKClusterAnnotation {
                return mapView.dequeueReusableAnnotationView(
                    withIdentifier: DiveClusterAnnotationView.reuseID,
                    for: annotation
                )
            }

            if annotation is DiveSiteAnnotation {
                return mapView.dequeueReusableAnnotationView(
                    withIdentifier: DiveSiteAnnotationView.reuseID,
                    for: annotation
                )
            }

            return nil
        }

        // MARK: didSelect

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? MKClusterAnnotation {
                // Zoom in to reveal individual pins inside the cluster
                mapView.showAnnotations(cluster.memberAnnotations, animated: true)
                mapView.deselectAnnotation(cluster, animated: false)

            } else if let diveAnnotation = view.annotation as? DiveSiteAnnotation {
                // Notify SwiftUI — MapView will present the Medium Detent Sheet
                onAnnotationTapped(diveAnnotation.dive)
            }
        }
    }
}
