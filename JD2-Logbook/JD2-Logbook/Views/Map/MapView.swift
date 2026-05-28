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
    /// The dive whose detail (sheet on iOS / side panel on macOS) is shown.
    @State private var selectedDive: DiveLog?
    /// Controls sheet presentation (iOS). Kept separate from selectedDive so that
    /// tapping a second pin while the sheet is open updates content without
    /// dismissing and re-presenting.
    @State private var isSheetPresented = false

    // MARK: - Body

    var body: some View {
        // macOS：NavigationStack 由 MainTabView 容器層提供（避免雙層 nav bar 產生頂部空白）
        #if os(iOS)
        NavigationStack { iosMapContent }
        #else
        macMapContent
        #endif
    }

    // MARK: - Shared Map Pane（地圖 + 控制按鈕 + 空狀態）

    private var mapPane: some View {
        ZStack(alignment: .topTrailing) {

            // ── Map ───────────────────────────────────────────────
            DiveMapRepresentable(
                dives:              mappableDives,
                mapType:            $mapType,
                selectedDive:       selectedDive,
                onAnnotationTapped: { dive in
                    selectedDive = dive
                    #if os(iOS)
                    isSheetPresented = true
                    #endif
                }
            )
            .ignoresSafeArea(edges: .bottom)

            // ── 懸浮控制按鈕（圖層切換 + 指北）─────────────────────
            controlButtons
                .padding(.top, 8)
                .padding(.trailing, 12)
        }
        .navigationTitle(String(localized: "Map"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .overlay {
            if mappableDives.isEmpty {
                emptyState
            }
        }
    }

    // MARK: - iOS：地圖 + Detent Sheet

    #if os(iOS)
    private var iosMapContent: some View {
        mapPane
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
            .sensoryFeedback(
                .impact(flexibility: .solid, intensity: 0.7),
                trigger: selectedDive?.persistentModelID
            )
    }
    #else

    // MARK: - macOS：地圖 + 右側「浮動」側邊欄（不參與版面競爭，永不擠壓/裁切地圖）

    private var macMapContent: some View {
        HSplitView {
            mapPane
                .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)

            if let dive = selectedDive {
                macSidePanel(dive: dive)
                    .frame(width: 320)
                    .frame(maxHeight: .infinity)
                    .background(Color(NSColor.windowBackgroundColor))
            }
        }
    }

    private func macSidePanel(dive: DiveLog) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Dive Site")
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedDive = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(String(localized: "Close"))
                .accessibilityLabel(String(localized: "Close"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            DiveSiteSheetView(dive: dive)
        }
    }
    #endif

    // MARK: - Control Buttons（僅圖層切換；指北交由 MapKit 內建羅盤）

    private var controlButtons: some View {
        VStack(spacing: 8) {
            mapTypeToggleButton
        }
    }

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
        .buttonStyle(.plain) // 移除 macOS 預設按鈕外框/焦點環（半透明白圈）
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
