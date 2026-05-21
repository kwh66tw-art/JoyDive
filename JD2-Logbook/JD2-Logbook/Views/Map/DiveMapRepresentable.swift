// DiveMapRepresentable.swift — JD2-Logbook/Views/Map/
// Week 10 — Cross-platform MKMapView wrapper
//
// iOS:   UIViewRepresentable
// macOS: NSViewRepresentable
//
// DiveMapCoordinator（MKMapViewDelegate）為兩平台共用。
// 僅 make/update 方法名稱依平台切換，業務邏輯完全一致。

import SwiftUI
import SwiftData
import MapKit

// MARK: - Shared Coordinator

/// MKMapViewDelegate APIs 在 iOS / macOS 完全相同，Coordinator 不需要平台分支。
final class DiveMapCoordinator: NSObject, MKMapViewDelegate {

    var onAnnotationTapped: (DiveLog) -> Void
    /// 防止後續資料更新觸發重複 zoom-to-fit。
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
            mapView.showAnnotations(cluster.memberAnnotations, animated: true)
            mapView.deselectAnnotation(cluster, animated: false)
        } else if let diveAnnotation = view.annotation as? DiveSiteAnnotation {
            onAnnotationTapped(diveAnnotation.dive)
        }
    }
}

// MARK: - Platform-specific Representable

#if os(iOS)

struct DiveMapRepresentable: UIViewRepresentable {

    let dives: [DiveLog]
    @Binding var mapType: MKMapType
    var onAnnotationTapped: (DiveLog) -> Void

    func makeCoordinator() -> DiveMapCoordinator {
        DiveMapCoordinator(onAnnotationTapped: onAnnotationTapped)
    }

    func makeUIView(context: Context) -> MKMapView {
        _makeMapView(context.coordinator)
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        _updateMapView(mapView, coordinator: context.coordinator)
    }
}

#else

struct DiveMapRepresentable: NSViewRepresentable {

    let dives: [DiveLog]
    @Binding var mapType: MKMapType
    var onAnnotationTapped: (DiveLog) -> Void

    func makeCoordinator() -> DiveMapCoordinator {
        DiveMapCoordinator(onAnnotationTapped: onAnnotationTapped)
    }

    func makeNSView(context: Context) -> MKMapView {
        _makeMapView(context.coordinator)
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        _updateMapView(mapView, coordinator: context.coordinator)
    }
}

#endif

// MARK: - Shared Implementation
// 兩平台的 make / update 邏輯完全相同，抽出成 private 方法避免重複。

private extension DiveMapRepresentable {

    func _makeMapView(_ coordinator: DiveMapCoordinator) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate           = coordinator
        mapView.mapType            = mapType
        mapView.showsUserLocation  = false
        mapView.showsCompass       = true
        mapView.showsScale         = true

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

    func _updateMapView(_ mapView: MKMapView, coordinator: DiveMapCoordinator) {
        // 更新 callback 防止 stale closure
        coordinator.onAnnotationTapped = onAnnotationTapped

        // ── Map type ─────────────────────────────────────────────────
        if mapView.mapType != mapType {
            mapView.mapType = mapType
        }

        // ── Annotation diff ──────────────────────────────────────────
        let existing = mapView.annotations.compactMap { $0 as? DiveSiteAnnotation }
        let newIDs   = Set(dives.map { $0.persistentModelID })

        let toRemove = existing.filter { !newIDs.contains($0.dive.persistentModelID) }
        if !toRemove.isEmpty {
            mapView.removeAnnotations(toRemove)
        }

        let currentIDs = Set(
            mapView.annotations
                .compactMap { $0 as? DiveSiteAnnotation }
                .map { $0.dive.persistentModelID }
        )
        let toAdd = dives
            .filter { !currentIDs.contains($0.persistentModelID) }
            .map    { DiveSiteAnnotation(dive: $0) }

        guard !toAdd.isEmpty else { return }
        mapView.addAnnotations(toAdd)

        // ── Zoom-to-fit on first load ─────────────────────────────────
        guard !coordinator.hasZoomedToFit else { return }
        coordinator.hasZoomedToFit = true

        DispatchQueue.main.async {
            let all = mapView.annotations.filter { !($0 is MKUserLocation) }
            guard !all.isEmpty else { return }

            if all.count == 1 {
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
}
