//
//  JD2_LogbookUITestsLaunchTests.swift
//  JD2-LogbookUITests
//
//  Created by Kevin on 2026/5/17.
//

import XCTest

final class JD2_LogbookUITestsLaunchTests: XCTestCase {

    // 2026-08-30 PM 裁示：功能測試只驗證功能，不需要對全部語系跑（截圖存證
    // 需求另計）。移除 runsForEachTargetApplicationUIConfiguration=true，
    // 改回預設（只跑一次，base 語系）——原設定讓這支不含任何斷言的樣板
    // 測試對 18 個語系重複啟動，膨脹成 800+ 次執行，是 UITests suite
    // 70 分鐘跑不完的主因。

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
