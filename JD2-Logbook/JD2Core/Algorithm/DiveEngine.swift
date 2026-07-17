// DiveEngine.swift — DiveKit/Algorithm
// 基底：JD2Core v1.0 FINAL 🔒（含全部 13 項審計修復，原審計註解保留）
// JD2-Ultra 變更（標記 // JD2-Ultra:）：
//   - 完整減壓引導（DecoStatus：ceiling/floor/ASC TIME，業界規格）
//   - Deepstop（業界規格，可關閉）
//   - 上升超速 → 強制安全停留加時（業界規格）
//   - 演算法鎖定 Er：超越 ceiling > 3 分鐘 → 鎖 48h（業界規格）
//   - OxygenTracker（CNS 移出 + OTU + OLF%，業界規格）
//   - 深度警報 / 潛水時間警報（業界規格）
//   - 禁飛 / 水面間隔（SurfaceStatus，業界規格）
//   - 持久化快照（DiveComputerState）
//   - tick(now:) 可注入時間（測試）
//   - 警報輸出改為 AlertEvent 回呼（watchOS 端接 haptics；水下聽不到聲音）
//
// ⚠️ 必須在 @MainActor 執行（HealthKit 和 WCSession 限制）
// ⚠️ 初始化時自動呼叫 buhlmann.updateSurface() → hasReceivedUpdate = true
// ⚠️ 時間補償機制：若 deltaT > 120s，視為數據間隙，不補算（避免飄移）

import Foundation
import Observation

// MARK: - Dive State Machine
public enum DiveState: Equatable, Sendable {
    case surface           // 水面待機
    case diving            // 潛水中
    case ascent            // 上升中
    case deepstop          // JD2-Ultra: 深停中（業界規格）
    case safetyStop        // 安全停留
    case decompression     // 減壓停留
    case postDive          // 潛水結束（3分鐘倒數後）
}

// MARK: - Data Gap Quality
public enum DataGapLevel: Equatable, Sendable {
    case normal            // 正常（< 2s 間隙）
    case degraded          // 降級（2-10s 間隙）
    case critical          // 嚴重（10-120s 間隙，但補算）
    case lost              // 喪失（> 120s，無補算，hasDataGap = true）
}

// MARK: - Alert State
public struct AlertState: Equatable, Sendable {
    public var ascentWarning: Bool = false
    public var ascentSustained: Bool = false
    public var ndlWarning: Bool = false              // < 3 min
    public var ndlCritical: Bool = false             // < 1 min
    public var decoViolation: Bool = false           // 高於 ceiling（寬限倒數中）
    public var sensorFailure: Bool = false
    public var exceeds40m: Bool = false
    // JD2-Ultra: 業界標準 警報補齊
    public var decoEntered: Bool = false             // NDL→deco 轉換（低優先，提示上升）
    public var deepstopViolated: Bool = false        // 深停未完成即上升
    public var safetyStopViolated: Bool = false      // 強制安全停留未完成即上升
    public var po2High: Bool = false                 // PO₂ 超過設定上限（高優先）
    public var olfWarning: Bool = false              // OLF ≥ 80%
    public var olfCritical: Bool = false             // OLF ≥ 100%
    public var depthAlarm: Bool = false              // 使用者設定深度警報
    public var diveTimeAlarm: Bool = false           // 使用者設定時間警報
    public var algorithmLocked: Bool = false         // Er 狀態（鎖定中）

    public init() {}
}

// JD2-Ultra: 警報事件（高/低優先對應 業界規格 的兩級聲響；watchOS 端轉 haptics + 視覺）
public enum AlertEvent: Equatable, Sendable {
    case highPriority(AlertKind)
    case lowPriority(AlertKind)

    public enum AlertKind: Equatable, Sendable {
        case po2High            // 立即上升或換低氧氣體
        case ceilingViolated    // 立即下潛回 ceiling 以下
        case ascentTooFast      // SLOW
        case decoEntered        // 開始減壓潛水，請上升
        case deepstopViolated
        case deepstopReached    // 深停開始（兩短聲）
        case safetyStopViolated
        case olfReached         // 80% / 100%
        case maxDepthReached    // 深度警報
        case diveTimeReached    // 時間警報
        case algorithmLocked    // Er 鎖定生效（審計 G6：原名 algorithmLockImminent 與時機不符）
        case variometer         // 0.2.0(A3)：變深度計——每 N 公尺提醒
    }
}

// MARK: - Core Engine
@MainActor  // ✅ FIXED Issue #2: 添加 @MainActor
@Observable  // JD2-Ultra: SwiftUI 直接觀察引擎狀態
public final class DiveEngine {

    // MARK: - Configuration & Dependencies
    public let buhlmann: Buhlmann
    public var environment: DiveEnvironment {
        get { buhlmann.environment }
        set { buhlmann.environment = newValue }
    }

    // JD2-Ultra: 模式設定（水面時才允許套用會影響演算法的變更）
    public private(set) var settings = DiveSettings()

    // JD2-Ultra: 警報事件回呼（watchOS 端接 WKInterfaceDevice haptics）
    public var onAlert: ((AlertEvent) -> Void)?

