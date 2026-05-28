//
//  JD2_LogbookApp.swift
//  JD2-Logbook
//
//  Created by Kevin on 2026/5/17.
//

import SwiftUI
import SwiftData

@main
struct JD2_LogbookApp: App {
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
