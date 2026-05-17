// DiveLogTests.swift — JD2Core/Models/DiveLogTests.swift
// 簡單的單元測試，驗證 DiveLog 模型基本功能

import Foundation

/// DiveLog 單元測試（不依賴 XCTest）
struct DiveLogTests {

    /// 執行所有測試
    static func runAllTests() {
        print("🧪 開始 DiveLog 單元測試...")
        testBasicInitialization()
        testCalculatedProperties()
        testUpdate()
        testEnvironmentSettings()
        print("✅ 所有測試通過！")
    }

    // MARK: - Test 1: 基本初始化

    static func testBasicInitialization() {
        print("\n[Test 1] 基本初始化...")

        let now = Date()
        let dive = DiveLog(
            dateTime: now,
            location: "Green Island",
            maxDepth: 25.5,
            diveTimeSeconds: 1800,
            gasMixJSON: "\"air\"",
            waterTemperature: 18.0
        )

        assert(dive.location == "Green Island", "地點應為 'Green Island'")
        assert(dive.maxDepth == 25.5, "最大深度應為 25.5m")
        assert(dive.diveTimeSeconds == 1800, "潛水時間應為 1800 秒")
        assert(dive.waterTemperature == 18.0, "水溫應為 18.0°C")
        assert(dive.sourceFormat == "manual", "預設來源應為 'manual'")

        print("  ✓ 初始化成功")
        print("  ✓ 所有屬性值正確")
    }

    // MARK: - Test 2: 計算屬性

    static func testCalculatedProperties() {
        print("\n[Test 2] 計算屬性...")

        let dive = DiveLog(
            dateTime: Date(),
            location: "Test Site",
            maxDepth: 30.0,
            diveTimeSeconds: 3661,  // 1 小時 1 分 1 秒
            waterTemperature: 20.0
        )

        // 分鐘轉換
        assert(dive.diveTimeMinutes == 61, "應計算為 61 分鐘")

        // 時間格式化
        let formattedTime = dive.diveTimeFormatted
        assert(formattedTime == "01:01:01", "格式應為 '01:01:01'，實際: \(formattedTime)")

        // 日期格式化
        let dateFormatted = dive.dateFormatted
        assert(dateFormatted.count == 10, "日期格式應為 YYYY-MM-DD")

        print("  ✓ diveTimeMinutes 計算正確")
        print("  ✓ diveTimeFormatted 格式正確")
        print("  ✓ dateFormatted 格式正確")
    }

    // MARK: - Test 3: 更新方法

    static func testUpdate() {
        print("\n[Test 3] 更新方法...")

        let dive = DiveLog(
            dateTime: Date(),
            location: "Old Site",
            maxDepth: 20.0,
            diveTimeSeconds: 1800,
            waterTemperature: 15.0,
            notes: ""
        )

        let oldUpdatedAt = dive.updatedAt

        // 等待一刻，確保 updatedAt 會變化
        usleep(10000)

        // 執行更新
        dive.update(
            location: "New Site",
            maxDepth: 25.0,
            waterTemperature: 18.0,
            notes: "Updated dive"
        )

        assert(dive.location == "New Site", "地點應更新為 'New Site'")
        assert(dive.maxDepth == 25.0, "深度應更新為 25.0")
        assert(dive.waterTemperature == 18.0, "水溫應更新為 18.0")
        assert(dive.notes == "Updated dive", "備註應更新")
        assert(dive.updatedAt > oldUpdatedAt, "updatedAt 應更新")

        print("  ✓ location 更新成功")
        print("  ✓ maxDepth 更新成功")
        print("  ✓ waterTemperature 更新成功")
        print("  ✓ updatedAt 時戳更新成功")
    }

    // MARK: - Test 4: 環境設定

    static func testEnvironmentSettings() {
        print("\n[Test 4] 環境設定...")

        let dive = DiveLog(
            dateTime: Date(),
            location: "Altitude Lake",
            maxDepth: 15.0,
            diveTimeSeconds: 1200,
            waterTemperature: 10.0
        )

        // 設定高海拔淡水環境
        dive.setEnvironment(
            type: "altitude",
            surfacePressure: 0.9,
            metersPerBar: 10.2
        )

        assert(dive.environmentType == "altitude", "環境應設為 'altitude'")
        assert(dive.surfacePressureBar == 0.9, "海拔氣壓應為 0.9 bar")
        assert(dive.metersPerBar == 10.2, "深度係數應為 10.2 m/bar")

        // 設定座標
        dive.setLocation(latitude: 25.1234, longitude: 121.5678)

        assert(dive.latitude == 25.1234, "緯度應設定")
        assert(dive.longitude == 121.5678, "經度應設定")

        print("  ✓ environmentType 設定成功")
        print("  ✓ surfacePressureBar 設定成功")
        print("  ✓ metersPerBar 設定成功")
        print("  ✓ latitude/longitude 設定成功")
    }
}

// MARK: - 測試入口（可手動呼叫）

extension DiveLog {
    /// 用於調試的測試函式
    static func runTests() {
        DiveLogTests.runAllTests()
    }
}
