// MapView.swift — JD2-Logbook/Views/Map/
// Week 10 — GPS map with dive site pins, native clustering, and Medium Detent Sheet
//
// Interaction model (Oceanic+ inspired):
//   • Tap a pin           → sheet appears at 0.35 detent (peek: location + date + stats)
//   • Tap a different pin → sheet content updates in-place, haptic fires; sheet stays open
//   • Pull sheet up       → .large detent reveals full dive details
//   • Swipe sheet down    → dismisses; map pin deselects via onDismiss
//   • Tap cluster badge   → map zooms in to fit member pins (handled in Coordinator)
//   • Top-right button    → toggles Standard / Hybrid map layer

import SwiftUI
import SwiftData
import MapKit

struct MapView: View {

    // MARK: - Data

    @Query(sort: \DiveLog.dateTime, order: .reverse) private var allDives: [DiveLog]

    private var mappableDives: [DiveLog] {
        allDives.filter { $0.latitude != nil && $0.longitude != nil }
    }

    // MARK: - State

    @State private var mapType: MKMapType = .standard
    /// The dive whose sheet is currently (or about to be) displayed.
    @State private var selectedDive: DiveLog?
    /// Controls sheet presentation. Kept separate from selectedDive so that
    /// tapping a second pin while the sheet is open updates content without
    /// dismissing and re-presenting.
    @State private var isSheetPresented = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {

                // ── Map ───────────────────────────────────────────────
                DiveMapRepresentable(
                    dives:              mappableDives,
                    mapType:            $mapType,
                    onAnnotationTapped: { dive in
                        selectedDive      = dive
                        isSheetPresented  = true
                    }
                )
                .ignoresSafeArea(edges: .bottom)

                // ── Map Type Toggle ───────────────────────────────────
                mapTypeToggleButton
                    .padding(.top, 8)
                    .padding(.trailing, 12)
            }
            .navigationTitle(String(localized: "Map"))
            .navigationBarTitleDisplayMode(.inline)

            // ── Empty State ───────────────────────────────────────────
            .overlay {
                if mappableDives.isEmpty {
                    emptyState
                }
            }

            // ── Dive Site Sheet ───────────────────────────────────────
            // Using isPresented (not item:) so sheet stays open when
            // selectedDive changes to a different pin.
            .sheet(isPresented: $isSheetPresented, onDismiss: {
                selectedDive = nil
            }) {
                if let dive = selectedDive {
                    DiveSiteSheetView(dive: dive)
                        .presentationDetents([.fraction(0.35), .large])
                        .presentationDragIndicator(.visible)
                        // Map remains fully interactive behind the sheet
                        .presentationBackgroundInteraction(.enabled(upThrough: .large))
                }
            }

            // ── Haptic Feedback ───────────────────────────────────────
            // Fires whenever selectedDive changes (new pin tapped).
            // iOS 17+ API — safe because SwiftData requires iOS 17.
            .sensoryFeedback(
                .impact(flexibility: .solid, intensity: 0.7),
                trigger: selectedDive?.persistentModelID
            )
        }
    }

    // MARK: - Map Type Toggle Button

    private var mapTypeToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                mapType = (mapType == .standard) ? .hybrid : .standard
            }
        } label: {
            Image(systemName: mapType == .standard ? "globe.americas.fill" : "map")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .accessibilityLabel(
            mapType == .standard
                ? String(localized: "Switch to Hybrid Map")
                : String(localized: "Switch to Standard Map")
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            ContentUnavailableView {
                Label(
                    String(localized: "No GPS Dive Sites"),
                    systemImage: "map.fill"
                )
            } description: {
                Text("Dives with GPS coordinates will appear on this map.")
            }

            // 決策 #5：地圖空狀態 inline 廣告（Premium 用戶隱藏）
            PremiumAwareAdBanner(adUnitID: AdUnitID.mapEmptyState)
        }
    }
}

// MARK: - Preview

#Preview {
    MapView()
        .modelContainer(DiveLogDatabase.shared.modelContainer)
}
