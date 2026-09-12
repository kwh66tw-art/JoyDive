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
// 資料來源＝DiveKit `DiveReplayEngine`（2026-08-22 起改用家族共用重放引擎，
// Logbook 原本那份 `JD2Core/Algorithm/DiveReplayEngine.swift` 已刪除——原為稽核
// 模式2 的獨立複製，見 `_JD2-family/decisions/2026-08-22_重放連續潛水殘氮與前置
// 判斷-設計.md`）。改用 `replayChain(...)` 後，同一串連續潛水的殘氮會延續進來，
// 不再每支都由水面飽和組織起算。事後估算，非即時裝置讀數，免責聲明見呼叫端
// DiveLogDetailView 的 Section footer。

import SwiftUI
import SwiftData
import Charts
import DiveKit

struct DiveAnalysisView: View {
    // v1.2：PM 決定曲線警示標示／狀態資訊列第二列的呈現方式要等改版再定案，
    // 程式碼保留（DiveReplayEngine 的警示偵測邏輯與 UI 都還在），先關閉、不刪除。
    // 之後要重新開放：把這個常數改回 true 即可，不需要改動其他任何地方。
    private let showWarningEvents = false

    /// 目標潛水本身——鏈式重放需要它的時間戳/時長/maxDepth/環境，光有樣本不夠
    let dive: DiveLog
    let samples: [DiveProfileSample]
    let gasMix: GasMix

    // v1.2 #4：公制／英制單位系統，儲存值永遠是公制，這裡只負責顯示層換算。
    @AppStorage(UnitSystem.storageKey) private var unitSystem = UnitSystem.metric

    // v1.2 #17：warningTitle/warningDetail 原本用 String(localized:)（讀系統
    // Locale，語言切換後不重開 App 會殘留舊語言），改吃 languageManager.localized(_:)。
    // 目前這段被 showWarningEvents=false 藏起來，先修正避免功能重開時繼承舊 bug。
    @Environment(AppLanguageManager.self) private var languageManager

    @Environment(\.modelContext) private var modelContext

    // ⚠️ Optional 而非預設值：DiveKit `ReplayResult` 是 public struct，但成員逐一
    // 初始化器維持 internal，App 層造不出空實例（已回報總指揮，非本 repo 可修）。
    // nil ＝尚未算完或被前置判斷攔下。
    @State private var replay: DiveReplayEngine.ReplayResult?
    /// 前置判斷 P1–P6 攔下來的原因（nil = 通過，正常顯示組織艙/ceiling/NDL）
    @State private var anomaly: DiveReplayEngine.Anomaly?
    /// 選取的**原始剖面樣本**索引（不是重放點索引——見 `selectedPoint` 的說明）。
    @State private var selectedIndex: Int?
    /// ⓘ 限制說明頁（2026-09-12 裁示 4.5：8 種異常 ＋ 2 項一般性限制全部羅列）
    @State private var showingLimitations = false

    /// 依時間排序後的樣本——**選取索引一律以這個陣列為準**。
    ///
    /// 🔴 為什麼要排序：DiveKit 的 `ReplayPoint.sampleIndex` 是它**自己排序後**的
    /// 列舉索引（`DiveReplay.drive()`：`samples.sorted { ... }.enumerated()`），
    /// 而本 view 原本用未排序的 `samples` 算選取索引、卻拿去索引 `replay.points`
    /// ——兩邊順序不一致時就會顯示到別的時間點的 Ceiling／NDL，而且**畫面上看起來
    /// 完全正常**。排序一次讓兩邊同基準；`init` 只算一次，不在每次 render 重排。
    private let orderedSamples: [DiveProfileSample]

    init(dive: DiveLog, samples: [DiveProfileSample], gasMix: GasMix) {
        self.dive = dive
        self.samples = samples
        self.gasMix = gasMix
        self.orderedSamples = samples.sorted { $0.timeSeconds < $1.timeSeconds }
    }

    private var replayPoints: [DiveReplayEngine.ReplayPoint] { replay?.points ?? [] }
    private var replayWarnings: [DiveReplayEngine.ReplayWarning] { replay?.warnings ?? [] }

