// DiveProfileChartView.swift — JD2-Logbook/Views/Logbook/
// 薄包裝：改呼叫家族共用 DiveKitUI.DiveProfileChartView（家族層共用抽取第三批，
// 見 `_JD2-family/decisions/`）。外觀（配色）維持不變。
//
// ⚠️ Y 軸深度單位：DiveKitUI.DiveProfileChartView 本身已支援注入 `depthAxisLabel`
// 換算格式（見該檔案 doc comment：「呼叫端可傳入自己的單位換算格式」），這裡原本
// 沒有傳，落回套件預設值（固定 "\(Int(depth))m"），導致 Settings 切成英制後 Y 軸
// 刻度仍固定顯示公尺——純 App 層漏接，非 Kit 本身的限制，故直接在這裡補上，不需要
// 回報家族層。
//
// 資料來源：DiveLog.profileSamples（SubsurfaceXML 解析後填入）

import SwiftUI
import DiveKit
import DiveKitUI

struct DiveProfileChartView: View {
    let samples: [DiveProfileSample]

    @AppStorage(UnitSystem.storageKey) private var unitSystem = UnitSystem.metric

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
            style: Self.style,
            depthAxisLabel: { depthMeters in
                let displayValue = unitSystem.convertDepth(metersValue: depthMeters)
                return "\(Int(displayValue.rounded()))\(unitSystem.depthSymbol)"
            }
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