    // MARK: - State
    // JD2-Ultra(AG 稽核 R1)：進入 .ascent 時記錄當下深度為「上升以來最淺深度」基準。
    //   只在「真正轉入上升」的瞬間鎖定一次；後續每 tick 由 determineState 取 min 更新。
    //   depth 在 tick() 開頭即已設為當前值，故 didSet 取得的是現值（restore/reset 仍為 .surface，不受影響）。
    public private(set) var state: DiveState = .surface {
        didSet {
            if state == .ascent && oldValue != .ascent {
                minDepthSinceAscent = depth
            }
        }
    }
    public private(set) var depth: Double = 0.0
    public private(set) var maxDepth: Double = 0.0
    public private(set) var diveTimeSeconds: Int = 0
    public private(set) var waterTemperature: Double = 15.0
    public private(set) var currentGasMix: GasMix = .air

    // MARK: - Calculated Values
    public private(set) var ndlSeconds: Int = 0
    public private(set) var ceilingDepth: Double = 0.0
    public private(set) var ascentRateMpm: Double = 0.0
    public private(set) var po2: Double = 0.0
    public private(set) var gf: Double = 0.85
    // JD2-Ultra: 完整減壓引導 + 氧暴露
    public private(set) var deco = DecoStatus()
    public private(set) var oxygen = OxygenTracker()
    public var cns: Double { oxygen.cnsPercent }
    public var olfPercent: Double { oxygen.olfPercent }

    // MARK: - Safety & Alerts
    public private(set) var alerts = AlertState()
    public private(set) var dataGapLevel: DataGapLevel = .normal
    public private(set) var hasDataGap: Bool = false

    // MARK: - Safety Stop State
    public private(set) var safetyStopActive: Bool = false
    public private(set) var safetyStopTimeRemaining: Int = 0
    // JD2-Ultra: 上升超速懲罰 → 安全停留轉為強制並加時（業界規格）
    public private(set) var safetyStopMandatory: Bool = false
    /// §2.2.1（M19）：5.1–7m 緩衝區＝暫停倒數（UI 黃閃，不歸零）
    public private(set) var safetyStopPaused: Bool = false
    private var mandatoryStopExtraSec: Int = 0

    // JD2-Ultra: Deepstop 狀態（業界規格：>20m 啟用，停在最大深度一半）
    public private(set) var deepstopDepth: Double = 0.0
    public private(set) var deepstopTimeRemaining: Int = 0
    private var deepstopCompleted: Bool = false
    private var deepstopAccumulator: Double = 0.0

    // JD2-Ultra: 水面 / 禁飛 / Er（持久化對象）
    public private(set) var surfaceStatus = SurfaceStatus()

    // MARK: - Surface Interval Tracking
    public private(set) var surfaceIntervalSeconds: Int = 0
    public private(set) var postDiveDelaySec: Int = 0  // 出水後延遲倒數（Surface Delay；UI 顯示用）

    // MARK: - Data Quality Tracking
    private var lastUpdateTime: Date?
    private var prevDepth: Double = 0.0
    // JD2-Ultra(AG 稽核 R1)：上升以來抵達的最淺深度。再下潛判定基準（取代易卡死的 prevDepth+1.0）。
    private var minDepthSinceAscent: Double = 0.0
    // JD2-Ultra(審計 Y1)：超速累積以「秒」為單位（原版以 tick 數充當秒，非 1Hz 時失真）
    private var ascentWarnSeconds: Double = 0

    // ✅ FIXED Issue #8: 精確的時間累積
    private var accumulatedDiveTime: Double = 0.0
    private var accumulatedPostDiveDelay: Double = 0.0

    // JD2-Ultra: Er 寬限（超越 ceiling 連續秒數；> 180s → 鎖定）
    private var ceilingViolationAccumulator: Double = 0.0
    private var erTriggeredThisDive: Bool = false

    // JD2-Ultra: 警報去重（同一事件潛水中只發一次，直到條件解除）
    private var firedAlerts: Set<AlertEvent.AlertKind> = []
    // 0.2.0(A3)：額外深度警報槽去重（每槽每潛一次）＋變深度計基準
    private var firedDepthSlots: Set<Int> = []
    private var variometerMark: Double = 0

    // MARK: - 40m Depth Limit (Critical Safety)
    private let HARD_DEPTH_LIMIT: Double = 40.0

    // default params 移入 body，避免 Swift 嚴格並行在 nonisolated 呼叫端求值時產生警告
    public init(buhlmann: Buhlmann? = nil, environment: DiveEnvironment? = nil) {
        let b   = buhlmann    ?? Buhlmann()
        let env = environment ?? .seaLevel
        self.buhlmann = b
        self.buhlmann.environment = env
        // ⚠️ MUST initialize tissue state before any dive
        self.buhlmann.updateSurface(deltaT: 1.0)
        self.lastUpdateTime = nil   // JD2-Ultra: 第一次 tick 用注入的 now 起算，避免 init/tick 時鐘混用
    }

    // MARK: - JD2-Ultra: 設定套用 / 持久化

    /// 套用設定。影響演算法的項目（personal/altitude/氣體）僅在水面狀態接受。
    /// - Returns: 是否完整套用（false = 潛水中，僅套用了非演算法項目）
    @discardableResult
    public func apply(settings newSettings: DiveSettings) -> Bool {
        if state == .surface || state == .postDive {
            settings = newSettings
            buhlmann.apply(personal: newSettings.personal)
            if buhlmann.environment != newSettings.altitude.environment() {
                // JD2-Ultra: 切換高度檔位必須保留組織殘氮（上高度後體內氮不會消失！）
                // 流程：暫存組織 → reset（解除 hasReceivedUpdate 防護）→ 換環境 → 還原組織
                let savedTissues = buhlmann.tissuePressures
                buhlmann.reset()
                buhlmann.environment = newSettings.altitude.environment()
                buhlmann.restoreTissues(savedTissues)
            }
            return true
        } else {
            // 潛水中只接受警報/取樣率等非演算法項目
            var merged = settings
            merged.depthAlarmEnabled = newSettings.depthAlarmEnabled
            merged.depthAlarmMeters = newSettings.depthAlarmMeters
            merged.diveTimeAlarmMinutes = newSettings.diveTimeAlarmMinutes
            merged.scubaSampleRateSec = newSettings.scubaSampleRateSec
            merged.units = newSettings.units
            settings = merged
            return false
        }
    }

