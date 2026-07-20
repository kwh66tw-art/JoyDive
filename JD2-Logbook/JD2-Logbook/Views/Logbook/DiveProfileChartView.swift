// DiveProfileChartView.swift — JD2-Logbook/Views/Logbook/
// 薄包裝：改呼叫家族共用 DiveKitUI.DiveProfileChartView（家族層共用抽取第三批，
// 見 `_JD2-family/decisions/`）。外觀（配色／Y 軸公尺標籤）維持不變。
//
// 資料來源：DiveLog.profileSamples（SubsurfaceXML 解析後填入）

import SwiftUI
import DiveKit
import DiveKitUI

struct DiveProfileChartView: View {
    let samples: [DiveProfileSample]

    private static let style = DiveKitUI.DiveProfileChartStyle(
        fillGradientTop: Color.blue.opacity(0.55),
        fillGradientBottom: Color.blue.opacity(0.08),
        lineColor: Color.blue
    )

    var body: some View {
        DiveKitUI.DiveProfileChartView(
            samples: samples.map {
                DiveKit.DiveProfileSample(timeSeconds: $0.timeSeconds, depthMeters: $0.depthMeters, waterTemp: $0.waterTemp)
            },
            style: Self.style
        )
    }
}

#Preview {
    let samples: [DiveProfileSample] = [
        .init(timeSeconds:    0, depthMeters:  0.0),
        .init(timeSeconds:   60, depthMeters:  5.0),
        .init(timeSeconds:  120, depthMeters: 12.0),
        .init(timeSeconds:  300, depthMeters: 20.0),
        .init(timeSeconds:  900, depthMeters: 18.0),
        .init(timeSeconds: 2400, depthMeters:  5.0),
        .init(timeSeconds: 2700, depthMeters:  3.0),
        .init(timeSeconds: 3020, depthMeters:  0.0),
    ]
    DiveProfileChartView(samples: samples)
        .padding()
}
