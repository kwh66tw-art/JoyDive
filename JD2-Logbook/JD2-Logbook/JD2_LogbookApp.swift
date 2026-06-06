//
//  JD2_LogbookApp.swift
//  JD2-Logbook
//
//  Created by Kevin on 2026/5/17.
//

import SwiftUI
import SwiftData
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct JD2_LogbookApp: App {

    init() {
        #if canImport(GoogleMobileAds)
        // ── 測試裝置 ID（開發用，上架前移除或清空此陣列）──────────────
        // 步驟：
        //   1. 用 Xcode 跑在真機上
        //   2. console 找這行 log（app 啟動幾秒後出現）：
        //      <Google> To get test ads on this device, set:
        //      GADMobileAds.sharedInstance.requestConfiguration.testDeviceIdentifiers = @[ "XXXXXXXX" ]
        //   3. 把那串大寫 hex 字串貼到下面 testDeviceIdentifiers 陣列裡
        //   4. 重跑 app，廣告版位會顯示測試廣告（橘色「Test Ad」框）
        // ──────────────────────────────────────────────────────────────
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
            "a10efcaff62afcacbd5dc5c884fb7f6d" // ⚠️ 上架前移除
        ]
        MobileAds.shared.start { _ in }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(DiveLogDatabase.shared.modelContainer)
        #if os(macOS)
        // 視窗最小尺寸 = 內容最小尺寸，讓各 pane 宣告的 minWidth/minHeight
        // 真正生效（否則視窗會無視 min 直接縮小並裁切內容）
        .windowResizability(.contentMinSize)
        #endif
    }
}