    /// 目前安全狀態快照（呼叫端負責落地，建議：潛水結束、App 進背景、每 5 分鐘）
    /// 審計 G14：加速模擬時 now 為剖面時間軸（可能在牆鐘未來）；restore 的 elapsed
    /// 已以 max(0,·) 防呆，真機（牆鐘）不受影響。
    public func snapshot(now: Date = Date()) -> DiveComputerState {
        DiveComputerState(tissuePN2: buhlmann.tissuePressures,
                          environment: buhlmann.environment,
                          oxygen: oxygen,
                          surface: surfaceStatus,
                          pendingErViolation: erTriggeredThisDive,   // 審計 Y2：潛水中觸發的 Er 隨快照保留
                          gfHigh: buhlmann.gfHigh,                   // M22：widget 算可去海拔用
                          savedAt: now)
    }

    /// 自持久化狀態還原（App 啟動時呼叫；內含離線水面脫飽和補算）
    public func restore(from state: DiveComputerState, now: Date = Date()) {
        let restored = state.restore(into: buhlmann, now: now)
        oxygen = restored.oxygen
        surfaceStatus = restored.surface
        alerts.algorithmLocked = surfaceStatus.isAlgorithmLocked(now: now)
        // 稽核修復 #4：App 關閉超過 24h 後重啟，還原當下就該歸零，不必等下次 tick
        resetStaleOTUIfNeeded(now: now)
    }

    // MARK: - Lifecycle

    /// Called per frame/second to update all calculations
    /// Returns true if state changed
    /// JD2-Ultra: now 參數可注入（測試）；正式呼叫端用預設值
    @discardableResult
    public func tick(depth: Double, gasMix: GasMix? = nil,
                     waterTemp: Double = 15.0, now: Date = Date()) -> Bool {
        let gasMix = gasMix ?? settings.activeGas
        let deltaT = max(0.001, now.timeIntervalSince(lastUpdateTime ?? now))
        lastUpdateTime = now

        self.depth = depth
        self.waterTemperature = waterTemp
        self.currentGasMix = gasMix

        // Calculate ascent rate (m/min) — uses prevDepth from PREVIOUS tick (correct)
        let depthDelta = depth - prevDepth
        if deltaT > 0 {
            ascentRateMpm = (depthDelta / deltaT) * 60.0
        }
        // ⚠️ prevDepth = depth is intentionally moved to AFTER determineState()

        // Determine data gap level
        determinateDataGapLevel(deltaT: deltaT)

        // ✅ FIXED Issue #5 + Audit Fix #2: 組織壓力必須在任何深度持續更新
        // ⚠️ 40m 限制僅用於 UI Alert（alerts.exceeds40m），不得阻斷 Bühlmann 計算
        //    超過 40m 繼續吸氮，演算法停算將導致回到 39m 時給出致死級樂觀 NDL
        if !hasDataGap {
            // Normal update with time compensation
            let compensatedDeltaT = min(deltaT, AlgorithmConstants.maxCompensateTotalSec)
            let chunkSize = AlgorithmConstants.tickChunkSizeSec
            var remainingTime = compensatedDeltaT
            var elapsed: Double = 0.0
            // 稽核修復 #1：chunk 迴圈內每一步都須傳入該步「對應時刻」的深度，而非最終
            // depth——buhlmann.update() 每次呼叫都會把內部 prevDepth 設為傳入的 depth，
            // 若每個 chunk 都傳最終 depth，第一個 chunk 之後 depthDelta 恆為 0，pRate
            // 被錯誤歸零，等同把補算期間全當作恆深。改為依已耗用時間比例，在
            // prevDepth（本次 tick 開始前的深度）→ depth（本次 tick 最終深度）之間
            // 線性插值，還原 Schreiner 方程式假設的均勻升降過程。
            let startDepth = prevDepth

            while remainingTime > 0.001 {
                let chunk = min(chunkSize, remainingTime)
                elapsed += chunk
                let fraction = compensatedDeltaT > 0 ? min(1.0, elapsed / compensatedDeltaT) : 1.0
                let interpolatedDepth = startDepth + (depth - startDepth) * fraction
                buhlmann.update(depth: interpolatedDepth, gasMix: gasMix, deltaT: chunk)
                remainingTime -= chunk
            }
        }

        // Calculate real-time values
        if depth >= HARD_DEPTH_LIMIT {
            // ⚠️ CRITICAL: 40m hard limit enforcement (Requirement #5)
            alerts.exceeds40m = true
            ndlSeconds = 0  // Force NDL to 0, show "---"
            ceilingDepth = buhlmann.ceiling(at: depth)   // JD2-Ultra: ceiling 仍須計算（減壓義務不因超深而消失）
        } else {
            alerts.exceeds40m = false
            ndlSeconds = buhlmann.ndlSeconds(at: depth, gasMix: gasMix)
            ceilingDepth = buhlmann.ceiling(at: depth)
        }

        po2 = calculatePO2(depth: depth, gasMix: gasMix)
        gf = buhlmann.currentGF(at: depth)

        // JD2-Ultra: 完整減壓引導（水下且有減壓義務、或接近時計算）
        // B10：lastStopDepthMeters 作為引導/模擬的停留底線
        let isUnderwaterNow = state != .surface && state != .postDive
        if isUnderwaterNow {
            deco = DecoCalculator.status(buhlmann: buhlmann, depth: depth, gasMix: gasMix,
                                         lastStopMeters: settings.lastStopDepthMeters)
        } else {
            deco = DecoStatus()
        }

        // ⚠️ Ascent rate validation (Requirement #6 + alert)
        updateAscentWarnings(deltaT: deltaT)

        // ⚠️ NDL warnings
        updateNDLWarnings()

        // JD2-Ultra: 業界標準 警報群（PO₂ / OLF / 深度 / 時間 / 減壓違規→Er）
        updateUltraAlerts(deltaT: deltaT)

        // Update max depth
        if depth > maxDepth {
            maxDepth = depth
        }

        let prevState = state

        // State machine transitions
        determineState(depth: depth, deltaT: deltaT)

        // ✅ FIXED Audit: prevDepth 必須在 determineState() 之後才更新
        prevDepth = depth

        // ✅ FIXED Audit Fix #3: CNS 在狀態確定後更新（水面衰減 vs 水下累積）
        // JD2-Ultra: 移至 OxygenTracker（含 OTU）
        let isUnderwater = state == .diving || state == .ascent || state == .deepstop
                        || state == .safetyStop || state == .decompression
        oxygen.update(po2: po2, deltaT: deltaT, isUnderwater: isUnderwater)
        alerts.olfWarning = oxygen.isWarning && !oxygen.isCritical
        alerts.olfCritical = oxygen.isCritical
        if oxygen.isWarning { fireOnce(.lowPriority(.olfReached)) }

        // ✅ FIXED Issue #8 + Audit Fix #7: 精確的時間累積，水下所有狀態均計時
        if isUnderwater {
            accumulatedDiveTime += deltaT
            diveTimeSeconds = Int(accumulatedDiveTime)
        }
        // JD2-Ultra: 修正基底 bug——原版條件為 state == .surface，但 postDive 狀態永遠不是
        // surface，postDiveDelaySec 永不遞減 → 卡死在 postDive。改為在 .postDive 累計。
        if state == .postDive && postDiveDelaySec > 0 {
            accumulatedPostDiveDelay += deltaT
            postDiveDelaySec = max(0, settings.diveEndDelaySec - Int(accumulatedPostDiveDelay))
        }
        if state == .surface || state == .postDive {
            surfaceIntervalSeconds += Int(deltaT)
        }

        return state != prevState
    }

