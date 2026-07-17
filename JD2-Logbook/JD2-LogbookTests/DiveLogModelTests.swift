// DiveLogModelTests.swift — JD2-LogbookTests
// v1.1 #6/#7/#8/#14：DiveLog 新增欄位、剖面樣本水溫、備份 Codable round-trip 單元測試

import XCTest
@testable import JoyDive_

final class DiveLogModelTests: XCTestCase {

    private func makeDive(profileSamples: [DiveProfileSample] = [], diveTimeSeconds: Int = 3600) -> DiveLog {
        let dive = DiveLog(
            dateTime: Date(timeIntervalSince1970: 1_700_000_000),
            location: "Test Site",
            maxDepth: 20.0,
            diveTimeSeconds: diveTimeSeconds,
            gasMixJSON: "\"air\"",
            waterTemperature: 25.0
        )
        if !profileSamples.isEmpty,
           let data = try? JSONEncoder().encode(profileSamples),
           let json = String(data: data, encoding: .utf8) {
            dive.profileSamplesJSON = json
        }
        return dive
    }

    // MARK: - importExtras（v1.1 #6/#7）

    func testImportExtrasDefaultsToEmptyDict() {
        let dive = makeDive()
        XCTAssertEqual(dive.importExtrasJSON, "{}")
        XCTAssertTrue(dive.importExtras.isEmpty)
    }

    func testImportExtrasDecodesKeyValuePairs() {
        let dive = makeDive()
        dive.importExtrasJSON = "{\"buddy\":\"Alice\",\"deviceSerial\":\"SN123\"}"
        let extras = dive.importExtras
        XCTAssertEqual(extras["buddy"], "Alice")
        XCTAssertEqual(extras["deviceSerial"], "SN123")
    }

    func testImportExtrasInvalidJSONReturnsEmptyDict() {
        let dive = makeDive()
        dive.importExtrasJSON = "not valid json"
        XCTAssertTrue(dive.importExtras.isEmpty)
    }

    func testBuildImportExtrasJSONEmptyPairsReturnsEmptyObject() {
        XCTAssertEqual(buildImportExtrasJSON([]), "{}")
    }

