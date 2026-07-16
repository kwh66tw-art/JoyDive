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

    @State private var languageManager = AppLanguageManager()

    init() {
        #if canImport(GoogleMobileAds)
        MobileAds.shared.start { _ in }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(languageManager)
                .environment(\.locale, languageManager.locale)
        }
        .modelContainer(DiveLogDatabase.shared.modelContainer)
        #if os(macOS)
        // 視窗最小尺寸 = 內容最小尺寸，讓各 pane 宣告的 minWidth/minHeight
        // 真正生效（否則視窗會無視 min 直接縮小並裁切內容）
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1280, height: 800)
        #endif
    }
}