    // MARK: - State Determination

    private func determineState(depth: Double, deltaT: Double) {
        switch state {
        case .surface:
            // 稽核修復 #4：只要留在水面就持續檢查，不必等到下一次 beginDive() 才歸零
            resetStaleOTUIfNeeded(now: lastUpdateTime ?? Date())

            // Check if descent starts
            if depth >= AlgorithmConstants.diveStartDepth {
                state = .diving
                beginDive()
            }

        case .diving:
            // Check if ascending
            if depth < prevDepth {
                state = .ascent
                // ✅ FIXED Audit Fix #4.1 + GF 保護：只在新天花板更深（壓力更高）時才更新基準
                // Erik Baker 規範：firstCeilingBar 應鎖定離開底部時最深的天花板壓力
                let newCeil = buhlmann.rawCeiling()
                if buhlmann.firstCeilingBar == nil || newCeil > buhlmann.firstCeilingBar! {
                    buhlmann.firstCeilingBar = newCeil
                }
            }
            // Check if safety stop depth reached
            else if depth <= AlgorithmConstants.safetyStopTriggerDepth
                && maxDepth >= AlgorithmConstants.safetyStopMinDiveDepth {
                enterSafetyStop()
            }

        case .ascent:
            // JD2-Ultra(AG 稽核 R1)：再下潛判定改用「上升以來最淺深度 + 1.0m」。
            //   舊版用 prevDepth+1.0 → 需單一 tick 內下潛 >1m（=60 m/min，生理不可能），
            //   一旦因呼吸雜訊（-0.3m）誤入 .ascent 就永遠卡死，導致正常速率再下潛無法回 .diving，
            //   firstCeilingBar 凍結在錯誤（過淺）天花板、GF 全程用 gfHigh → 致死級樂觀 NDL/淺停。
            //   新版：累進追蹤上升中最淺點，正常速率（如 10 m/min）再下潛超過該點 1m 即正確回 .diving。
            // ⚠️ 不重置 firstCeilingBar — 回 .diving 後若真正上升，rawCeiling 較深會自動覆蓋（Erik Baker 規範取最大）。
            minDepthSinceAscent = min(minDepthSinceAscent, depth)
            if depth > (minDepthSinceAscent + 1.0) && depth >= AlgorithmConstants.diveStartDepth {
                state = .diving
                return
            }
            // JD2-Ultra: Deepstop 觸發（業界規格：>20m 的潛水，停於最大深度一半）
            if shouldEnterDeepstop(depth: depth) {
                enterDeepstop()
                return
            }
            // Check if decompression stop required
            if ceilingDepth > 0 && depth <= ceilingDepth + DecoStatus.ceilingZoneMeters + 0.5 {
                // JD2-Ultra: 進入減壓停留狀態 = 到達 ceiling zone 附近（提供連續減壓引導）
                // decoViolation 旗標僅在「高於 ceiling」時由 updateUltraAlerts 設定，不在此處
                state = .decompression
            }
            // ✅ FIXED Audit Fix #5: 統一用 safetyStopTriggerDepth (6.0m)，與 .diving 分支一致
            else if ceilingDepth <= 0
                && depth <= AlgorithmConstants.safetyStopTriggerDepth
                && maxDepth >= AlgorithmConstants.safetyStopMinDiveDepth {
                enterSafetyStop()
            }
            // Check if surface reached
            else if depth < AlgorithmConstants.diveEndDepth {
                // JD2-Ultra: 強制安全停留未完成即出水 → 違規記錄
                // 審計 Y7：mandatoryStopExtraSec > 0 也算（淺潛欠停留、從未進入 safetyStop 狀態的情形）
                if mandatoryStopExtraSec > 0
                    || (safetyStopMandatory && safetyStopTimeRemaining > 0) {
                    alerts.safetyStopViolated = true
                    fireOnce(.lowPriority(.safetyStopViolated))
                }
                endDive()
            }

        // JD2-Ultra: Deepstop 狀態（呈現方式同安全停留：CEILING + DEEPSTOP + 倒數）
        case .deepstop:
            deepstopAccumulator += deltaT
            deepstopTimeRemaining = max(0, AlgorithmConstants.deepstopDurationSec - Int(deepstopAccumulator))

            // 審計 Y9：減壓引導優先——ceiling 加深至深停窗附近即中止深停（避免「停留」與
            // 「違規下潛」同時出現的指引衝突；不記違規，轉回 ascent 由減壓引導接手）
            if ceilingDepth >= deepstopDepth - 1.0 {
                deepstopCompleted = true
                state = .ascent
            }
            else if depth < deepstopDepth - AlgorithmConstants.deepstopWindowMeters {
                // 未完成即上升 → 深停違規（業界慣例：低優先警報 + 下降箭頭）
                if deepstopTimeRemaining > 0 {
                    alerts.deepstopViolated = true
                    fireOnce(.lowPriority(.deepstopViolated))
                }
                deepstopCompleted = true
                state = .ascent
            } else if depth > deepstopDepth + 3.0 {
                // 顯著再下潛 → 回 diving（深停之後重新評估）
                deepstopCompleted = false
                deepstopAccumulator = 0
                state = .diving
            } else if deepstopTimeRemaining <= 0 {
                deepstopCompleted = true
                state = .ascent
            }

        case .safetyStop:
            // §2.2.1（M19）三段區間：>7m 歸零重置退出／5.1–7m 緩衝暫停／≤5m 倒數
            if depth > AlgorithmConstants.safetyStopHoldMax {
                // 超深 → 歸零重置、退回潛水（再上升重新進入時 enterSafetyStop 會補滿）
                safetyStopPaused = false
                safetyStopActive = false
                safetyStopTimeRemaining = settings.safetyStopDurationSec + mandatoryStopExtraSec
                state = .diving
            } else if depth < AlgorithmConstants.diveEndDepth {
                // 出水（<1m）：強制停留未完成→違規；一律結算
                if safetyStopMandatory && safetyStopTimeRemaining > 0 {
                    alerts.safetyStopViolated = true
                    fireOnce(.lowPriority(.safetyStopViolated))
                }
                safetyStopPaused = false
                safetyStopActive = false
                endDive()
            } else if depth > AlgorithmConstants.safetyStopValidMax {
                // 5.1–7m 緩衝區：暫停倒數（不歸零、不結束），UI 黃閃
                safetyStopPaused = true
            } else {
                // ≤5m 目標區：正常倒數（以 deltaT 累積）
                safetyStopPaused = false
                safetyStopTimeRemaining = max(0, safetyStopTimeRemaining - Int(deltaT.rounded()))
                if safetyStopTimeRemaining <= 0 { mandatoryStopExtraSec = 0 }   // 審計 Y7
            }

        case .decompression:
            // ✅ FIXED Audit Fix #4.2: 天花板解除後若仍在水中，回到 .ascent 繼續上升
            if ceilingDepth <= 0 {
                alerts.decoViolation = false
                ceilingViolationAccumulator = 0
                if depth < AlgorithmConstants.diveEndDepth {
                    endDive()
                } else {
                    state = .ascent  // 天花板解除，恢復正常上升（保留 firstCeilingBar）
                }
            } else if depth < AlgorithmConstants.diveEndDepth {
                // JD2-Ultra: 帶著減壓義務直接出水 → 視同違規出水（Er 倒數由水下累積決定，
                // 出水後組織持續以水面壓力計算；業界標準行為：浮出後 Er 檢查在下一次 tick 收斂）
                endDive()
            }

        case .postDive:
            // JD2-Ultra: 3 分鐘內再下潛 = 同一次潛水繼續（業界標準行為；潛水時間/最大深度保留）
            if depth >= AlgorithmConstants.diveStartDepth {
                postDiveDelaySec = 0
                accumulatedPostDiveDelay = 0.0
                state = .diving
            }
            // Wait for 3-minute delay → 正式結束本次潛水並結算
            else if postDiveDelaySec <= 0 {
                finalizeDive()
            }
        }
    }