    func testBuildImportExtrasJSONRoundTrips() {
        let json = buildImportExtrasJSON([("buddy", "Bob"), ("tags", "wreck,deep")])
        guard let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            XCTFail("應可解碼回 [String:String]")
            return
        }
        XCTAssertEqual(dict["buddy"], "Bob")
        XCTAssertEqual(dict["tags"], "wreck,deep")
    }

    // MARK: - avgDepth 梯形重建（v1.1 #8）

    func testReconstructedAvgDepthFlatProfile() {
        // 全程等深 10m → 平均深度應等於 10m
        let samples = [
            DiveProfileSample(timeSeconds: 0,    depthMeters: 10),
            DiveProfileSample(timeSeconds: 1800, depthMeters: 10),
        ]
        let dive = makeDive(profileSamples: samples, diveTimeSeconds: 1800)
        XCTAssertEqual(dive.reconstructedAvgDepth(), 10.0, accuracy: 0.01)
    }

    func testReconstructedAvgDepthTriangularProfile() {
        // 0 → 20m → 0，線性下潛/上升，時間對稱 → 平均深度應為 10m
        let samples = [
            DiveProfileSample(timeSeconds: 0,    depthMeters: 0),
            DiveProfileSample(timeSeconds: 600,  depthMeters: 20),
            DiveProfileSample(timeSeconds: 1200, depthMeters: 0),
        ]
        let dive = makeDive(profileSamples: samples, diveTimeSeconds: 1200)
        XCTAssertEqual(dive.reconstructedAvgDepth(), 10.0, accuracy: 0.01)
    }

    func testReconstructedAvgDepthAccountsForTailBeyondLastSample() {
        // 最後樣本在 t=1000（10m），但潛水時長 1200s → 尾段 200s 需補積分（審計 G4 邊界修正）
        let samples = [
            DiveProfileSample(timeSeconds: 0,    depthMeters: 10),
            DiveProfileSample(timeSeconds: 1000, depthMeters: 10),
        ]
        let dive = makeDive(profileSamples: samples, diveTimeSeconds: 1200)
        // 全程恆定 10m（含尾段）→ 平均深度仍應為 10m，而非因漏算尾段被低估
        XCTAssertEqual(dive.reconstructedAvgDepth(), 10.0, accuracy: 0.01)
    }

    func testReconstructedAvgDepthInsufficientSamplesReturnsZero() {
        let dive = makeDive(profileSamples: [DiveProfileSample(timeSeconds: 0, depthMeters: 10)])
        XCTAssertEqual(dive.reconstructedAvgDepth(), 0)
    }

    // MARK: - DiveProfileSample 水溫（w，v1.1 #4，additive optional）

    func testProfileSampleWaterTempEncodesWhenPresent() throws {
        let sample = DiveProfileSample(timeSeconds: 10, depthMeters: 5, waterTemp: 26.5)
        let data = try JSONEncoder().encode(sample)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("\"w\""), "有水溫時應編碼 w 欄位")
    }

    func testProfileSampleWaterTempOmittedWhenNil() throws {
        let sample = DiveProfileSample(timeSeconds: 10, depthMeters: 5)
        let data = try JSONEncoder().encode(sample)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("\"w\""), "無水溫時不應輸出 w 欄位")
    }

    func testProfileSampleDecodesOldFormatWithoutWaterTemp() throws {
        // 舊資料格式 {t,d}（無 w）應優雅降級解碼為 waterTemp = nil
        let json = "{\"t\":10.0,\"d\":5.0}".data(using: .utf8)!
        let sample = try JSONDecoder().decode(DiveProfileSample.self, from: json)
        XCTAssertEqual(sample.timeSeconds, 10.0)
        XCTAssertEqual(sample.depthMeters, 5.0)
        XCTAssertNil(sample.waterTemp)
    }

    // MARK: - Export/Import 備份 round-trip（v1.1 #14）

    func testDiveLogBackupEntryRoundTrip() {
        let original = makeDive(profileSamples: [
            DiveProfileSample(timeSeconds: 0, depthMeters: 0, waterTemp: 27),
            DiveProfileSample(timeSeconds: 60, depthMeters: 10, waterTemp: 25),
        ])
        original.avgDepth = 8.5
        original.importExtrasJSON = "{\"buddy\":\"Carol\"}"
        original.notes = "Great dive"

        let entry = DiveLogBackupEntry(from: original)
        let restored = entry.makeDiveLog()

        XCTAssertEqual(restored.location, original.location)
        XCTAssertEqual(restored.maxDepth, original.maxDepth)
        XCTAssertEqual(restored.diveTimeSeconds, original.diveTimeSeconds)
        XCTAssertEqual(restored.avgDepth, 8.5, accuracy: 0.001)
        XCTAssertEqual(restored.importExtrasJSON, "{\"buddy\":\"Carol\"}")
        XCTAssertEqual(restored.notes, "Great dive")
        XCTAssertEqual(restored.profileSamples.count, 2)
        XCTAssertEqual(restored.profileSamples[0].waterTemp ?? 0, 27, accuracy: 0.001)
    }

    func testDiveLogBackupJSONEncodeDecodeRoundTrip() throws {
        let dive = makeDive()
        dive.avgDepth = 12.3
        let backup = DiveLogBackup(appVersion: "1.1", dives: [DiveLogBackupEntry(from: dive)])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DiveLogBackup.self, from: data)

        XCTAssertEqual(decoded.dives.count, 1)
        XCTAssertEqual(decoded.dives[0].avgDepth, 12.3, accuracy: 0.001)
        XCTAssertEqual(decoded.appVersion, "1.1")
    }
}