    /// 選取點的原始樣本——**異常時仍然有值**（Time／Depth／Temp 不需要重放）。
    private var selectedSample: DiveProfileSample? {
        guard let idx = selectedIndex, orderedSamples.indices.contains(idx) else { return nil }
        return orderedSamples[idx]
    }

    /// 選取點對應的重放結果——可能為 nil（前置判斷拒算，**或**該樣本沒有對應重放點）。
    ///
    /// 🔴 用 `sampleIndex` 比對而非陣列位置：`drive()` 對 `span <= 0` 的樣本
    /// `continue`（同一秒重複樣本）⇒ `points.count` 可能少於樣本數，位置索引會整體
    /// 錯位。`sampleIndex` 是唯一可靠的對應鍵。
    private var selectedPoint: DiveReplayEngine.ReplayPoint? {
        guard let idx = selectedIndex else { return nil }
        return replayPoints.first { $0.sampleIndex == idx }
    }

    /// v1.2 #3：目前選取的樣本點附近命中的警示事件（可能 0～2 筆：上升過速／強制安全停留）
    /// showWarningEvents=false 時強制回傳空陣列，UI 端不需要另外判斷開關。
    private var selectedWarnings: [DiveReplayEngine.ReplayWarning] {
        guard showWarningEvents, let idx = selectedIndex else { return [] }
        return replayWarnings.filter { $0.sampleIndex == idx }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            interactiveChart

            // 🔑 2026-09-12 PM 裁示：callout **不再被異常關掉**。Time／Depth／Temp
            // 來自原始剖面、與重放無關，異常時照常可拖曳；只有 Ceiling／No Deco
            // （唯二的重放產物）顯示「—」。原本三欄一起關掉，使
            // 「inspect any moment of the dive」在這些潛水上變成做不到的承諾。
            if let sample = selectedSample {
                // v1.2：狀態列文字不跟著外層 .animation(value: selectedIndex) 做隱式動畫
                // ——原本整個 VStack 共用同一個 easeInOut，狀態列在「插入」瞬間會跟著
                // 淡入/版面過渡一起跑，若剛好在動畫還沒跑完時被截圖，數值文字會停在
                // 過渡中間的狀態，看起來字級／樣式跟穩定後不一致。用 transaction 關掉
                // 這個子樹的動畫，狀態列一律立即以最終樣式出現，不會有中間態。
                calloutRow(sample, point: selectedPoint)
                    .transaction { $0.animation = nil }
                // v1.2 #3：狀態資訊列下第二列——選取點命中警示事件時才出現
                if !selectedWarnings.isEmpty {
                    warningEventsSection(selectedWarnings)
                }
            }

            // 組織艙區塊：算得出來就畫長條，算不出來就**在同一個位置**說明為什麼
            // ——而不是讓這塊空間靜默消失（使用者無從分辨「沒選點」與「不支援」）。
            if let anomaly {
                tissueUnavailableNotice(anomaly)
            } else if let point = selectedPoint {
                TissueBarsView(loadPercents: DiveReplayEngine.tissueLoadPercent(
                    pN2: point.tissuePN2,
                    pHe: point.tissuePHe,
                    environment: dive.replayEnvironment
                ))
            }

            hintRow
            replayLimitationsNotice
        }
        .sheet(isPresented: $showingLimitations) {
            ReplayLimitationsInfoView(activeAnomaly: anomaly)
        }
        .animation(.easeInOut(duration: 0.15), value: selectedIndex)
        .task {
            // 鏈式重放（樣本 ≤300、步長 10s；鏈長實務上 1–3 筆——主執行緒毫秒級）。
            // 候選前導潛水給 96h 內全部，窗口過濾／排序／保守上界截斷由 Kit 自理。
            let outcome = DiveReplayEngine.replayChain(
                target: dive.replayInput,
                precedingDives: DiveReplayChainQuery
                    .precedingDives(of: dive, in: modelContext)
                    .map(\.replayInput)
            )
            switch outcome {
            case .replayed(let result):
                replay = result
                anomaly = nil
            case .anomaly(let reason):
                // 深度剖面照常顯示（chart 不吃重放結果）；**只有**「事後推算」的部分
                // （組織艙／Ceiling／NDL）改成說明訊息。
                //
                // ✅ 2026-09-12 PM 裁示已實作：這裡**不再**清掉 `selectedIndex`。
                // 清掉會讓拖曳完全沒反應，連 Time／Depth／Temp 一起關掉——那三欄
                // 來自原始剖面、與重放無關，關掉等於讓
                // 「inspect any moment of the dive」變成做不到的承諾。
                // 裁示全文（分三類／not available vs not applicable／免責拆兩句）：
                // `../_JD2-family/decisions/2026-09-12_重放異常的文案細分與UI重新設計-PM裁示.md`
                replay = nil
                anomaly = reason
            }
        }
    }

    // MARK: - 前置判斷異常說明（組織艙區塊的替代內容）
    // 設計文件第四節：前置判斷任一成立 → 整個 tissue loading 重放不計算，原本放
    // 組織艙飽和度的區塊改顯示說明訊息，**深度剖面與 Time／Depth／Temp 照常**。
    //
    // 🔑 文案定版 2026-09-12（PM 全案裁示，取代 V1_2_BACKLOG #24 的 2026-08-22 定版
    // ——那版是六種異常共用一段，之後 `Anomaly` 變 8 種、其中一種性質也改了）：
    // `../_JD2-family/decisions/2026-09-12_重放異常的文案細分與UI重新設計-PM裁示.md`
    //
    // 🔴 **"available" 與 "applicable" 只差一個字，但它決定使用者覺得
    // 「app 有問題」還是「這種潛水本來就沒有」**——B／C 都不是故障：模型本來就
    // 不適用於閉氣潛水，也不能跨大氣基準線做殘氮延續。不要在翻譯或改寫時合併這兩句。

    private func tissueUnavailableNotice(_ anomaly: DiveReplayEngine.Anomaly) -> some View {
        Button {
            showingLimitations = true
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: languageManager.localized(AnomalyClass(anomaly).tissueNoticeKey))
                Image(systemName: "info.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("replayAnomalyNotice")
    }

    /// 異常分三類（PM 2026-09-12 裁示 1）。**分類只影響文案語意，不影響是否拒算**。
    private enum AnomalyClass {
        /// A 資料問題（6 種）：這筆紀錄的資料無法支持重放 ⇒ "not available"
        case dataProblem
        /// B 不適用（`breathHoldTarget`）：模型本來就不適用 ⇒ "not applicable"
        case notApplicable
        /// C 環境不同（`inconsistentEnvironment`）：無法跨大氣基準線延續殘氮 ⇒ "not applicable"
        case differentEnvironment

        init(_ anomaly: DiveReplayEngine.Anomaly) {
            switch anomaly {
            case .breathHoldTarget:
                self = .notApplicable
            case .inconsistentEnvironment:
                self = .differentEnvironment
            case .technicalDive, .unknownGasMix, .overlappingDives,
                 .implausibleTiming, .seriesIndexMismatch, .precedingProfileSamplesMissing:
                self = .dataProblem
            }
        }

        var tissueNoticeKey: String {
            switch self {
            case .dataProblem:
                return "Interactive tissue loading is not available for this dive — see detail"
            case .notApplicable, .differentEnvironment:
                return "Interactive tissue loading is not applicable for this dive — see detail"
            }
        }
    }

    // MARK: - 提示列（PM 2026-09-12 裁示 4.2）
    // 「Limited support ⓘ」與既有 App Store 文案一致（標題已是 "Interactive Profile,
    // With Tissue Loading (Limited Support)"），措辭不另外發明。
    // 🔑 ⓘ **恆常可達**：ⓘ 頁除了 8 種異常，還列 2 項**永遠成立**的一般性限制
    // （GF 樂觀偏差、本 App 缺 series index 導致偵測覆蓋較窄）——那兩項在重放
    // 完全正常時同樣適用，所以入口不能只在異常時出現。
    private var hintRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if selectedIndex == nil {
                // 走 localized(_:) 而非 Text 字面量：App 內語言切換後才會即時生效（v1.2 #17）
                Text(verbatim: languageManager.localized("Touch and drag the profile to inspect any moment of the dive."))
                Text(verbatim: "·")
            }
            Button {
                showingLimitations = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(verbatim: languageManager.localized("Limited support"))
                    Image(systemName: "info.circle")
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("replayLimitedSupportButton")
            Spacer(minLength: 0)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 一般性重放限制揭露
    // 設計文件第七節（`_JD2-family/decisions/2026-08-22_重放連續潛水殘氮與前置
    // 判斷-設計.md`）：這兩項是 DiveKit 共用重放引擎／Logbook 資料模型的固有限制，
    // **永遠顯示**在組織艙飽和度／ceiling 區塊附近，不論這次重放有沒有觸發 P1–P6
    // 異常——因為就算重放正常算出結果，這兩項限制依然成立。文案由 PM 於
    // 2026-08-22 定版（V1_2_BACKLOG #24）：
    //   1. GF 樂觀偏差：重放全程以 gfHigh 為基準，不模擬即時裝置 ascent 中的
    //      GF 收緊，ceiling 因此可能比裝置當時實際顯示更淺（更樂觀）。
    //   2. 偵測強度較弱：Logbook 沒有 `diveNumberInSeries` 欄位（ultra／immersion
    //      有），P4 交叉比對會被跳過，不得暗示偵測強度與另外兩者相同。
    // 比異常訊息（anomalyNotice）更不顯眼——那是狀況警示，這是固定揭露。
    //
    // 🔴 **2026-09-12：兩句不得同進退**（PM 裁示 4.4 的同一原則往下一層套用）。
    // 第一句描述「這次重放**怎麼算的**」——沒有重放時它宣稱了沒發生的事，必須消失。
    // 第二句描述「**偵測**覆蓋範圍」——偵測確實跑過（正是它判出異常的），永遠成立。
    // 綁在一起一定有一句是錯的：一起留 ⇒ 第一句說謊；一起消失 ⇒ 在資訊最少的
    // 那些潛水上連正確的那句也不見了。
    private var replayLimitationsNotice: some View {
        VStack(alignment: .leading, spacing: 2) {
            if replay != nil {
                // 從呼叫端 Section footer 搬進來（PM 2026-09-12 裁示 4.4）：這句描述
                // 「這些數字是怎麼算出來的」，沒有重放時它宣稱了沒發生的事。
                // 免責那一句（"Not a substitute for…"）留在 footer 恆常顯示。
                Text(verbatim: languageManager.localized(
                    "Estimated using Bühlmann ZHL-16C from the imported profile only."
                ))
                Text(verbatim: languageManager.localized(
                    "Replay is simulated using the conservative GF High ceiling baseline, so the ceiling shown may be more optimistic (shallower) than what your dive computer displayed at the time."
                ))
            }
            Text(verbatim: languageManager.localized(
                "This app can't read the original device's dive-series index, so replay-anomaly detection here has narrower coverage than in ultra or immersion."
            ))
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("replayLimitationsNotice")
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
                    // plotFrame（iOS 17 起取代已棄用的 plotAreaFrame）是 Anchor<CGRect>?，
                    // 用 if let 而非強制解包，理論上 chartOverlay 觸發時圖表已完成佈局、
                    // 這裡幾乎不會是 nil，但沒必要冒非必要的強制解包崩潰風險。
                    if let plotFrame = proxy.plotFrame.map({ geo[$0] }) {
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
                        // v1.2 #3：曲線警示標示（紅點＝上升過速、橘點＝強制安全停留）——
                        // 暫時關閉（showWarningEvents，見型別開頭註解），同樣要用 plotFrame
                        // 校正，否則會踩到跟選取線一樣的偏移 bug，重新開放時保留這段校正邏輯。
                        if showWarningEvents {
                            ForEach(Array(replayWarnings.enumerated()), id: \.offset) { _, warning in
                                if let wx = proxy.position(forX: warning.timeSeconds / 60.0),
                                   let wy = proxy.position(forY: -warning.depthMeters) {
                                    Circle()
                                        .fill(warningColor(warning.kind))
                                        .frame(width: 11, height: 11)
                                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                        .position(x: plotFrame.minX + wx, y: plotFrame.minY + wy)
                                }
                            }
                        }

                        // 選取豎線——用**原始樣本**的時間，不用重放點：異常時
                        // 沒有重放點，但拖曳照常有效，豎線不能跟著消失。
                        if let sample = selectedSample,
                           let x = proxy.position(forX: sample.timeSeconds / 60.0) {
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.6))
                                .frame(width: 1.5, height: plotFrame.height)
                                .position(x: plotFrame.minX + x, y: plotFrame.midY)
                        }
                    }
                }
            }
    }

    private func select(atX x: CGFloat, proxy: ChartProxy, plotFrame: CGRect) {
        // 🔴 一律走 `orderedSamples`——索引基準必須與 `ReplayPoint.sampleIndex`
        // 相同（見 `orderedSamples` 的說明）。也不再要求重放成功：異常時三欄照常可拖曳。
        guard !orderedSamples.isEmpty,
              let minutes: Double = proxy.value(atX: x - plotFrame.minX) else { return }
        let t = minutes * 60
        let nearest = orderedSamples.enumerated().min {
            abs($0.element.timeSeconds - t) < abs($1.element.timeSeconds - t)
        }
        selectedIndex = nearest?.offset
    }

    // MARK: - 選取點資訊列
    // port 自 JD2-Ultra companion DiveAnalysisView.calloutRow：Time/Depth/Temp/
    // Ceiling/No Deco 五欄等寬排版，label 在上、數值在下；只有真的需要警示時
    // （減壓中 / NDL 逼近）數值才用填色膠囊強調，其餘為一般深色文字。

    /// - Parameters:
    ///   - sample: **原始剖面樣本**——Time／Depth／Temp 三欄的唯一來源，與重放無關。
    ///   - point: 對應的重放點；`nil` ⇒ 前置判斷拒算（或該樣本無對應重放點），
    ///     Ceiling／No Deco 顯示「—」，**其餘三欄照常**（PM 2026-09-12 裁示 4.3）。
    private func calloutRow(_ sample: DiveProfileSample, point: DiveReplayEngine.ReplayPoint?) -> some View {
        // v1.2：畫面一致性——固定 5 欄排版，不因資料缺漏（例如沒有溫度樣本）而增減
        // 欄位數，缺的欄位一律用「—」佔位，不隱藏欄位本身。
        HStack(spacing: 0) {
            calloutCell(label: Text("Time"), value: timeLabel(sample.timeSeconds))
            calloutCell(label: Text("Depth"), value: unitSystem.formatDepth(sample.depthMeters, locale: languageManager.locale))
            calloutCell(
                label: Text("Temp"),
                value: sample.waterTemp.map { unitSystem.formatTemperature($0, locale: languageManager.locale) } ?? "—"
            )
            calloutCell(
                label: Text("Ceiling"),
                value: (point?.ceilingMeters ?? 0) > 0
                    ? unitSystem.formatDepthConservative(point!.ceilingMeters, locale: languageManager.locale) : "—",
                accent: (point?.ceilingMeters ?? 0) > 0 ? .deco : .neutral
            )
            calloutCell(
                label: Text("No Deco"),
                value: point.map { ndlText($0.ndlSeconds) } ?? "—",
                accent: (point?.ndlSeconds ?? .max) < AlgorithmConstants.ndlWarnMinutes * 60 ? .warning : .neutral
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
        // v1.2：畫面一致性——原本的 `.minimumScaleFactor(0.7)` 讓 5 欄各自的 Text
        // 依「自己的字串長度是否超出所分到的等寬欄位」獨立決定縮放比例，不同潛水的
        // 數值字串長度不同（"16'24"" vs "33'00"" 等）就可能讓同一列裡各欄縮放比例不一致，
        // 使用者會覺得「文字大小格式不一樣」。改用固定不縮放的 `.footnote`——在最窄的
        // 支援機型（iPhone SE，5 欄等寬）下這個字級搭配目前最長的數值字串仍然放得下，
        // 不需要再靠縮放救援，確保每次都是同一個絕對字級。
        //
        // ⚠️ label 當時漏了同樣處理：沒設 lineLimit，某些語言的 label 翻譯偏長（例如
        // 德文 "Deco-Ceiling / Decotiefe"、印尼文/馬來文/希臘文 "No Deco / ..." 這類
        // 保留雙語的複合字串）在這個等寬窄欄位裡會折成兩行，撐高整列高度、跟數值行
        // 對不齊。先加 `.lineLimit(1)` 讓過長的 label 用省略號截斷、不折行，維持列高
        // 一致；翻譯內容本身是否要縮短（跟數值一樣改成單一絕對字級或改語意）留給
        // 翻譯校對決定，這裡只處理版面不會壞掉。
        //
        // ⚠️ 2026-07-26 真機回報：泰文 "No Deco" 被截斷成看不懂的 "No Deco..."——這是
        // "No Deco" 這個 label 本身是安全相關資訊（免減壓時間），單純省略號截斷等於
        // 讓使用者看不到內容，比縮小字級更糟。額外補 `.minimumScaleFactor`，讓過長的
        // label 優先縮小字級塞進去、真的塞不下才觸發 lineLimit 省略號（雙重保險）。
        // 這是翻譯內容長度無關的通用版面修法，另外也同一批把翻譯內容本身的多餘雙語
        // 冗字修掉（見 V1_2_BACKLOG）。
        VStack(spacing: 3) {
            label
                .font(.caption2)
                .foregroundStyle(Color.accessibleSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(verbatim: value)
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(accent.textColor)
                .lineLimit(1)
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
                Text(unitSystem.formatDepth(warning.depthMeters, decimals: 0, locale: languageManager.locale))
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
        case .ascentRateExceeded:  return languageManager.localized("Ascent Rate Alert")
        case .mandatorySafetyStop: return languageManager.localized("Mandatory Safety Stop")
        }
    }

    private func warningDetail(_ kind: DiveReplayEngine.ReplayWarningKind) -> String {
        // 門檻讀自 DiveKit AlgorithmConstants，不寫死，避免 Kit 端常數異動後
        // 這裡（含 18 語言翻譯）不會跟著動（R-060 附帶發現）。
        let mpm = AlgorithmConstants.maxAscentRateWarn
        let fpm = mpm * 3.28084
        switch kind {
        case .ascentRateExceeded:
            return String(format: languageManager.localized("Ascent rate exceeded %1$.0f m/min (%2$.1f ft/min)."), locale: languageManager.locale, mpm, fpm)
        case .mandatorySafetyStop:
            return String(format: languageManager.localized("Safety stop became mandatory: ascent rate stayed above %1$.0f m/min (%2$.1f ft/min) for %3$d seconds."), locale: languageManager.locale, mpm, fpm, AlgorithmConstants.ascentSustainedWarnSec)
        }
    }

    private func timeLabel(_ seconds: Double) -> String {
        "\(Int(seconds) / 60)'\(String(format: "%02d", locale: languageManager.locale, Int(seconds) % 60))\""
    }

    /// 與 Ultra companion PlanModel.ndlText 相同的顯示規則（99+ / 分鐘）。
    ///
    /// CH-18（顯示取整方向常駐檢查）：NDL 是「還剩多少免減壓時間」，安全的顯示
    /// 方向是**絕不比真實值多**——`seconds / 60` 對非負 `Int` 是無條件捨去
    /// （truncation towards zero == floor），例如真實 9'59" 顯示「9'」而非「10'」，
    /// 潛水員不會因為看到的剩餘時間比實際多而多待。這裡故意保留 internal（非
    /// private）存取層級，讓 `DiveAnalysisViewNDLRoundingTests`（見
    /// JD2-LogbookTests/DiveLogModelTests.swift）能直接 `@testable import` 呼叫，
    /// 鎖定這個捨去方向，不再只靠人工檢查程式碼。
    func ndlText(_ seconds: Int) -> String {
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
    let dive = DiveLog(
        dateTime: Date(),
        location: "Preview Site",
        maxDepth: 30,
        diveTimeSeconds: 2700
    )
    DiveAnalysisView(dive: dive, samples: samples, gasMix: .air)
        .padding()
}