    // MARK: - JD2-Ultra: 潛水開始/結束

    /// JD2-Ultra(審計 Y5) + 稽核修復 #4：OTU 是單日概念（REPEX）——超過 24h 未潛水則歸零。
    /// 原本只在 beginDive() 觸發時檢查，若潛水員完成潛水後在水面停留超過 24 小時
    /// 卻遲遲未開始下一次潛水，beginDive() 永遠不會被呼叫，UI/Widget 顯示的 OTU
    /// 會一直卡在舊值，造成生理安全數值上的顯示矛盾。改為抽成共用檢查，同時在
    /// beginDive()、水面 tick、以及 restore()（App 重啟還原狀態）都會執行。
    private func resetStaleOTUIfNeeded(now: Date) {
        if let last = surfaceStatus.lastSurfacedAt,
           now.timeIntervalSince(last) > 24 * 3600 {
            oxygen.resetDailyOTU()
        }
    }

    private func beginDive() {
        diveTimeSeconds = 0
        accumulatedDiveTime = 0.0
        maxDepth = 0.0
        postDiveDelaySec = 0
        firedDepthSlots.removeAll()        // 0.2.0(A3)
        variometerMark = 0
        buhlmann.firstCeilingBar = nil  // Reset GF baseline
        resetStaleOTUIfNeeded(now: lastUpdateTime ?? Date())
        // JD2-Ultra: 本次潛水的引導狀態歸零
        deepstopCompleted = false
        deepstopAccumulator = 0
        deepstopTimeRemaining = 0
        safetyStopMandatory = false
        safetyStopPaused = false
        mandatoryStopExtraSec = 0
        ceilingViolationAccumulator = 0
        erTriggeredThisDive = false
        firedAlerts.removeAll()
        var cleared = AlertState()
        cleared.algorithmLocked = alerts.algorithmLocked   // Er 鎖定跨潛水保留
        alerts = cleared
    }

