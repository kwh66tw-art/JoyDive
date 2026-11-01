// MapClusterAndFocusTests.swift — JD2-LogbookTests
// v1.4 B1／B2（PM 2026-10-26，D6／D7；`docs/decisions/D-2026-10-26-v1.4-D3至D7裁示.md`）。
// B2：點聚合點 ⇒ 座標完全相同或已無法再放大就列清單，否則放大——不自訂距離門檻。
// B1：「在地圖上顯示」請求只被處理一次。

import XCTest
import Foundation
import MapKit
import SwiftData
@testable import JoyDive_

@MainActor
final class MapClusterAndFocusTests: XCTestCase {

    private func coordinate(_ lat: Double, _ lon: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: B2 聚合點

    func testIdenticalCoordinatesAlwaysList() {
        let same = [coordinate(22.0298, 121.5342), coordinate(22.0298, 121.5342), coordinate(22.0298, 121.5342)]
        // 即使地圖還能再放大，座標完全相同也拆不開 ⇒ 直接列清單（D7 ①）
        XCTAssertEqual(DiveMapCoordinator.clusterResolution(memberCoordinates: same,
                                                            visibleWidthBefore: 1000, visibleWidthAfterFit: 10), .list)
    }

    func testDistinctCoordinatesZoomWhileMapCanStillZoomIn() {
        let near = [coordinate(22.0298, 121.5342), coordinate(22.0299, 121.5343)]
        XCTAssertEqual(DiveMapCoordinator.clusterResolution(memberCoordinates: near,
                                                            visibleWidthBefore: 1000, visibleWidthAfterFit: 10), .zoom)
    }

    /// D7 ②：框住成員後可見範圍沒有變小（MapKit 已到縮放上限）⇒ 列清單。
    func testDistinctCoordinatesListWhenMapCannotZoomFurther() {
        let near = [coordinate(22.0298, 121.5342), coordinate(22.02980001, 121.53420001)]
        XCTAssertEqual(DiveMapCoordinator.clusterResolution(memberCoordinates: near,
                                                            visibleWidthBefore: 50, visibleWidthAfterFit: 50), .list)
        XCTAssertEqual(DiveMapCoordinator.clusterResolution(memberCoordinates: near,
                                                            visibleWidthBefore: 50, visibleWidthAfterFit: 60), .list,
                       "框住成員反而要縮小（不該發生）時也不放大，改列清單")
    }

    /// 同一緯度、經度只差最後一位也算「不同座標」——判斷是精確相等，不是容差。
    func testIdentityIsExactNotTolerance() {
        let almost = [coordinate(22.0298, 121.5342), coordinate(22.0298, 121.53420000001)]
        XCTAssertEqual(DiveMapCoordinator.clusterResolution(memberCoordinates: almost,
                                                            visibleWidthBefore: 1000, visibleWidthAfterFit: 10), .zoom)
    }

    // MARK: B1 地圖跳轉請求

    /// 刻意不釋放：`MapFocusRequest`（`@MainActor @Observable`）在測試中被釋放會 SIGABRT
    /// （2026-11-01 crash report，同 `EnvironmentUnrecordedTests` 的 `AppLanguageManager`）。
    private static let request = MapFocusRequest()

    func testFocusRequestIsTakenOnce() throws {
        let container = try ModelContainer(for: DiveLog.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let dive = DiveLog(dateTime: Date(timeIntervalSince1970: 1_700_000_000), location: "B1",
                           maxDepth: 18, diveTimeSeconds: 2400)
        context.insert(dive)
        try context.save()

        let request = Self.request
        _ = request.take()
        XCTAssertNil(request.take())
        request.focus(on: dive)
        XCTAssertEqual(request.targetDiveID, dive.persistentModelID)
        XCTAssertEqual(request.take(), dive.persistentModelID)
        XCTAssertNil(request.targetDiveID, "取走即清空，切回地圖分頁不會重複套用")
        XCTAssertNil(request.take())
    }
}
