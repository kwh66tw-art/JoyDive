// DiveProfileChartView.swift — JD2-Logbook/Views/Logbook/
// Week 13 — 潛水深度剖面圖（Swift Charts）
//
// 資料來源：DiveLog.profileSamples（SubsurfaceXML 解析後填入）
// Y 軸反轉：數值越大 = 越深 = 畫面越低（使用負值 + 自訂 label）
// 只在有樣本時渲染，空資料由 DiveLogDetailView 過濾

import SwiftUI
import Charts

struct DiveProfileChartView: View {
    let samples: [DiveProfileSample]

    // 最大深度（用於 Y 軸 domain）
    private var maxDepth: Double {
        samples.map(\.depthMeters).max() ?? 1.0
    }

    // 最長時間（分鐘，用於 X 軸 domain）
    private var maxMinutes: Double {
        (samples.map(\.timeSeconds).max() ?? 60.0) / 60.0
    }

    var body: some View {
        Chart {
            ForEach(Array(samples.enumerated()), id: \.offset) { _, s in
                let minutes = s.timeSeconds / 60.0
                let depth   = -s.depthMeters   // 負值 → 深度往下

                // 填色區域
                AreaMark(
                    x: .value("Time", minutes),
                    yStart: .value("Surface", 0.0),
                    yEnd:   .value("Depth",   depth)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [
                            Color.blue.opacity(0.55),
                            Color.blue.opacity(0.08)
                        ],
                        startPoint: .bottom,
                        endPoint:   .top
                    )
                )
                .interpolationMethod(.catmullRom)

                // 輪廓線
                LineMark(
                    x: .value("Time", minutes),
                    y: .value("Depth", depth)
                )
                .foregroundStyle(Color.blue)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.catmullRom)
            }
        }
        // Y 軸：0 在頂，maxDepth*1.1 在底（全為負值）
        .chartYScale(domain: -(maxDepth * 1.15) ... 0)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                    .foregroundStyle(Color.secondary.opacity(0.25))
                AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(-v))m")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
        }
        // X 軸：分鐘
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                    .foregroundStyle(Color.secondary.opacity(0.25))
                AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))min")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
        }
        .chartXScale(domain: 0 ... maxMinutes)
        .frame(height: 160)
        .padding(.vertical, 4)
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