    /// 出水（深度 < diveEndDepth）→ 進入確認期（B10：時長可調），尚未結算
    private func endDive() {
        state = .postDive
        postDiveDelaySec = settings.diveEndDelaySec
        accumulatedPostDiveDelay = 0.0
        surfaceIntervalSeconds = 0
        // ⚠️ firstCeilingBar 在 finalizeDive 才清——確認期內再下潛屬同一次潛水，GF 基準延續
    }

    /// 水面滿 3 分鐘 → 正式結束本次潛水並結算（禁飛 / 系列 / Er，業界規格）
    private func finalizeDive() {
        state = .surface
        // M22：歸零前捕捉上次潛水摘要（complication 顯示；隨 SurfaceStatus 持久化）
        surfaceStatus.lastDiveMaxDepth = maxDepth
        surfaceStatus.lastDiveDurationSec = diveTimeSeconds
        diveTimeSeconds = 0
        maxDepth = 0.0
        accumulatedPostDiveDelay = 0.0
        buhlmann.firstCeilingBar = nil

        let now = lastUpdateTime ?? Date()
        let desat = DiveComputerState.desaturationSeconds(
            tissuePN2: buhlmann.tissuePressures,
            environment: buhlmann.environment)
        surfaceStatus.diveEnded(at: now,
                                decoViolated: erTriggeredThisDive,
                                desaturationSeconds: desat)
        // 0.2.0(A7)：Gauge 潛水 → 24h 演算法鎖（組織數據不可信；業界同款）
        if settings.mode == .gauge {
            surfaceStatus.gaugeDiveEnded(at: now)
        }
        alerts.algorithmLocked = surfaceStatus.isAlgorithmLocked(now: now)
        // 審計 Y2：違規已結算進 surfaceStatus，清除潛水內旗標（快照的 pendingEr 僅指「未結算」）
        erTriggeredThisDive = false
    }

    // JD2-Ultra(AG 稽核 R2)：自潛/浮潛模式繞過 tick()（改直接驅動 buhlmann.update）時，
    //   引擎內部 lastUpdateTime 會停滯；切回水肺第一個 tick 的 deltaT 會突然變成整段自潛時長，
    //   超過 120s 熔斷 → 誤判 dataGapLevel = .lost（單 tick 假性 sensor gap 警示）。
    //   組織氮壓本身在自潛期間已被正確更新、無丟失；此處僅對齊時鐘消除誤報。
    public func syncSurfaceClock(now: Date) {
        lastUpdateTime = now
    }

    // JD2-Ultra(審計 Y4): 自潛 session 結束時結算水面狀態
    // （業界規格：desat > 70 分鐘即顯示禁飛，不分模式；自潛同樣累積氮）
    // 稽核 2026-07-03 A：補上次潛水摘要（complication 與 App 內顯示一致）
    public func finalizeFreeSession(now: Date = Date(),
                                    lastDiveMaxDepth: Double? = nil,
                                    lastDiveDurationSec: Int? = nil) {
        let desat = DiveComputerState.desaturationSeconds(
            tissuePN2: buhlmann.tissuePressures,
            environment: buhlmann.environment)
        surfaceStatus.diveEnded(at: now, decoViolated: false, desaturationSeconds: desat)
        if let depth = lastDiveMaxDepth, let dur = lastDiveDurationSec {
            surfaceStatus.lastDiveMaxDepth = depth
            surfaceStatus.lastDiveDurationSec = dur
        }
    }

    /// 稽核 2026-07-03 B：浮潛 session 結束——僅更新「水中活動」時間供水面間隔顯示。
    /// ⚠️ 刻意不走 diveEnded()：浮潛無氮負載追蹤，不得影響系列判定/禁飛/組織。
    public func snorkelSessionEnded(at now: Date = Date()) {
        surfaceStatus.lastWaterActivityAt = now
    }

