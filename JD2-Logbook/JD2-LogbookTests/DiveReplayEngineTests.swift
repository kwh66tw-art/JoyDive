// DiveReplayEngineTests.swift — JD2-LogbookTests
// v1.1 #4/#5/#13：DiveReplayEngine（DiveKit 重放）單元測試

import XCTest
import DiveKit
@testable import JoyDive_

@MainActor
final class DiveReplayEngineTests: XCTestCase {

    func testTooFewSamplesReturnsEmptyResult() {
        let result = DiveReplayEngine.replay(
            samples: [DiveKit.DiveProfileSample(timeSeconds: 0, depthMeters: 10)],
            gasMix: .air
        )
        XCTAssertTrue(result.points.isEmpty)
        XCTAssertFalse(result.enteredDeco)
    }

    func testShallowShortDiveNeverEntersDeco() {
        // 12m、10 分鐘：遠低於 NDL 極限，不應觸發減壓天花板
        let samples = [
            DiveKit.DiveProfileSample(timeSeconds: 0,   depthMeters: 0),
            DiveKit.DiveProfileSample(timeSeconds: 60,  depthMeters: 12),
            DiveKit.DiveProfileSample(timeSeconds: 540, depthMeters: 12),
            DiveKit.DiveProfileSample(timeSeconds: 600, depthMeters: 0),
        ]
        let result = DiveReplayEngine.replay(samples: samples, gasMix: .air)
        XCTAssertFalse(result.points.isEmpty)
        XCTAssertFalse(result.enteredDeco, "淺潛短時間不應進入減壓")
        XCTAssertEqual(result.maxCeilingMeters, 0)
        XCTAssertEqual(result.finalTissuePN2.count, 16, "應回傳 16 個隔室的最終氮分壓")
    }

    func testDeepLongDiveEntersDecoAndProducesNDL() {
        // 40m、40 分鐘的底部時間：應超過 NDL，進入減壓天花板 > 0
        var samples: [DiveKit.DiveProfileSample] = [DiveKit.DiveProfileSample(timeSeconds: 0, depthMeters: 0)]
        samples.append(DiveKit.DiveProfileSample(timeSeconds: 120, depthMeters: 40))
        for minute in stride(from: 3, through: 40, by: 1) {
            samples.append(DiveKit.DiveProfileSample(timeSeconds: Double(minute * 60), depthMeters: 40))
        }
        let result = DiveReplayEngine.replay(samples: samples, gasMix: .air)
        XCTAssertTrue(result.enteredDeco, "40m/40min 應超過免減壓極限")
        XCTAssertGreaterThan(result.maxCeilingMeters, 0)
    }

    func testNDLDecreasesAsBottomTimeAccumulates() {
        let samples = (0...20).map { i in
            DiveKit.DiveProfileSample(timeSeconds: Double(i * 60), depthMeters: i == 0 ? 0 : 30)
        }
        let result = DiveReplayEngine.replay(samples: samples, gasMix: .air)
        guard let first = result.points.first(where: { $0.depthMeters >= 29 }),
              let last = result.points.last else {
            XCTFail("應有底部深度樣本")
            return
        }
        XCTAssertLessThanOrEqual(last.ndlSeconds, first.ndlSeconds, "隨底部時間累積，NDL 應遞減或持平")
    }
}
