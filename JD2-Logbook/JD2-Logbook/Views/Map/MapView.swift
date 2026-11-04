// MapView.swift — JD2-Logbook/Views/Map/
// Week 10 — GPS map with dive site pins, native clustering, and Medium Detent Sheet
//
// Interaction model (Oceanic+ inspired):
//   • Tap a pin           → sheet appears at 0.35 detent (peek: location + date + stats)
//   • Tap a different pin → sheet content updates in-place, haptic fires; sheet stays open
//   • Pull sheet up       → .large detent reveals full dive details
//   • Swipe sheet down    → dismisses; map pin deselects via onDismiss
//   • Tap cluster badge   → map zooms in to fit member pins (handled in Coordinator);
//                           can't split (same coordinates / max zoom) → list of dives there (v1.4 B2)
//   • Detail page coords  → switches to this tab, selects + centers that dive (v1.4 B1, `MapFocusRequest`)
//   • Top-right button    → toggles Standard / Hybrid map layer

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct MapView: View {

    @Environment(AppLanguageManager.self) private var languageManager

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
    /// v1.4 B2：聚合點拆不開時列出的潛水（非空且尚未選取 ⇒ 卡片／面板顯示清單）。
    @State private var clusterDives: [DiveLog] = []

    /// v1.4 B1：詳細頁「在地圖上顯示」的請求（`MainTabView` 注入；預覽沒有 ⇒ nil）。
    @Environment(MapFocusRequest.self) private var mapFocus: MapFocusRequest?

    // v1.1 #11：回到我的位置。開關本身在 Settings 頁，這裡只讀取。
    @AppStorage(UserLocationProvider.isEnabledKey) private var gpsLocationEnabled = false
    @State private var locationProvider = UserLocationProvider()
    @State private var recenterCoordinate: CLLocationCoordinate2D?
    /// v1.4 B1：「在地圖上顯示」的目標；地圖依資料算縮放後置中（`DiveMapRepresentable.focusRect`），與「回到我的位置」分開。
    @State private var focusZoomTargetID: PersistentIdentifier?

    private var showsUserLocationDot: Bool {
        gpsLocationEnabled && locationProvider.authorizationStatus.isAuthorizedForRecenter
    }

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
                showsUserLocation:  showsUserLocationDot,
                recenterCoordinate: $recenterCoordinate,
                focusZoomTargetID:  $focusZoomTargetID,
                onAnnotationTapped: { dive in
                    clusterDives = []
                    selectedDive = dive
                    #if os(iOS)
                    isSheetPresented = true
                    #endif
                },
                onClusterListRequested: { dives in
                    selectedDive = nil
                    clusterDives = dives
                    #if os(iOS)
                    isSheetPresented = true
                    #endif
                }
            )
            .ignoresSafeArea(edges: .bottom)

            // ── 懸浮控制按鈕（圖層切換 + 指北 + 回到我的位置）───────
            controlButtons
                .padding(.top, 8)
                .padding(.trailing, 12)
        }
        .onAppear {
            locationProvider.onLocationUpdate = { location in
                recenterCoordinate = location.coordinate
            }
            handleFocusRequest()
        }
        .onChange(of: mapFocus?.targetDiveID) { _, _ in handleFocusRequest() }
        .navigationTitle(Text(verbatim: languageManager.localized("Map")))
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
                clusterDives = []
            }) {
                // 以 Binding 傳入：body 本身不讀 `clusterDives`，若在閉包內直接讀會拿到舊值（卡片空白，11/01 實測）。
                IOSMapSheetContent(selectedDive: $selectedDive, clusterDives: $clusterDives)
                .presentationDetents([.fraction(0.35), .large])
                .presentationDragIndicator(.visible)
                // Map remains fully interactive behind the sheet
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
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

            if selectedDive != nil || !clusterDives.isEmpty {
                macSidePanel
                    .frame(width: 320)
                    .frame(maxHeight: .infinity)
                    .background(Color(NSColor.windowBackgroundColor))
            }
        }
    }

    private var macSidePanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text(verbatim: languageManager.localized("Dive Site"))
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDive = nil
                        clusterDives = []
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(languageManager.localized("Close"))
                .accessibilityLabel(languageManager.localized("Close"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if let dive = selectedDive {
                DiveSiteSheetView(dive: dive)
            } else {
                DiveSiteClusterList(dives: clusterDives) { dive in selectFromCluster(dive) }
            }
        }
    }
    #endif

    // MARK: - v1.4 B1／B2

    #if os(iOS)
    /// iOS 卡片內容：選取的潛水，或拆不開的聚合點清單（點一筆 ⇒ 換成該筆）。
    private struct IOSMapSheetContent: View {
        @Binding var selectedDive: DiveLog?
        @Binding var clusterDives: [DiveLog]

        var body: some View {
            if let dive = selectedDive {
                DiveSiteSheetView(dive: dive)
            } else if !clusterDives.isEmpty {
                DiveSiteClusterList(dives: clusterDives) { dive in
                    clusterDives = []
                    selectedDive = dive
                }
            }
        }
    }
    #endif

    private func selectFromCluster(_ dive: DiveLog) {
        clusterDives = []
        selectedDive = dive
    }

    /// 取走 `MapFocusRequest` 的目標：選取並置中（D6）。縮放依資料決定（B1，PM 2026-11-04），不沿用「回到我的位置」的範圍；
    /// 座標完全相同的仍聚合，卡片／面板直接顯示這筆，點聚合點照 D7 列清單。
    private func handleFocusRequest() {
        guard let id = mapFocus?.take(),
              let dive = mappableDives.first(where: { $0.persistentModelID == id }),
              dive.latitude != nil, dive.longitude != nil else { return }
        clusterDives = []
        selectedDive = dive
        focusZoomTargetID = id
        #if os(iOS)
        isSheetPresented = true
        #endif
    }

    // MARK: - Control Buttons（圖層切換 + 回到我的位置；指北交由 MapKit 內建羅盤）

    private var controlButtons: some View {
        VStack(spacing: 8) {
            mapTypeToggleButton
            // v1.1 #11：僅在 Settings 開啟 GPS 定位後才出現，關閉時整個按鈕不存在
            if gpsLocationEnabled {
                recenterButton
            }
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
                ? languageManager.localized("Switch to Hybrid Map")
                : languageManager.localized("Switch to Standard Map")
        )
    }

    /// v1.1 #11：授權中／已授權 → 一般樣式，按下觸發單次定位；
    /// 被拒絕／受限 → 灰階樣式，按下改為導去系統設定（呼應 Settings 頁同款按鈕）。
    private var recenterButton: some View {
        let isDenied = locationProvider.authorizationStatus == .denied
            || locationProvider.authorizationStatus == .restricted

        return Button {
            if isDenied {
                openSystemLocationSettingsFromMap()
            } else {
                locationProvider.requestOneShotLocation()
            }
        } label: {
            Image(systemName: isDenied ? "location.slash.fill" : "location.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isDenied ? .secondary : .primary)
                .frame(width: 40, height: 40)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(languageManager.localized("Recenter on My Location"))
        .accessibilityHint(isDenied ? languageManager.localized("Location Access Denied") : "")
    }

    private func openSystemLocationSettingsFromMap() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #else
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }


    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            ContentUnavailableView {
                Label(
                    languageManager.localized("No GPS Dive Sites"),
                    systemImage: "map.fill"
                )
            } description: {
                Text(verbatim: languageManager.localized("Dives with GPS coordinates will appear on this map."))
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