    // MARK: - JD2-Ultra: Deepstop 判定

    private func shouldEnterDeepstop(depth: Double) -> Bool {
        guard settings.deepstopEnabled,
              settings.mode != .free,
              !deepstopCompleted,
              maxDepth > AlgorithmConstants.deepstopActivationDepth else { return false }
        let stopDepth = (maxDepth / 2.0).rounded()
        guard stopDepth >= AlgorithmConstants.deepstopMinStopDepth else { return false }
        // 上升通過深停深度 ± window 時觸發；深停深度不得高於減壓 ceiling
        guard stopDepth > ceilingDepth + 1.0 else { return false }
        if abs(depth - stopDepth) <= AlgorithmConstants.deepstopWindowMeters {
            deepstopDepth = stopDepth
            return true
        }
        return false
    }

    private func enterDeepstop() {
        state = .deepstop
        deepstopAccumulator = 0
        deepstopTimeRemaining = AlgorithmConstants.deepstopDurationSec
        fireOnce(.lowPriority(.deepstopReached))   // 業界慣例：到達深停，兩短聲
    }

    private func enterSafetyStop() {
        state = .safetyStop
        safetyStopActive = true
        // JD2-Ultra: 上升超速懲罰加時（業界規格）；B10：基礎時長可調
        safetyStopTimeRemaining = settings.safetyStopDurationSec + mandatoryStopExtraSec
        safetyStopMandatory = mandatoryStopExtraSec > 0
    }

    // MARK: - Safety Validations

    private func updateAscentWarnings(deltaT: Double) {
        let ascentRateThreshold = AlgorithmConstants.maxAscentRateWarn

        // ✅ FIXED Audit Fix #6: 移除 abs()，只有真正上升（負值 = 變淺）才觸發警報
        if ascentRateMpm < -ascentRateThreshold {
            ascentWarnSeconds += deltaT
            if ascentWarnSeconds >= Double(AlgorithmConstants.ascentWarnConsecutiveSec) {
                alerts.ascentWarning = true
            }
            if ascentWarnSeconds >= Double(AlgorithmConstants.ascentSustainedWarnSec) {
                let wasSustained = alerts.ascentSustained
                alerts.ascentSustained = true
                // ⚠️ Requirement #6: 高優先警報（業界慣例：SLOW 閃爍，高優先三連發）
                if !wasSustained {
                    onAlert?(.highPriority(.ascentTooFast))
                    // JD2-Ultra: 超速持續 → 強制安全停留加時（業界規格）
                    mandatoryStopExtraSec = min(
                        mandatoryStopExtraSec + AlgorithmConstants.mandatoryStopBaseSec,
                        AlgorithmConstants.mandatoryStopMaxSec)
                }
            }
        } else {
            ascentWarnSeconds = 0
            alerts.ascentWarning = false
            alerts.ascentSustained = false
        }
    }

    private func updateNDLWarnings() {
        // 0.2.0(A7)：Gauge 模式不提供 NDL 資訊
        if alerts.exceeds40m || settings.mode == .gauge {
            alerts.ndlWarning = false
            alerts.ndlCritical = false
            return
        }

        // JD2-Ultra: 已進入減壓 → NDL 警報語意被 deco 引導取代
        if ceilingDepth > 0 {
            alerts.ndlWarning = false
            alerts.ndlCritical = false
            return
        }

        let ndlMinutes = ndlSeconds / 60

        if ndlSeconds <= AlgorithmConstants.ndlCriticalSeconds {
            alerts.ndlCritical = true
            alerts.ndlWarning = false
            // 視覺警告為主；「實際進入減壓」的聲響/觸覺由 updateUltraAlerts 的 decoEntered 發出
        } else if ndlMinutes <= AlgorithmConstants.ndlWarnMinutes {
            alerts.ndlWarning = true
            alerts.ndlCritical = false
        } else {
            alerts.ndlWarning = false
            alerts.ndlCritical = false
        }
    }

    // MARK: - JD2-Ultra: 業界標準 警報群

