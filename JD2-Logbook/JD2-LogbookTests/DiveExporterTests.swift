// DiveExporterTests.swift — JD2-LogbookTests/
// v1.0
//
// 針對 DiveExporter 導出功能 (UDDF 3.2.2 & CSV RFC 4180) 以及 PurchaseManager 的單元測試

import XCTest
import SwiftData
@testable import JD2_Logbook

final class DiveExporterTests: XCTestCase {
    
    // MARK: - DiveExporter Tests
    
    /// 測試 CSV 導出是否嚴格符合 RFC 4180 規範 (逗號、引號、新行的 escape 邏輯，以及 CRLF 換行)
    func testCSVExportRFC4180Compliance() throws {
        // 1. 建立具有特殊字元的 Mock 潛水日誌
        let date = Date(timeIntervalSince1970: 1716200000) // 固定日期
        
        let dive1 = DiveLog(
            dateTime: date,
            location: "龍洞, 三號口", // 含逗號
            maxDepth: 18.5,
            diveTimeSeconds: 2700, // 45 分鐘
            gasMixJSON: "\"air\"",
            waterTemperature: 24.5
        )
        dive1.buddy = "Alex \"The Diver\" Chen" // 含雙引號
        dive1.notes = "Saw a huge turtle!\nVis was great." // 含換行
        
        let dive2 = DiveLog(
            dateTime: date.addingTimeInterval(3600),
            location: "Kenting",
            maxDepth: 22.0,
            diveTimeSeconds: 2400,
            gasMixJSON: "{\"nitrox\":{\"fO2\":0.32}}", // Nitrox 32
            waterTemperature: 27.0
        )
        dive2.setLocation(latitude: 21.9392, longitude: 120.7441)
        
        let dives = [dive1, dive2]
        
        // 2. 執行 CSV 導出
        let csvData = DiveExporter.export(dives, as: .csv)
        guard let csvString = String(data: csvData, encoding: .utf8) else {
            XCTFail("無法將 CSV 資料轉換為 UTF8 字串")
            return
        }
        
        // 3. 驗證 CSV 內容
        // 驗證是否使用 CRLF (\r\n) 換行
        XCTAssertTrue(csvString.contains("\r\n"))
        
        let lines = csvString.components(separatedBy: "\r\n")
        XCTAssertGreaterThanOrEqual(lines.count, 3) // Header + 2 rows
        
        // 驗證首行 (Header) 是否正確
        XCTAssertTrue(lines[0].contains("Date,Time,Location,Max Depth (m)"))
        
        // 驗證第一筆資料 (包含特殊字元的欄位)
        let row1 = lines[1]
        // 檢查含逗號的地點是否被雙引號包裹
        XCTAssertTrue(row1.contains("\"龍洞, 三號口\""))
        // 檢查含雙引號的潛伴是否被雙引號包裹且內部雙引號加倍
        XCTAssertTrue(row1.contains("\"Alex \"\"The Diver\"\" Chen\""))
        // 檢查含換行的 notes 是否被雙引號包裹並且換行存在 (因為換行在 row 中，所以 lines 分割會受到影響，我們可以直接在整段字串檢查)
        XCTAssertTrue(csvString.contains("\"Saw a huge turtle!\nVis was great.\""))
        
        // 驗證第二筆資料 (Nitrox 氣體)
        let row2 = csvString.components(separatedBy: "\r\n").last(where: { $0.contains("Kenting") }) ?? ""
        XCTAssertTrue(row2.contains("EANx32"))
        XCTAssertTrue(row2.contains("21.939200"))
        XCTAssertTrue(row2.contains("120.744100"))
    }
    
    /// 測試 UDDF 導出是否符合 3.2.2 規範 (溫度 Kelvin 轉換、GPS 省略避免 Null Island 偏誤)
    func testUDDFExportKelvinAndGPSOmitting() throws {
        // 1. 建立兩筆潛水記錄，一筆無 GPS，一筆有 GPS
        let date = Date(timeIntervalSince1970: 1716200000)
        
        // 無 GPS 潛水日誌，水溫 25°C
        let diveWithoutGPS = DiveLog(
            dateTime: date,
            location: "Secret Dive Site",
            maxDepth: 15.0,
            diveTimeSeconds: 3000,
            waterTemperature: 25.0
        )
        // 緯度經度皆為 nil
        XCTAssertNil(diveWithoutGPS.latitude)
        XCTAssertNil(diveWithoutGPS.longitude)
        
        // 有 GPS 潛水日誌，水溫 18.5°C
        let diveWithGPS = DiveLog(
            dateTime: date.addingTimeInterval(7200),
            location: "Castle Rock",
            maxDepth: 32.5,
            diveTimeSeconds: 2100,
            waterTemperature: 18.5
        )
        diveWithGPS.setLocation(latitude: -8.4419, longitude: 119.5719)
        
        let dives = [diveWithoutGPS, diveWithGPS]
        
        // 2. 執行 UDDF 導出
        let uddfData = DiveExporter.export(dives, as: .uddf)
        guard let xmlString = String(data: uddfData, encoding: .utf8) else {
            XCTFail("無法將 UDDF 資料轉換為 UTF8 字串")
            return
        }
        
        // 3. 驗證 XML 內容
        // 驗證版本資訊
        XCTAssertTrue(xmlString.contains("version=\"3.2.2\""))
        XCTAssertTrue(xmlString.contains("<uddf"))
        
        // 驗證第一筆無 GPS 潛水：必須不含有 <geography> 標籤
        // 我們定位到第一個 <dive id="dive1"> 區塊
        guard let rangeOfDive1 = xmlString.range(of: "<dive id=\"dive1\">"),
              let rangeOfDive2 = xmlString.range(of: "<dive id=\"dive2\">") else {
            XCTFail("找不到潛水日誌區塊")
            return
        }
        
        let dive1Block = String(xmlString[rangeOfDive1.upperBound..<rangeOfDive2.lowerBound])
        XCTAssertFalse(dive1Block.contains("<geography>"))
        XCTAssertFalse(dive1Block.contains("<latitude>"))
        
        // 驗證第一筆溫度轉換：25.0°C 必須轉換成 298.15 K
        XCTAssertTrue(dive1Block.contains("<temperaturemin>298.15</temperaturemin>"))
        
        // 驗證第二筆有 GPS 潛水：必須含有正確的 <geography> 標籤與 GPS 數值
        let dive2Block = String(xmlString[rangeOfDive2.upperBound...])
        XCTAssertTrue(dive2Block.contains("<geography>"))
        XCTAssertTrue(dive2Block.contains("<latitude>-8.4419</latitude>"))
        XCTAssertTrue(dive2Block.contains("<longitude>119.5719</longitude>"))
        
        // 驗證第二筆溫度轉換：18.5°C 必須轉換成 291.65 K
        XCTAssertTrue(dive2Block.contains("<temperaturemin>291.65</temperaturemin>"))
    }
    
    // MARK: - PurchaseManager Tests
    
    /// 測試 PurchaseManager 初始狀態與基本屬性
    @MainActor
    func testPurchaseManagerInitialState() throws {
        let pm = PurchaseManager.shared
        
        // 驗證預設價格字串
        XCTAssertEqual(pm.premiumPriceString, "$1.99")
        
        // 驗證產品 ID 常數
        XCTAssertEqual(PurchaseManager.premiumProductID, "com.jd2logbook.premium")
    }
}
