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
    }
}