    private func updateUltraAlerts(deltaT: Double) {
        let isUnderwater = state != .surface && state != .postDive

        // PO₂ 超標（高優先，業界規格：立即上升或換低 O₂ 氣體）
        let po2Exceeded = isUnderwater && po2 > settings.maxPO2
        if po2Exceeded && !alerts.po2High { onAlert?(.highPriority(.po2High)) }
        alerts.po2High = po2Exceeded

        // 進入減壓（低優先：NO DEC TIME → ASC TIME 轉換，業界規格；gauge 不提示）
        if isUnderwater && settings.mode != .gauge && ceilingDepth > 0 && !alerts.decoEntered {
            alerts.decoEntered = true
            fireOnce(.lowPriority(.decoEntered))
        } else if ceilingDepth <= 0 {
            alerts.decoEntered = false
        }

        // 超越 ceiling → 寬限 3 分鐘 → Er 鎖定（業界規格）
        // JD2-Ultra(審計 R1)：不得以 isUnderwater 限定——帶減壓義務直接出水是最徹底的
        // omitted deco，postDive 期間 ceiling 仍在計算（tick 恆算），寬限必須持續累積；
        // 僅在「已正式結算回 surface」後停止（dive 已結束，鎖定由 finalize 決定）。
        // 0.2.0(A7)：Gauge 模式不提供減壓資訊 → 不觸發違規/Er（鎖定改由 24h gauge lock 承擔）
        let ceilingViolating = settings.mode != .gauge
            && state != .surface
            && ceilingDepth > 0 && depth < ceilingDepth - 0.1
        if ceilingViolating {
            if !alerts.decoViolation {
                alerts.decoViolation = true
                onAlert?(.highPriority(.ceilingViolated))
            }
            ceilingViolationAccumulator += deltaT
            if ceilingViolationAccumulator >= Double(AlgorithmConstants.decoViolationGraceSec)
                && !erTriggeredThisDive {
                erTriggeredThisDive = true
                alerts.algorithmLocked = true
                onAlert?(.highPriority(.algorithmLocked))
            }
        } else {
            if alerts.decoViolation { alerts.decoViolation = false }
            if !erTriggeredThisDive { ceilingViolationAccumulator = 0 }
        }

        // 深度警報（業界規格，低優先，預設 30m）＋ 0.2.0(A3) 額外兩組
        var depthAlarmHit = isUnderwater && settings.depthAlarmEnabled
            && depth >= settings.depthAlarmMeters
        if depthAlarmHit && !alerts.depthAlarm { fireOnce(.lowPriority(.maxDepthReached)) }
        for (i, slot) in settings.extraDepthAlarms.enumerated()
        where slot.enabled && isUnderwater && depth >= slot.depthMeters {
            depthAlarmHit = true
            if !firedDepthSlots.contains(i) {
                firedDepthSlots.insert(i)
                onAlert?(.lowPriority(.maxDepthReached))
            }
        }
        alerts.depthAlarm = depthAlarmHit

        // 0.2.0(A3)：變深度計——自基準每變化 N 公尺提醒一次（上下皆計）
        if isUnderwater, let every = settings.variometerEveryMeters, every > 0 {
            if abs(depth - variometerMark) >= every {
                variometerMark = (depth / every).rounded() * every
                onAlert?(.lowPriority(.variometer))
            }
        }

        // 潛水時間警報（業界規格，低優先）
        if let limitMin = settings.diveTimeAlarmMinutes {
            let hit = isUnderwater && diveTimeSeconds >= limitMin * 60
            if hit && !alerts.diveTimeAlarm { fireOnce(.lowPriority(.diveTimeReached)) }
            alerts.diveTimeAlarm = hit
        } else {
            alerts.diveTimeAlarm = false
        }
    }

    /// 同一種警報每次潛水只發送一次（業界慣例：acknowledge 後不再響；watch 端以 haptic 呈現）
    private func fireOnce(_ event: AlertEvent) {
        let kind: AlertEvent.AlertKind
        switch event {
        case .highPriority(let k), .lowPriority(let k): kind = k
        }
        guard !firedAlerts.contains(kind) else { return }
        firedAlerts.insert(kind)
        onAlert?(event)
    }

    // MARK: - Data Quality Assessment

    private func determinateDataGapLevel(deltaT: Double) {
        if deltaT < 2.0 {
            dataGapLevel = .normal
            hasDataGap = false
        } else if deltaT < 10.0 {
            dataGapLevel = .degraded
            hasDataGap = false
        } else if deltaT < AlgorithmConstants.maxCompensateTotalSec {
            dataGapLevel = .critical
            hasDataGap = false
        } else {
            dataGapLevel = .lost
            hasDataGap = true
        }
    }

    // MARK: - Calculations

    private func calculatePO2(depth: Double, gasMix: GasMix) -> Double {
        let absolutePressure = environment.absolutePressure(at: depth)
        return absolutePressure * gasMix.fO2
    }

    // MARK: - 0.2.0 查詢

    /// B2：目前可安全前往的最高海拔（公尺；5000 = 顯示上限）
    public var allowedAltitudeMeters: Double {
        DiveComputerState.allowedAltitudeMeters(tissuePN2: buhlmann.tissuePressures,
                                                gfHigh: buhlmann.gfHigh)
    }

    /// M20-5：目前組織完全脫飽和所需時間（秒；0＝已脫飽和）——水面顯示用（即時由組織計算，非快照）
    public var desaturationRemainingSeconds: Int {
        DiveComputerState.desaturationSeconds(tissuePN2: buhlmann.tissuePressures,
                                              environment: buhlmann.environment)
    }

    /// A7：Gauge 鎖定中（24h 內僅 Gauge/Free 可用）
    public var isGaugeLocked: Bool {
        surfaceStatus.isGaugeLocked(now: lastUpdateTime ?? Date())
    }

    // MARK: - Reset

    public func reset() {
        state = .surface
        depth = 0.0
        maxDepth = 0.0
        diveTimeSeconds = 0
        ascentRateMpm = 0.0
        ndlSeconds = 0
        ceilingDepth = 0.0
        alerts = AlertState()
        deco = DecoStatus()
        safetyStopActive = false
        safetyStopTimeRemaining = 0
        safetyStopMandatory = false
        safetyStopPaused = false
        mandatoryStopExtraSec = 0
        deepstopCompleted = false
        deepstopTimeRemaining = 0
        deepstopAccumulator = 0
        postDiveDelaySec = 0
        // ✅ FIXED Issue #8: 重置時間累積器
        accumulatedDiveTime = 0.0
        accumulatedPostDiveDelay = 0.0
        ceilingViolationAccumulator = 0
        ascentWarnSeconds = 0
        erTriggeredThisDive = false
        firedAlerts.removeAll()
        oxygen.reset()
        surfaceStatus = SurfaceStatus()
        lastUpdateTime = nil
        buhlmann.reset()
        buhlmann.updateSurface(deltaT: 1.0)
    }
}

