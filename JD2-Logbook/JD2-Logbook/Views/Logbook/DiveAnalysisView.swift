// DiveAnalysisView.swift — JD2-Logbook/Views/Logbook/
// v1.1 #4/#5 — 互動剖面圖＋組織艙飽和度視覺化（合併為單一互動單元）
//
//   - 拖曳剖面任一點 → 顯示當下深度/水溫/ceiling/NDL
//   - 16 隔室張力長條（載荷 % 相對水面 M-value，gfHigh 收緊）
//   - 組織艙圖預設不顯示（省視覺空間，使用者不一定每次都要看），
//     使用者點選/拖曳剖面後才出現，且放開後保留最後選取的點——
//     不會「一放開就收回」，讓使用者能停下來仔細看資料。
//
// 架構重點：剖面圖本身（DiveProfileChartView）不持有選取狀態，選取的
// selectedIndex 由本 view 統一管理，同時驅動 callout 列與組織艙長條，
// 兩者才能隨拖曳同步反應（先前 bug：選取狀態關在 DiveProfileChartView
// 內部，同層的組織艙 section 讀不到，畫面完全不動）。
//
// 資料來源＝DiveReplayEngine（DiveKit 重放）。事後估算，非即時裝置讀數，
// 免責聲明見呼叫端 DiveLogDetailView 的 Section footer。

import SwiftUI
import Charts

struct DiveAnalysisView: View {
    let samples: [DiveProfileSample]
    let gasMix: GasMix

    @State private var replay = DiveReplayEngine.ReplayResult()
    @State private var selectedIndex: Int?

    private var selectedPoint: DiveReplayEngine.ReplayPoint? {
        guard let idx = selectedIndex, replay.points.indices.contains(idx) else { return nil }
        return replay.points[idx]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            interactiveChart

            if let point = selectedPoint {
                calloutRow(point)
                TissueBarsView(loadPercents: DiveReplayEngine.tissueLoadPercent(pN2: point.tissuePressures))
            } else {
                Text("Touch and drag the profile to inspect any moment of the dive.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: selectedIndex)
        .task {
            // 重放（樣本 ≤300、步長 10s——主執行緒毫秒級）
            replay = DiveReplayEngine.replay(samples: samples, gasMix: gasMix)
        }
    }

    // MARK: - 互動剖面圖
    // port 自 JD2-Ultra companion DiveAnalysisView.interactiveChart：選取豎線
    // 用 chartOverlay 疊加一條 Rectangle（以 proxy.position(forX:) 定位），
    // 不畫進 Chart 本體的 marks 裡——DiveProfileChartView 維持與 Ultra 一致的
    // 純呈現圖表，兩者職責分離。

    private var interactiveChart: some View {
        DiveProfileChartView(samples: samples)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    select(atX: value.location.x, proxy: proxy)
                                }
                            // 放開後保留選取（不自動收回），讓使用者能停下來仔細看
                            // callout／組織艙圖；下次點選其他時間點時才會更新。
                        )
                    // 選取豎線
                    if let point = selectedPoint,
                       let x = proxy.position(forX: point.timeSeconds / 60.0) {
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.6))
                            .frame(width: 1.5)
                            .offset(x: x)
                    }
                }
            }
    }

    private func select(atX x: CGFloat, proxy: ChartProxy) {
        guard !samples.isEmpty, let minutes: Double = proxy.value(atX: x) else { return }
        let t = minutes * 60
        let nearest = samples.enumerated().min {
            abs($0.element.timeSeconds - t) < abs($1.element.timeSeconds - t)
        }
        selectedIndex = nearest?.offset
    }

    // MARK: - 選取點資訊列

    private func calloutRow(_ point: DiveReplayEngine.ReplayPoint) -> some View {
        HStack(spacing: 14) {
            calloutItem(icon: "arrow.down.to.line", text: String(format: "%.1f m", point.depthMeters))
            if let temp = point.waterTemp {
                calloutItem(icon: "thermometer.medium", text: String(format: "%.0f°C", temp))
            }
            if point.ceilingDepth > 0 {
                calloutItem(icon: "arrow.up.to.line", text: String(format: "%@ %.0f m", String(localized: "Ceiling"), point.ceilingDepth))
                    .foregroundStyle(.red)
            } else if point.ndlSeconds < Buhlmann.ndlUnlimitedMarker {
                calloutItem(icon: "timer", text: "NDL \(point.ndlSeconds / 60) min")
            }
            Spacer()
            Text(timeLabel(point.timeSeconds))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func calloutItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(text).font(.caption.monospacedDigit())
        }
    }

    private func timeLabel(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - 16 隔室張力長條

struct TissueBarsView: View {
    /// 各隔室載荷 %（相對水面 M-value，gfHigh 收緊；>100 = 超出）
    let loadPercents: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tissue Loading")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(loadPercents.enumerated()), id: \.offset) { _, percent in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(barColor(percent))
                        .frame(height: barHeight(percent))
                        .frame(maxWidth: .infinity, alignment: .bottom)
                }
            }
            .frame(height: 64, alignment: .bottom)

            // 快慢隔室方向標（1=最快 4min ↔ 16=最慢 635min）
            HStack {
                Text("Fast")
                    .font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text("Slow")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Tissue Loading"))
    }

    private func barHeight(_ percent: Double) -> CGFloat {
        // 120% 滿格（留 >100% 的視覺空間）
        max(2, CGFloat(min(percent, 120) / 120) * 64)
    }

    private func barColor(_ percent: Double) -> Color {
        if percent > 100 { return .red }      // 超出水面允許值（gfHigh M-value）
        if percent > 80  { return .orange }    // 逼近上限
        return .green
    }
}

#Preview {
    let samples: [DiveProfileSample] = [
        .init(timeSeconds: 0, depthMeters: 0, waterTemp: 27),
        .init(timeSeconds: 300, depthMeters: 30, waterTemp: 25),
        .init(timeSeconds: 1800, depthMeters: 28, waterTemp: 25),
        .init(timeSeconds: 2400, depthMeters: 5, waterTemp: 27),
        .init(timeSeconds: 2700, depthMeters: 0, waterTemp: 28),
    ]
    DiveAnalysisView(samples: samples, gasMix: .air)
        .padding()
}
