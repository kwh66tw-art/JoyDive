import XCTest
import Foundation
@testable import JD2Logbook

class UDDFParserTests: XCTestCase {

    var parser: UDDFParser!
    var testDataURL: URL!

    override func setUp() {
        super.setUp()
        parser = UDDFParser()

        // 設定測試資料目錄
        let bundle = Bundle(for: type(of: self))
        testDataURL = bundle.url(forResource: "UDDF", withExtension: nil, subdirectory: "TestData")
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("TestData/UDDF")
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    // MARK: - Basic Functionality Tests

    /// 測試解析單筆簡單潛水記錄
    func testParseSimpleDive() throws {
        // Given: 簡單的 UDDF 檔案
        let testFile = createTemporaryUDDFFile(
            withDives: [
                UDDFTestData(
                    dateTime: "2023-06-15T14:30:00+08:00",
                    diveNumber: "42",
                    location: "Kenting, Taiwan",
                    maxDepth: "25.5",
                    duration: "00:45:30",
                    surfaceTemp: "28",
                    bottomTemp: "24"
                )
            ]
        )
        defer { try? FileManager.default.removeItem(at: testFile) }

        // When: 解析檔案
        let logs = try parser.parse(fileURL: testFile)

        // Then: 驗證結果
        XCTAssertEqual(logs.count, 1, "應該解析出 1 筆潛水記錄")

        let dive = logs[0]
        XCTAssertEqual(dive.diveNumber, 42)
        XCTAssertEqual(dive.location, "Kenting, Taiwan")
        XCTAssertEqual(dive.maxDepth, 25.5, accuracy: 0.01)
        XCTAssertEqual(dive.diveTime, 2730, accuracy: 1) // 45分30秒
        XCTAssertEqual(dive.waterTemp, 28)
    }

    /// 測試解析多筆潛水記錄
    func testParseMultipleDives() throws {
        // Given: 包含 3 筆潛水的 UDDF 檔案
        let testFile = createTemporaryUDDFFile(
            withDives: [
                UDDFTestData(
                    dateTime: "2023-06-15T09:00:00+08:00",
                    diveNumber: "40",
                    location: "Green Island",
                    maxDepth: "18.5",
                    duration: "00:50:00",
                    surfaceTemp: "27",
                    bottomTemp: "26"
                ),
                UDDFTestData(
                    dateTime: "2023-06-15T14:30:00+08:00",
                    diveNumber: "41",
                    location: "Kenting",
                    maxDepth: "25.5",
                    duration: "00:45:30",
                    surfaceTemp: "28",
                    bottomTemp: "24"
                ),
                UDDFTestData(
                    dateTime: "2023-06-16T10:00:00+08:00",
                    diveNumber: "42",
                    location: "Jiaobanshan",
                    maxDepth: "30.0",
                    duration: "01:10:00",
                    surfaceTemp: "27.5",
                    bottomTemp: "23"
                )
            ]
        )
        defer { try? FileManager.default.removeItem(at: testFile) }

        // When: 解析檔案
        let logs = try parser.parse(fileURL: testFile)

        // Then: 驗證結果
        XCTAssertEqual(logs.count, 3, "應該解析出 3 筆潛水記錄")
        XCTAssertEqual(logs[0].diveNumber, 40)
        XCTAssertEqual(logs[1].diveNumber, 41)
        XCTAssertEqual(logs[2].diveNumber, 42)
    }

    // MARK: - Edge Case Tests

    /// 測試缺失選擇欄位（location）
    func testMissingOptionalLocation() throws {
        // Given: 缺少 location 欄位的潛水記錄
        let testFile = createTemporaryUDDFFile(
            withDives: [
                UDDFTestData(
                    dateTime: "2023-06-15T14:30:00+08:00",
                    diveNumber: "42",
                    location: nil, // 缺失
                    maxDepth: "25.5",
                    duration: "00:45:30",
                    surfaceTemp: "28",
                    bottomTemp: "24"
                )
            ]
        )
        defer { try? FileManager.default.removeItem(at: testFile) }

        // When: 解析檔案
        let logs = try parser.parse(fileURL: testFile)

        // Then: 應使用預設值 "Unknown Location"
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].location, "Unknown Location")
    }

    /// 測試極端深度值
    func testExtremeDeptValue() throws {
        // Given: 深度 100 公尺的潛水記錄（極端但有效）
        let testFile = createTemporaryUDDFFile(
            withDives: [
                UDDFTestData(
                    dateTime: "2023-06-15T14:30:00+08:00",
                    diveNumber: "42",
                    location: "Very Deep Site",
                    maxDepth: "100.5", // 極端深度
                    duration: "00:45:30",
                    surfaceTemp: "28",
                    bottomTemp: "24"
                )
            ]
        )
        defer { try? FileManager.default.removeItem(at: testFile) }

        // When: 解析檔案
        let logs = try parser.parse(fileURL: testFile)

        // Then: 應正確解析極端值
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].maxDepth, 100.5, accuracy: 0.01)
    }

    /// 測試極端潛水時長（8 小時）
    func testExtremeDurationValue() throws {
        // Given: 潛水時長 8 小時的記錄
        let testFile = createTemporaryUDDFFile(
            withDives: [
                UDDFTestData(
                    dateTime: "2023-06-15T06:00:00+08:00",
                    diveNumber: "42",
                    location: "Long Dive",
                    maxDepth: "10.0",
                    duration: "08:00:00", // 8 小時
                    surfaceTemp: "28",
                    bottomTemp: "24"
                )
            ]
        )
        defer { try? FileManager.default.removeItem(at: testFile) }

        // When: 解析檔案
        let logs = try parser.parse(fileURL: testFile)

        // Then: 應正確轉換為秒數
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].diveTime, 8 * 3600, accuracy: 1) // 8 小時 = 28800 秒
    }

    /// 測試缺失水溫
    func testMissingWaterTemperature() throws {
        // Given: 缺少 surfaceTemperature 欄位
        let testFile = createTemporaryUDDFFile(
            withDives: [
                UDDFTestData(
                    dateTime: "2023-06-15T14:30:00+08:00",
                    diveNumber: "42",
                    location: "Kenting",
                    maxDepth: "25.5",
                    duration: "00:45:30",
                    surfaceTemp: nil, // 缺失
                    bottomTemp: "24"
                )
            ]
        )
        defer { try? FileManager.default.removeItem(at: testFile) }

        // When: 解析檔案
        let logs = try parser.parse(fileURL: testFile)

        // Then: 應允許缺失選擇欄位
        XCTAssertEqual(logs.count, 1)
        XCTAssertNil(logs[0].waterTemp)
    }

    // MARK: - Error Handling Tests

    /// 測試檔案不存在
    func testFileNotFound() {
        // Given: 不存在的檔案
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/file.uddf")

        // When & Then: 應拋出 fileNotFound 異常
        XCTAssertThrowsError(try parser.parse(fileURL: nonExistentURL)) { error in
            guard let importError = error as? ImportError else {
                XCTFail("Expected ImportError")
                return
            }
            if case .fileNotFound = importError {
                // 預期結果
            } else {
                XCTFail("Expected fileNotFound error, got \(importError)")
            }
        }
    }

    /// 測試無效的 ZIP 格式
    func testInvalidZipFormat() throws {
        // Given: 無效的 ZIP 檔案（只是普通文本）
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("invalid.uddf")

        try "This is not a ZIP file".write(toFile: tempFile.path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        // When & Then: 應拋出 invalidFormat 異常
        XCTAssertThrowsError(try parser.parse(fileURL: tempFile)) { error in
            guard let importError = error as? ImportError else {
                XCTFail("Expected ImportError")
                return
            }
            if case .invalidFormat = importError {
                // 預期結果
            } else {
                XCTFail("Expected invalidFormat error, got \(importError)")
            }
        }
    }

    /// 測試 ZIP 內沒有 uddf.xml
    func testMissingUddfFileInZip() throws {
        // Given: ZIP 檔案但沒有 uddf.xml
        let testFile = createTemporaryZipFileWithoutUddfXml()
        defer { try? FileManager.default.removeItem(at: testFile) }

        // When & Then: 應拋出 invalidFormat 異常
        XCTAssertThrowsError(try parser.parse(fileURL: testFile)) { error in
            guard let importError = error as? ImportError else {
                XCTFail("Expected ImportError")
                return
            }
            if case .invalidFormat(let reason) = importError {
                XCTAssertTrue(reason.contains("uddf.xml"))
            } else {
                XCTFail("Expected invalidFormat error with 'uddf.xml' message")
            }
        }
    }

    // MARK: - Validation Tests

    /// 測試驗證功能
    func testValidation() throws {
        // Given: 有效的潛水記錄
        let testFile = createTemporaryUDDFFile(
            withDives: [
                UDDFTestData(
                    dateTime: "2023-06-15T14:30:00+08:00",
                    diveNumber: "42",
                    location: "Kenting",
                    maxDepth: "25.5",
                    duration: "00:45:30",
                    surfaceTemp: "28",
                    bottomTemp: "24"
                )
            ]
        )
        defer { try? FileManager.default.removeItem(at: testFile) }

        // When: 解析並驗證
        let logs = try parser.parse(fileURL: testFile)
        let validation = parser.validate(logs: logs)

        // Then: 驗證結果應為有效
        XCTAssertTrue(validation.isValid)
        XCTAssertEqual(validation.errors.count, 0)
        XCTAssertGreaterThanOrEqual(validation.successCount, 1)
    }

    // MARK: - Performance Tests

    /// 測試解析性能
    func testParsingPerformance() throws {
        // Given: 包含 50 筆潛水的 UDDF 檔案
        let largeTestFile = createTemporaryUDDFFile(
            withDives: (0..<50).map { index in
                UDDFTestData(
                    dateTime: "2023-06-\(String(format: "%02d", index % 28 + 1))T14:30:00+08:00",
                    diveNumber: String(index),
                    location: "Dive Site \(index)",
                    maxDepth: String(format: "%.1f", Double.random(in: 10..<50)),
                    duration: "00:45:30",
                    surfaceTemp: String(Int.random(in: 20..<30)),
                    bottomTemp: String(Int.random(in: 15..<28))
                )
            }
        )
        defer { try? FileManager.default.removeItem(at: largeTestFile) }

        // When: 測量解析時間
        self.measure {
            _ = try? parser.parse(fileURL: largeTestFile)
        }

        // Then: 預期時間 < 1 秒（實際應遠快於此）
    }

    // MARK: - Helper Methods

    /// 創建臨時 UDDF 檔案
    private func createTemporaryUDDFFile(withDives dives: [UDDFTestData]) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let uddfZipURL = tempDir.appendingPathComponent("test_\(UUID().uuidString).uddf")
        let uddfXmlURL = tempDir.appendingPathComponent("uddf.xml")

        // 生成 XML 內容
        var xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <uddf version="3.2.0">
          <generator>
            <name>JD2-Logbook Test</name>
          </generator>
          <dives>
        """

        for dive in dives {
            xmlContent += """
            \n    <dive datetime="\(dive.dateTime ?? "2023-06-15T14:30:00+08:00")">
              <divenumber>\(dive.diveNumber ?? "0")</divenumber>
            """

            if let location = dive.location {
                xmlContent += "\n      <location>\(location)</location>"
            }

            xmlContent += """
            \n      <greatestdepth>\(dive.maxDepth ?? "0")</greatestdepth>
              <diveduration>\(dive.duration ?? "00:00:00")</diveduration>
            """

            if let temp = dive.surfaceTemp {
                xmlContent += "\n      <surfacetemperature>\(temp)</surfacetemperature>"
            }

            if let temp = dive.bottomTemp {
                xmlContent += "\n      <bottomtemperature>\(temp)</bottomtemperature>"
            }

            xmlContent += "\n    </dive>"
        }

        xmlContent += """
        \n  </dives>
        </uddf>
        """

        // 寫入臨時 XML 檔案
        try? xmlContent.write(toFile: uddfXmlURL.path, atomically: true, encoding: .utf8)

        // 創建 ZIP 檔案並添加 XML
        if let archive = Archive(url: uddfZipURL, accessMode: .create) {
            try? archive.addFile(uddfXmlURL, relativePath: "uddf.xml")
        }

        try? FileManager.default.removeItem(at: uddfXmlURL)

        return uddfZipURL
    }

    /// 創建不含 uddf.xml 的臨時 ZIP 檔案
    private func createTemporaryZipFileWithoutUddfXml() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let zipURL = tempDir.appendingPathComponent("empty_\(UUID().uuidString).zip")
        let dummyFileURL = tempDir.appendingPathComponent("dummy.txt")

        // 創建臨時檔案
        try? "dummy content".write(toFile: dummyFileURL.path, atomically: true, encoding: .utf8)

        // 創建 ZIP
        if let archive = Archive(url: zipURL, accessMode: .create) {
            try? archive.addFile(dummyFileURL, relativePath: "dummy.txt")
        }

        try? FileManager.default.removeItem(at: dummyFileURL)

        return zipURL
    }
}

// MARK: - Test Data Structure

struct UDDFTestData {
    let dateTime: String?
    let diveNumber: String?
    let location: String?
    let maxDepth: String?
    let duration: String?
    let surfaceTemp: String?
    let bottomTemp: String?

    init(dateTime: String? = nil, diveNumber: String? = nil, location: String? = nil,
         maxDepth: String? = nil, duration: String? = nil, surfaceTemp: String? = nil,
         bottomTemp: String? = nil) {
        self.dateTime = dateTime
        self.diveNumber = diveNumber
        self.location = location
        self.maxDepth = maxDepth
        self.duration = duration
        self.surfaceTemp = surfaceTemp
        self.bottomTemp = bottomTemp
    }
}
