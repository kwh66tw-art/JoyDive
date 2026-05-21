// MapPlaceholderView.swift — JD2-Logbook/Views/Map/
// Week 9 — 地圖 Tab 佔位視圖（Week 10 實作 MapKit + 潛點聚類）

import SwiftUI

struct MapPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                label: {
                    Label("Map view coming soon", systemImage: "map")
                },
                description: {
                    Text("Dive site map will be available in a future update.")
                }
            )
            .navigationTitle("Map")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }
}

#Preview {
    MapPlaceholderView()
}
