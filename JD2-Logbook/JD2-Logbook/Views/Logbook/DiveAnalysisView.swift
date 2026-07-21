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
import DiveKit

struct DiveAnalysisView: View {
    let samples: [DiveProfileSample]
    let gasMix: GasMix

    @State private var replay = DiveReplayEngine.ReplayResult()
    @State private var selectedIndex: Int?

    private var selectedPoint: DiveReplayEngine.ReplayPoint? {
        guard let idx = selectedIndex, replay.points.indices.contains(idx) else { return nil }
        return replay.points[idx]
    }

    /// v1.2 #3：目前選取的樣本點附近命中的警示事件（可能 0～2 筆：上升過速／強制安全停留）
    private var selectedWarnings: [DiveReplayEngine.ReplayWarning] {
        guard let idx = selectedIndex else { return [] }
        return replay.warnings.filter { $0.sampleIndex == idx }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            interactiveChart

            if replay.decoDataUnavailable {
                // F5：trimix 潛水——DiveKit 尚未支援氦氣組織負荷計算，只給深度/時間/溫度。
                Text("Decompression analysis is not yet available for trimix dives.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let point = selectedPoint {
                calloutRow(point)
                // v1.2 #3：狀態資訊列下第二列——選取點命中警示事件時才出現
                if !selectedWarnings.isEmpty {
                    warningEventsSection(selectedWarnings)
                }
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
                    // ⚠️ 修復時間軸偏移 bug：proxy.position(forX:)／proxy.value(atX:)
                    // 都是相對「繪圖區域」（plot area）的座標，不含左側 Y 軸刻度標籤
                    // （"0m"/"10m"/... 的文字寬度）。原本直接拿 GeometryReader 的座標
                    // 用，等於少扣掉這段刻度標籤寬度，選取線/命中判定整體往左偏移了
                    // 一個刻度標籤寬度，深度夠大（三位數字寬度變寬）時偏移更明顯——
                    // 對照 JD2-Ultra companion 的同款程式碼，是同一個從未被抓到的 bug，
                    // 已記錄到 SYNC_TO_JD2-ULTRA.md。這裡統一用 plotFrame.minX 校正。
                    let plotFrame = geo[proxy.plotAreaFrame]

                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    select(atX: value.location.x, proxy: proxy, plotFrame: plotFrame)
                                }
                            // 放開後保留選取（不自動收回），讓使用者能停下來仔細看
                            // callout／組織艙圖；下次點選其他時間點時才會更新。
                        )
                    // v1.2 #3：曲線警示標示（紅點＝上升過速、橘點＝強制安全停留），
                    // 同樣要用 plotFrame 校正，否則會踩到跟選取線一樣的偏移 bug。
                    ForEach(Array(replay.warnings.enumerated()), id: \.offset) { _, warning in
                        if let wx = proxy.position(forX: warning.timeSeconds / 60.0),
                           let wy = proxy.position(forY: -warning.depthMeters) {
                            Circle()
                                .fill(warningColor(warning.kind))
                                .frame(width: 11, height: 11)
                                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                .position(x: plotFrame.minX + wx, y: plotFrame.minY + wy)
                        }
                    }

                    // 選取豎線
                    if let point = selectedPoint,
                       let x = proxy.position(forX: point.timeSeconds / 60.0) {
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.6))
                            .frame(width: 1.5, height: plotFrame.height)
                            .position(x: plotFrame.minX + x, y: plotFrame.midY)
                    }
                }
            }
    }

    private func select(atX x: CGFloat, proxy: ChartProxy, plotFrame: CGRect) {
        guard !samples.isEmpty,
              let minutes: Double = proxy.value(atX: x - plotFrame.minX) else { return }
        let t = minutes * 60
        let nearest = samples.enumerated().min {
            abs($0.element.timeSeconds - t) < abs($1.element.timeSeconds - t)
        }
        selectedIndex = nearest?.offset
    }

    // MARK: - 選取點資訊列
    // port 自 JD2-Ultra companion DiveAnalysisView.calloutRow：Time/Depth/Temp/
    // Ceiling/No Deco 五欄等寬排版，label 在上、數值在下；只有真的需要警示時
    // （減壓中 / NDL 逼近）數值才用填色膠囊強調，其餘為一般深色文字。

    private func calloutRow(_ point: DiveReplayEngine.ReplayPoint) -> some View {
        HStack(spacing: 0) {
            calloutCell(label: Text("Time"), value: timeLabel(point.timeSeconds))
            calloutCell(label: Text("Depth"), value: String(format: "%.1f m", point.depthMeters))
            if let temp = point.waterTemp {
                calloutCell(label: Text("Temp"), value: String(format: "%.0f°C", temp))
            }
            calloutCell(
                label: Text("Ceiling"),
                value: point.ceilingDepth > 0 ? String(format: "%.0f m", point.ceilingDepth) : "—",
                accent: point.ceilingDepth > 0 ? .deco : .neutral
            )
            calloutCell(
                label: Text("No Deco"),
                value: ndlText(point.ndlSeconds),
                accent: point.ndlSeconds < 10 * 60 ? .warning : .neutral
            )
        }
    }

    /// 數值強調樣式：一般狀態＝純深字、無膠囊；只有真的要警示時膠囊才亮起。
    private enum CalloutAccent {
        case neutral, warning, deco
        var pillFill: Color? {
            switch self {
            case .neutral: return nil
            case .warning: return .yellow
            case .deco:    return .red
            }
        }
        var textColor: Color {
            switch self {
            case .neutral: return .primary
            case .warning: return .black
            case .deco:    return .white
            }
        }
    }

    private func calloutCell(label: Text, value: String, accent: CalloutAccent = .neutral) -> some View {
        VStack(spacing: 3) {
            label
                .font(.caption2)
                .foregroundStyle(Color.accessibleSecondary)
            Text(verbatim: value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(accent.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background {
                    if let fill = accent.pillFill { Capsule().fill(fill) }
                }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 警示事件列（v1.2 #3：狀態資訊列下第二列）
    // 門檻與觸發邏輯見 DiveReplayEngine.replay()；文案固定顯示公制＋英制雙單位
    // （不看 Settings 的單位切換，避免這裡先行侷限單位系統展開範圍——見 V1_2_BACKLOG.md #4）。

    private func warningEventsSection(_ warnings: [DiveReplayEngine.ReplayWarning]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(warnings.enumerated()), id: \.offset) { index, warning in
                warningRow(warning)
                if index < warnings.count - 1 {
                    Divider().padding(.leading, 42)
                }
            }
        }
        .background(Color.platformSecondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func warningRow(_ warning: DiveReplayEngine.ReplayWarning) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: warningIcon(warning.kind))
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(warningColor(warning.kind)))

            VStack(alignment: .leading, spacing: 2) {
                Text(warningTitle(warning.kind))
                    .font(.subheadline.weight(.semibold))
                Text(warningDetail(warning.kind))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%.0f m", warning.depthMeters))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text(timeLabel(warning.timeSeconds))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
    }

    private func warningIcon(_ kind: DiveReplayEngine.ReplayWarningKind) -> String {
        switch kind {
        case .ascentRateExceeded:  return "arrow.up"
        case .mandatorySafetyStop: return "hourglass"
        }
    }

    private func warningColor(_ kind: DiveReplayEngine.ReplayWarningKind) -> Color {
        switch kind {
        case .ascentRateExceeded:  return .red
        case .mandatorySafetyStop: return .orange
        }
    }

    private func warningTitle(_ kind: DiveReplayEngine.ReplayWarningKind) -> String {
        switch kind {
        case .ascentRateExceeded:  return String(localized: "Ascent Rate Alert")
        case .mandatorySafetyStop: return String(localized: "Mandatory Safety Stop")
        }
    }

    private func warningDetail(_ kind: DiveReplayEngine.ReplayWarningKind) -> String {
        switch kind {
        case .ascentRateExceeded:
            return String(localized: "Ascent rate exceeded 10 m/min (32.8 ft/min).")
        case .mandatorySafetyStop:
            return String(localized: "Safety stop became mandatory: ascent rate stayed above 10 m/min (32.8 ft/min) for 10 seconds.")
        }
    }

    private func timeLabel(_ seconds: Double) -> String {
        "\(Int(seconds) / 60)'\(String(format: "%02d", Int(seconds) % 60))\""
    }

    /// 與 Ultra companion PlanModel.ndlText 相同的顯示規則（99+ / 分鐘）
    private func ndlText(_ seconds: Int) -> String {
        seconds >= Buhlmann.ndlUnlimitedMarker ? "99+" : "\(seconds / 60)'"
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
