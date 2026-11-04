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
    /// v1.4 B2：聚合點拆不開時，改列出該處的潛水（`clusterResolution`）。
    var onClusterListRequested: ([DiveLog]) -> Void
    /// 首次 zoom-to-fit 是否已完成。置於 coordinator（reference type），
    /// 可在 update 內「同步」設值 → 杜絕重複 async fit 排程。
    var hasZoomedToFit = false
    /// 已平移置中過的潛點 ID，確保每次選取只置中一次。
    var lastCenteredID: PersistentIdentifier? = nil

    // ── v1.4 B1-A：聚合點名稱與選取標示由我們決定（`DiveClusterLabeling`）──
    /// 目前選取的潛水；聚合點依它決定名稱與選取標示。由 `_updateMapView` 設定。
    var selectedDiveID: PersistentIdentifier? = nil
    /// 上一次據以產生聚合點的選取；與 `selectedDiveID` 不同時要重新聚合。
    var labeledSelectionID: PersistentIdentifier? = nil
    var unknownLocationText = ""
    var multipleSitesText = ""
    /// 「+其他 N 筆」：MapKit 原生 subtitle 只跟啟動時的語言，App 內切換語言後不會更新（11/04 實測）⇒ 自己產生，走 languageManager。
    var othersFormat = ""
    var locale = Locale.current

    init(onAnnotationTapped: @escaping (DiveLog) -> Void,
         onClusterListRequested: @escaping ([DiveLog]) -> Void) {
        self.onAnnotationTapped = onAnnotationTapped
        self.onClusterListRequested = onClusterListRequested
    }

    /// 點聚合點的處置（D7，PM 2026-10-26：不錯開圖釘、**不自訂距離門檻**）：
    /// ① 成員座標完全相同 ⇒ 列清單（再怎麼放大都拆不開）；
    /// ② 否則照常放大到框住成員；若地圖已無法再放大（可見範圍沒有變小）⇒ 列清單。
    /// ②的判斷交給 MapKit 自己的縮放上限，不另算公尺數。
    enum ClusterTapResolution: Equatable { case list, zoom }

    static func clusterResolution(memberCoordinates: [CLLocationCoordinate2D],
                                  visibleWidthBefore: Double,
                                  visibleWidthAfterFit: Double) -> ClusterTapResolution {
        if let first = memberCoordinates.first,
           memberCoordinates.allSatisfy({ $0.latitude == first.latitude && $0.longitude == first.longitude }) {
            return .list
        }
        return visibleWidthAfterFit < visibleWidthBefore ? .zoom : .list
    }

    // MARK: 聚合點（B1-A）

    /// 自建聚合點，名稱依 `DiveClusterLabeling` 決定，不讓 MapKit 從成員中任挑一筆。
    /// 出處：MapKit `MKMapView.h:345` `mapView(_:clusterAnnotationForMemberAnnotations:)`——
    ///       "it is illegal to return a cluster annotation not containing the identical array of member annotations given."
    /// 查證：標頭沒說原生 subtitle 的語言；實測（11/04）原生 subtitle 只跟啟動時的語言，App 內切換後不變 ⇒ subtitle 也自己產生。
    /// 驗證：`DiveClusterLabelTests`（規則①–④）＋模擬器／macOS 實測，見決策檔。
    func mapView(_ mapView: MKMapView,
                 clusterAnnotationForMemberAnnotations memberAnnotations: [MKAnnotation]) -> MKClusterAnnotation {
        let cluster = MKClusterAnnotation(memberAnnotations: memberAnnotations)
        cluster.title = clusterLabel(for: memberAnnotations).title
        cluster.subtitle = String(format: othersFormat, locale: locale, memberAnnotations.count - 1)
        return cluster
    }

    func clusterLabel(for memberAnnotations: [MKAnnotation]) -> DiveClusterLabel {
        let dives = memberAnnotations.compactMap { ($0 as? DiveSiteAnnotation)?.dive }
        return DiveClusterLabeling.label(
            memberLocations: dives.map(\.location),
            selectedIndex: selectedDiveID.flatMap { id in dives.firstIndex { $0.persistentModelID == id } },
            unknownLocationText: unknownLocationText,
            multipleSitesText: multipleSitesText)
    }

    /// 含選取潛水的聚合點，顏色沿用單筆潛點圖釘的藍色（`DiveSiteAnnotationView`）；其餘維持 MapKit 原生顏色（nil）。
    func applyClusterHighlight(to view: MKAnnotationView) {
        guard let cluster = view.annotation as? MKClusterAnnotation,
              let marker = view as? MKMarkerAnnotationView else { return }
        #if os(iOS)
        let wanted: UIColor? = clusterLabel(for: cluster.memberAnnotations).containsSelection ? .systemBlue : nil
        #else
        let wanted: NSColor? = clusterLabel(for: cluster.memberAnnotations).containsSelection ? .systemBlue : nil
        #endif
        if marker.markerTintColor != wanted { marker.markerTintColor = wanted }
    }

    /// 聚合點的 view 被加上地圖（含重用）時套用選取標示。
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        for view in views where view.annotation is MKClusterAnnotation {
            applyClusterHighlight(to: view)
        }
    }

    // MARK: viewFor annotation

    func mapView(_ mapView: MKMapView,
                 viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }

        if annotation is MKClusterAnnotation {
            // 回傳 nil → 交給 MapKit 原生預設聚合徽章（系統自動算繪數字、自管重用）
            return nil
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
            mapView.deselectAnnotation(cluster, animated: false)
            let members = cluster.memberAnnotations.compactMap { $0 as? DiveSiteAnnotation }
            // 先不帶動畫試算「框住成員」後的可見範圍，再還原、決定要放大還是列清單。
            // 同一個 run loop 內設定再還原，畫面不會畫出中間狀態。
            let before = mapView.visibleMapRect
            mapView.showAnnotations(cluster.memberAnnotations, animated: false)
            let fitted = mapView.visibleMapRect
            mapView.setVisibleMapRect(before, animated: false)

            switch Self.clusterResolution(memberCoordinates: members.map(\.coordinate),
                                          visibleWidthBefore: before.size.width,
                                          visibleWidthAfterFit: fitted.size.width) {
            case .zoom:
                mapView.setVisibleMapRect(fitted, animated: true)
            case .list:
                onClusterListRequested(members.map(\.dive))
            }
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
    /// 目前選取的潛點，用於大頭針選取狀態雙向同步 + 自動置中。
    var selectedDive: DiveLog?
    /// 是否顯示系統藍點（僅在使用者於 Settings 開啟 GPS 定位且系統已授權時為 true）。
    var showsUserLocation: Bool = false
    /// v1.1 #11：recenter 按鈕觸發的目標座標；套用後由 _updateMapView 清空。
    @Binding var recenterCoordinate: CLLocationCoordinate2D?
    /// v1.4 B1：「在地圖上顯示」的目標；套用依資料算出的縮放後由 _updateMapView 清空。
    @Binding var focusZoomTargetID: PersistentIdentifier?
    var onAnnotationTapped: (DiveLog) -> Void
    /// v1.4 B2：聚合點拆不開 ⇒ 列出該處潛水。
    var onClusterListRequested: ([DiveLog]) -> Void = { _ in }

    @Environment(AppLanguageManager.self) private var languageManager

    func makeCoordinator() -> DiveMapCoordinator {
        DiveMapCoordinator(onAnnotationTapped: onAnnotationTapped,
                           onClusterListRequested: onClusterListRequested)
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
    /// 目前選取的潛點，用於大頭針選取狀態雙向同步 + 自動置中。
    var selectedDive: DiveLog?
    /// 是否顯示系統藍點（僅在使用者於 Settings 開啟 GPS 定位且系統已授權時為 true）。
    var showsUserLocation: Bool = false
    /// v1.1 #11：recenter 按鈕觸發的目標座標；套用後由 _updateMapView 清空。
    @Binding var recenterCoordinate: CLLocationCoordinate2D?
    /// v1.4 B1：「在地圖上顯示」的目標；套用依資料算出的縮放後由 _updateMapView 清空。
    @Binding var focusZoomTargetID: PersistentIdentifier?
    var onAnnotationTapped: (DiveLog) -> Void
    /// v1.4 B2：聚合點拆不開 ⇒ 列出該處潛水。
    var onClusterListRequested: ([DiveLog]) -> Void = { _ in }

    @Environment(AppLanguageManager.self) private var languageManager

    func makeCoordinator() -> DiveMapCoordinator {
        DiveMapCoordinator(onAnnotationTapped: onAnnotationTapped,
                           onClusterListRequested: onClusterListRequested)
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

    /// v1.4 B1（PM 2026-11-04）：跳轉時讓目標和其他潛點在畫面上至少相隔一個圖釘，算出所需縮放；只放大、不縮小。
    /// 出處：MapKit `MKAnnotationView.h:161` "Default collision mode is rectangle."；`:149` 相同 clusteringIdentifier 的 view 可聚合。
    /// 查證：標頭沒寫「聚合＝圖釘矩形重疊」，以「兩個圖釘矩形不重疊就不聚合」為推論；矩形 ⇒ 水平差 ≥ 寬或垂直差 ≥ 高即不重疊。
    ///       實測（11/04）：貼邊或多 1 像素仍會聚合，MapKit 另有未公開間距 ⇒ 最近一筆可能仍與目標聚合，點它照 D7 處理（已知行為）。
    ///       座標完全相同的不列入（本來就是同一地點，維持聚合，點聚合點照 D7 列清單）。超過 MapKit 縮放上限時由 MapKit 夾住。
    /// 驗證：iOS 模擬器實測見 `docs/decisions/D-2026-10-26-v1.4-D3至D7裁示.md`「B1 重開」節。
    static func focusRect(for targetID: PersistentIdentifier, dives: [DiveLog], in mapView: MKMapView) -> MKMapRect? {
        guard let target = dives.first(where: { $0.persistentModelID == targetID }),
              let lat = target.latitude, let lon = target.longitude else { return nil }
        let center = MKMapPoint(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        let pinSize = markerSize(in: mapView)
        // 每 pt 的 map point 數：目前值，以及每個鄰居要求的上限，取最小（只放大）。
        var mapPointsPerPt = mapView.visibleMapRect.size.width / Double(mapView.bounds.width)
        for dive in dives where dive.persistentModelID != targetID {
            guard let dLat = dive.latitude, let dLon = dive.longitude, dLat != lat || dLon != lon else { continue }
            let p = MKMapPoint(CLLocationCoordinate2D(latitude: dLat, longitude: dLon))
            let needed = max(abs(p.x - center.x) / Double(pinSize.width), abs(p.y - center.y) / Double(pinSize.height))
            mapPointsPerPt = min(mapPointsPerPt, needed)
        }
        let size = MKMapSize(width: mapPointsPerPt * Double(mapView.bounds.width),
                             height: mapPointsPerPt * Double(mapView.bounds.height))
        var rect = MKMapRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
        // MapKit 套用時會調整範圍（11/04 實測：要求 0.570 m／pt，實得 0.640）⇒ 先用 MapKit 自己的 mapRectThatFits 問它會變成多大，
        // 再依比例縮小，讓實際結果符合需要的縮放。
        let fitted = mapView.mapRectThatFits(rect)
        let fittedPerPt = fitted.size.width / Double(mapView.bounds.width)
        if fittedPerPt > mapPointsPerPt {
            let shrink = mapPointsPerPt / fittedPerPt
            rect = MKMapRect(x: center.x - size.width * shrink / 2, y: center.y - size.height * shrink / 2,
                             width: size.width * shrink, height: size.height * shrink)
        }
        return rect
    }

    /// 圖釘實際大小：讀地圖上現有的潛點圖釘；都沒有（全被聚合）時建一個同類別的 view 讀它的大小。
    static func markerSize(in mapView: MKMapView) -> CGSize {
        if let size = mapView.annotations.lazy
            .filter({ $0 is DiveSiteAnnotation })
            .compactMap({ mapView.view(for: $0)?.frame.size })
            .first(where: { $0.width > 0 && $0.height > 0 }) {
            return size
        }
        return DiveSiteAnnotationView(annotation: nil, reuseIdentifier: nil).frame.size
    }

    func _makeMapView(_ coordinator: DiveMapCoordinator) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate           = coordinator
        mapView.mapType            = mapType
        mapView.showsUserLocation  = false
        // 關閉旋轉：潛水世界地圖維持正北朝上即可。
        // 這一併解決 MapKit 內建的「旋轉後自動彈回正北」與羅盤跨平台不一致問題。
        mapView.isRotateEnabled    = false
        // 不顯示羅盤（既然不旋轉，永遠正北，兩平台一致：都不出現）。
        mapView.showsCompass       = false
        mapView.showsScale         = true

        mapView.register(
            DiveSiteAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: DiveSiteAnnotationView.reuseID
        )
        // cluster 不註冊自訂類別：viewFor 回傳 nil，用 MapKit 原生預設聚合徽章。

        return mapView
    }

    func _updateMapView(_ mapView: MKMapView, coordinator: DiveMapCoordinator) {
        // 更新 callback 防止 stale closure
        coordinator.onAnnotationTapped = onAnnotationTapped
        coordinator.onClusterListRequested = onClusterListRequested
        coordinator.unknownLocationText = languageManager.localized("Unknown Location")
        coordinator.othersFormat = languageManager.localized("+%lld more")
        coordinator.locale = languageManager.locale
        let multipleSitesText = languageManager.localized("Multiple Dive Sites")
        // App 內語言切換後，既有聚合點的名稱要跟著換 ⇒ 全部重新聚合（移除再加回）。
        let languageChanged = !coordinator.multipleSitesText.isEmpty && coordinator.multipleSitesText != multipleSitesText
        coordinator.multipleSitesText = multipleSitesText
        coordinator.selectedDiveID = selectedDive?.persistentModelID

        // ── Map type ─────────────────────────────────────────────────
        if mapView.mapType != mapType {
            mapView.mapType = mapType
        }

        // ── 使用者定位藍點（v1.1 #11）───────────────────────────────
        if mapView.showsUserLocation != showsUserLocation {
            mapView.showsUserLocation = showsUserLocation
        }

        // ── Recenter on my location（v1.1 #11）─────────────────────────
        // 套用後立即清空 binding，避免同一個座標重複觸發置中。
        if let coordinate = recenterCoordinate {
            let region = MKCoordinateRegion(
                center: coordinate,
                span:   MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            DispatchQueue.main.async {
                mapView.setRegion(region, animated: true)
                recenterCoordinate = nil
            }
        }

        // ── v1.4 B1：「在地圖上顯示」——依資料決定縮放（不沿用上方「回到我的位置」的 0.05°）──
        // 剛切到地圖分頁時 bounds 可能還是 0 ⇒ 留著請求，等下一次 update 再套用。
        if let targetID = focusZoomTargetID {
            DispatchQueue.main.async {
                guard focusZoomTargetID == targetID, mapView.bounds.width > 0,
                      let rect = Self.focusRect(for: targetID, dives: dives, in: mapView) else { return }
                // 這次縮放已以目標為中心：標記為已置中，下方選取同步就不再 setCenter（帶動畫的 setCenter 會打斷這段縮放，
                // 地圖停在原本的遠景——11/04 實測：FOCUS 後 4 ms 被 setCenter 蓋掉）。
                coordinator.lastCenteredID = targetID
                mapView.setVisibleMapRect(rect, animated: true)
                focusZoomTargetID = nil
            }
        }

        // ── Annotation diff ──────────────────────────────────────────
        let existing = mapView.annotations.compactMap { $0 as? DiveSiteAnnotation }

        // 漏洞 1：對已存在的大頭針即時同步 title/subtitle（編輯潛點後地名/深度更新）
        for annotation in existing {
            if let newDive = dives.first(where: { $0.persistentModelID == annotation.dive.persistentModelID }) {
                let newTitle = newDive.location.isEmpty
                    ? languageManager.localized("Unknown Location") : newDive.location
                if annotation.title != newTitle { annotation.title = newTitle }
                // v1.2 #4：非 SwiftUI View，不能用 @AppStorage，直接讀同一個 UserDefaults key。
                let unitSystem = UnitSystem(rawValue: UserDefaults.standard.string(forKey: UnitSystem.storageKey) ?? "") ?? .metric
                let newSubtitle = unitSystem.formatDepth(newDive.maxDepth)
                if annotation.subtitle != newSubtitle { annotation.subtitle = newSubtitle }
            }
        }

        let newIDs = Set(dives.map { $0.persistentModelID })
        let toRemove = existing.filter { !newIDs.contains($0.dive.persistentModelID) }
        if !toRemove.isEmpty {
            mapView.removeAnnotations(toRemove)
        }

        let currentIDs = Set(
            mapView.annotations
                .compactMap { $0 as? DiveSiteAnnotation }
                .map { $0.dive.persistentModelID }
        )
        let unknownLocationText = languageManager.localized("Unknown Location")
        let toAdd = dives
            .filter { !currentIDs.contains($0.persistentModelID) }
            .map    { DiveSiteAnnotation(dive: $0, unknownLocationText: unknownLocationText) }

        mapView.addAnnotations(toAdd)

        // ── v1.4 B1-A：選取改變（或語言切換）⇒ 讓相關聚合點重新產生，名稱與選取標示才會跟著變 ──
        // 把前後兩筆選取移除再加回，MapKit 會重新聚合並再次呼叫 clusterAnnotationForMemberAnnotations。不靠計時。
        if languageChanged || coordinator.labeledSelectionID != coordinator.selectedDiveID {
            let ids = [coordinator.labeledSelectionID, coordinator.selectedDiveID].compactMap { $0 }
            let affected = mapView.annotations
                .compactMap { $0 as? DiveSiteAnnotation }
                .filter { languageChanged || ids.contains($0.dive.persistentModelID) }
            coordinator.labeledSelectionID = coordinator.selectedDiveID
            if !affected.isEmpty {
                mapView.removeAnnotations(affected)
                mapView.addAnnotations(affected)
            }
        }

        // ── 漏洞 2 + 選取 pin 自動置中（解決卡死 + 推開式面板遮擋）──────────
        // ⚠️ 關鍵：選取/取消選取/置中等會觸發地圖重新佈局的操作，
        // 必須「延後」到 SwiftUI render 之外執行，否則會造成 NSHostingView reentrant
        // layout + AttributeGraph 無窮迴圈（連帶卡頓、clustering 閃失、旋轉彈回正北）。
        DispatchQueue.main.async {
            if let selected = selectedDive {
                let target = mapView.annotations.first {
                    ($0 as? DiveSiteAnnotation)?.dive.persistentModelID == selected.persistentModelID
                } as? DiveSiteAnnotation

                // 確保 MapKit 也選中（支援未來 list→map 跳轉；animated:false 不平移鏡頭）
                let alreadySelected = mapView.selectedAnnotations.contains {
                    ($0 as? DiveSiteAnnotation)?.dive.persistentModelID == selected.persistentModelID
                }
                if !alreadySelected, let target {
                    mapView.selectAnnotation(target, animated: false)
                }

                // 每次選取只置中一次；setCenter 僅平移、保留 heading（不會彈回正北）
                if coordinator.lastCenteredID != selected.persistentModelID, let target {
                    coordinator.lastCenteredID = selected.persistentModelID
                    mapView.setCenter(target.coordinate, animated: true)
                }
            } else {
                // selectedDive 清空（Sheet 滑掉）→ 取消 MapKit 選取，避免再點同一 pin 卡死
                for anno in mapView.selectedAnnotations {
                    mapView.deselectAnnotation(anno, animated: true)
                }
                coordinator.lastCenteredID = nil
            }
        }

        // ── Zoom-to-fit on first load ──
        // ⚠️ 旗標必須在「動作真正執行完」之後才設 true，不能在派送 async 之前就設。
        // 舊寫法在 guard 通過後立刻設 true，再 DispatchQueue.main.async 執行實際 fit；
        // 冷啟動時若該次 async 執行時 annotations 仍是空的（資料尚未載入完成），
        // 內層 guard !all.isEmpty 會直接 return，但旗標早已卡死在 true，
        // 導致地圖永遠不會自動 zoom-to-fit。改為：旗標只在 async 區塊內、
        // 確認真的有 annotation 可以 fit 並執行完 setRegion/showAnnotations 之後才設 true，
        // 且仍在 main.async 開頭做旗標檢查以避免同一次 layout pass 內重複排入 fit。
        guard !coordinator.hasZoomedToFit else { return }

        DispatchQueue.main.async {
            guard !coordinator.hasZoomedToFit else { return }

            let all = mapView.annotations.filter { !($0 is MKUserLocation) }
            guard !all.isEmpty else { return }

            // v1.4 B1：從詳細頁跳過來時已有選取目標，置中由選取／recenter 處理——首次 fit 不得把它蓋掉。
            if selectedDive != nil {
                coordinator.hasZoomedToFit = true
                return
            }

            // animated: false —— 避免首次 fit 的鏡頭動畫在結束時把地圖拉回正北。
            if all.count == 1 {
                let region = MKCoordinateRegion(
                    center: all[0].coordinate,
                    span:   MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                mapView.setRegion(region, animated: false)
            } else {
                mapView.showAnnotations(all, animated: false)
            }

            // 動作真正執行完後才標記完成，避免旗標卡死在「尚未真的 fit 過」的 true。
            coordinator.hasZoomedToFit = true
        }
    }
}
