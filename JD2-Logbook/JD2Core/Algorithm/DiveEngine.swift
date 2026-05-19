// DiveEngine.swift — JoyDiveCore/Algorithm/DiveEngine.swift
// v1.0 FINAL 🔒
//
// Core dive state machine, sensor integration, and real-time calculation engine
// ⚠️ 必須在 @MainActor 執行（HealthKit 和 WCSession 限制）
// ⚠️ 初始化時自動呼叫 buhlmann.updateSurface() → hasReceivedUpdate = true
// ⚠️ 時間補償機制：若 deltaT > 120s，視為數據間隙，不補算（避免飄移）

import Foundation

// MARK: - Dive State Machine
enum DiveState: Equatable {
    case surface           // 水面待機
    case diving            // 潛水中
    case ascent            // 上升中
    case safetyStop        // 安全停留
    case decompression     // 減壓停留
    case postDive          // 潛水結束（3分鐘倒數後）
}

// MARK: - Data Gap Quality
enum DataGapLevel: Equatable {
    case normal            // 正常（< 2s 間隙）
    case degraded          // 降級（2-10s 間隙）
    case critical          // 嚴重（10-120s 間隙，但補算）
    case lost              // 喪失（> 120s，無補算，hasDataGap = true）
}

// MARK: - Alert State
struct AlertState: Equatable {
    var ascentWarning: Bool = false
    var ascentSustained: Bool = false
    var ndlWarning: Bool = false              // < 3 min
    var ndlCritical: Bool = false             // < 1 min
    var decoViolation: Bool = false
    var sensorFailure: Bool = false
    var exceeds40m: Bool = false
}

// MARK: - Core Engine
@MainActor  // ✅ FIXED Issue #2: 添加 @MainActor
final class DiveEngine {

    // MARK: - Configuration & Dependencies
    let buhlmann: Buhlmann
    var environment: DiveEnvironment {
        get { buhlmann.environment }
        set { buhlmann.environment = newValue }
    }

    // MARK: - State
    private(set) var state: DiveState = .surface
    private(set) var depth: Double = 0.0
    private(set) var maxDepth: Double = 0.0
    private(set) var diveTimeSeconds: Int = 0
    private(set) var waterTemperature: Double = 15.0
    private(set) var currentGasMix: GasMix = .air

    // MARK: - Calculated Values
    private(set) var ndlSeconds: Int = 0
    private(set) var ceilingDepth: Double = 0.0
    private(set) var ascentRateMpm: Double = 0.0
    private(set) var po2: Double = 0.0
    private(set) var cns: Double = 0.0
    private(set) var gf: Double = 0.85

    // MARK: - Safety & Alerts
    private(set) var alerts = AlertState()
    private(set) var dataGapLevel: DataGapLevel = .normal
    private(set) var hasDataGap: Bool = false

    // MARK: - Safety Stop State
    private(set) var safetyStopActive: Bool = false
    private(set) var safetyStopTimeRemaining: Int = 0
    private var safetyStopTargetDepth: Double = 5.0

    // MARK: - Surface Interval Tracking
    private(set) var surfaceIntervalSeconds: Int = 0
    private var surfaceIntervalTimer: Timer?
    private var postDiveDelaySec: Int = 0  // 3分鐘倒數

    // MARK: - Data Quality Tracking
    private var lastUpdateTime: Date?
    private var prevDepth: Double = 0.0
    private var ascentWarnCounter: Int = 0
    private var ascentSustainedCounter: Int = 0

    // ✅ FIXED Issue #8: 精確的時間累積
    private var accumulatedDiveTime: Double = 0.0
    private var accumulatedPostDiveDelay: Double = 0.0

    // ✅ FIXED Audit Fix #3: NOAA Oxygen Clock 累積積分（0–200%）
    private var accumulatedCNS: Double = 0.0

    // MARK: - 40m Depth Limit (Critical Safety)
    private let HARD_DEPTH_LIMIT: Double = 40.0

    init(buhlmann: Buhlmann = Buhlmann(),
         environment: DiveEnvironment = .seaLevel) {
        self.buhlmann = buhlmann
        self.buhlmann.environment = environment
        // ⚠️ MUST initialize tissue state before any dive
        self.buhlmann.updateSurface(deltaT: 1.0)
        self.lastUpdateTime = Date()
    }

    // MARK: - Lifecycle

    /// Called per frame/second to update all calculations
    /// Returns true if state changed
    func tick(depth: Double, gasMix: GasMix = .air,
              waterTemp: Double = 15.0) -> Bool {
        let now = Date()
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
        // Updating here would make all prevDepth comparisons in determineState() trivially false

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

            while remainingTime > 0.001 {
                let chunk = min(chunkSize, remainingTime)
                buhlmann.update(depth: depth, gasMix: gasMix, deltaT: chunk)
                remainingTime -= chunk
            }
        }

        // Calculate real-time values
        if depth >= HARD_DEPTH_LIMIT {
            // ⚠️ CRITICAL: 40m hard limit enforcement (Requirement #5)
            alerts.exceeds40m = true
            ndlSeconds = 0  // Force NDL to 0, show "---"
            ceilingDepth = 0.0
        } else {
            alerts.exceeds40m = false
            ndlSeconds = buhlmann.ndlSeconds(at: depth, gasMix: gasMix)
            ceilingDepth = buhlmann.ceiling(at: depth)
        }

        po2 = calculatePO2(depth: depth, gasMix: gasMix)
        gf = calculateGF(depth: depth)
        // CNS 在 determineState() 之後計算，確保使用最新狀態判斷水面衰減 vs 水下累積

        // ⚠️ Ascent rate validation (Requirement #6 + audio warning)
        updateAscentWarnings()

        // ⚠️ NDL warnings
        updateNDLWarnings()

        // Update max depth
        if depth > maxDepth {
            maxDepth = depth
        }

        let prevState = state

        // State machine transitions
        determineState(depth: depth)

        // ✅ FIXED Audit: prevDepth 必須在 determineState() 之後才更新
        // 若在 tick() 開頭更新，determineState 裡所有 prevDepth 比較都會與 depth 相等（永遠 false）
        prevDepth = depth

        // ✅ FIXED Audit Fix #3: CNS 在狀態確定後更新，確保水面衰減 vs 水下累積邏輯正確
        updateCNS(po2: po2, deltaT: deltaT)

        // ✅ FIXED Issue #8 + Audit Fix #7: 精確的時間累積，水下所有狀態均計時
        // 僅 .surface / .postDive 不計入潛水時間
        let isUnderwater = state == .diving || state == .ascent
                        || state == .safetyStop || state == .decompression
        if isUnderwater {
            accumulatedDiveTime += deltaT
            diveTimeSeconds = Int(accumulatedDiveTime)
        }
        if state == .surface && postDiveDelaySec > 0 {
            accumulatedPostDiveDelay += deltaT
            postDiveDelaySec = max(0, 180 - Int(accumulatedPostDiveDelay))
            if postDiveDelaySec <= 0 {
                // Finalize logbook entry
                accumulatedPostDiveDelay = 0.0  // Reset accumulator
                diveTimeSeconds = 0
                maxDepth = 0.0
            }
        }
        if state == .surface {
            surfaceIntervalSeconds += Int(deltaT)
        }

        return state != prevState
    }

    // MARK: - State Determination

    private func determineState(depth: Double) {
        switch state {
        case .surface:
            // Check if descent starts
            if depth >= AlgorithmConstants.diveStartDepth {
                state = .diving
                diveTimeSeconds = 0
                maxDepth = 0.0
                postDiveDelaySec = 0
                buhlmann.firstCeilingBar = nil  // Reset GF baseline
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
                state = .safetyStop
                safetyStopActive = true
                safetyStopTimeRemaining = AlgorithmConstants.safetyStopDuration
            }

        case .ascent:
            // ✅ FIXED Audit Fix #4.1: 顯著再下潛（> 1.0m）才切回 .diving
            // 防止感測器雜訊（±0.3m 呼吸起伏）造成狀態機高頻震盪（Ping-Pong Effect）
            // ⚠️ 不重置 firstCeilingBar — GF 基準維持在最深點天花板壓力（Erik Baker 規範）
            if depth > (prevDepth + 1.0) && depth >= AlgorithmConstants.diveStartDepth {
                state = .diving
                return
            }
            // Check if safety stop required
            if ceilingDepth > 0 && depth <= ceilingDepth + 0.5 {
                state = .decompression
                alerts.decoViolation = true
            }
            // ✅ FIXED Audit Fix #5: 統一用 safetyStopTriggerDepth (6.0m)，與 .diving 分支一致
            // 原本錯誤地使用 safetyStopValidMax (5.0m)，造成觸發深度不一致
            else if depth <= AlgorithmConstants.safetyStopTriggerDepth
                && maxDepth >= AlgorithmConstants.safetyStopMinDiveDepth {
                state = .safetyStop
                safetyStopActive = true
                safetyStopTimeRemaining = AlgorithmConstants.safetyStopDuration
            }
            // Check if surface reached
            else if depth < AlgorithmConstants.diveEndDepth {
                state = .postDive
                postDiveDelaySec = 180  // 3-minute delay
                buhlmann.firstCeilingBar = nil
            }

        case .safetyStop:
            // Update safety stop timer
            safetyStopTimeRemaining = max(0, safetyStopTimeRemaining - 1)

            // Check if depth goes too deep during safety stop
            if depth > AlgorithmConstants.safetyStopHoldMax {
                state = .diving  // Restart dive
                safetyStopActive = false
            }
            // Check if safety stop complete and at surface
            else if safetyStopTimeRemaining <= 0 && depth < AlgorithmConstants.diveEndDepth {
                state = .postDive
                safetyStopActive = false
                postDiveDelaySec = 180
                buhlmann.firstCeilingBar = nil
            }

        case .decompression:
            // ✅ FIXED Audit Fix #4.2: 天花板解除後若仍在水中，回到 .ascent 繼續上升
            // 原本要求 ceilingDepth <= 0 && depth < 1.0m 才退出，導致 3m 解除 deco 後
            // UI 仍顯示「減壓中」直到浮出水面（狀態錯亂）
            if ceilingDepth <= 0 {
                alerts.decoViolation = false
                if depth < AlgorithmConstants.diveEndDepth {
                    state = .postDive
                    postDiveDelaySec = 180
                    buhlmann.firstCeilingBar = nil
                } else {
                    state = .ascent  // 天花板解除，恢復正常上升（保留 firstCeilingBar）
                }
            }

        case .postDive:
            // Wait for 3-minute delay
            if postDiveDelaySec <= 0 {
                state = .surface
                diveTimeSeconds = 0
                maxDepth = 0.0
            }
        }
    }

    // MARK: - Safety Validations

    private func updateAscentWarnings() {
        let ascentRateThreshold = AlgorithmConstants.maxAscentRateWarn

        // ✅ FIXED Audit Fix #6: 移除 abs()，只有真正上升（負值 = 變淺）才觸發警報
        // ascentRateMpm < 0 表示上升（深度減少），> 0 表示下潛（深度增加）
        // 使用 abs() 會讓快速下潛（+20 m/min）被誤判為上升過快，發出無謂蜂鳴
        if ascentRateMpm < -ascentRateThreshold {
            ascentWarnCounter += 1
            if ascentWarnCounter >= AlgorithmConstants.ascentWarnConsecutiveSec {
                alerts.ascentWarning = true
            }
            if ascentWarnCounter >= AlgorithmConstants.ascentSustainedWarnSec {
                alerts.ascentSustained = true
                // ⚠️ Requirement #6: Trigger AVFoundation audio warning
                playHighFrequencyAlert()
            }
        } else {
            ascentWarnCounter = 0
            alerts.ascentWarning = false
            alerts.ascentSustained = false
        }
    }

    private func updateNDLWarnings() {
        if alerts.exceeds40m {
            alerts.ndlWarning = false
            alerts.ndlCritical = false
            return
        }

        let ndlMinutes = ndlSeconds / 60

        if ndlSeconds <= AlgorithmConstants.ndlCriticalSeconds {
            alerts.ndlCritical = true
            alerts.ndlWarning = false
            playHighFrequencyAlert()
        } else if ndlMinutes <= AlgorithmConstants.ndlWarnMinutes {
            alerts.ndlWarning = true
            alerts.ndlCritical = false
        } else {
            alerts.ndlWarning = false
            alerts.ndlCritical = false
        }
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

    // MARK: - NOAA CNS Oxygen Clock
    //
    // ✅ FIXED Audit Fix #3: 實作 NOAA 標準時間積分（取代原本的瞬時比例公式）
    //
    // 原理：每秒的 CNS 累積量 = 100% ÷ 該 PO₂ 的 NOAA 允許暴露時間（秒）
    //   accumulatedCNS += (100.0 / limitSec) × deltaT
    //
    // 水面衰減：半衰期 90 分鐘（NOAA 標準）
    //   每秒衰減因子 = exp(-ln(2) / 5400 × deltaT)
    //
    // ⚠️ 積分式：PO₂ 降低時 CNS 不會瞬間歸零（過去累積的氧毒素仍存在）

    // NOAA Diving Manual Table 3-5（PO₂ bar → 允許暴露時間 min）
    // AI-generated (Claude)
    private static let noaaCNSTable: [(po2: Double, limitMin: Double)] = [
        (0.60, 720.0),
        (0.70, 570.0),
        (0.80, 450.0),
        (0.90, 360.0),
        (1.00, 300.0),
        (1.10, 240.0),
        (1.20, 210.0),
        (1.30, 180.0),
        (1.40, 150.0),
        (1.50, 120.0),
        (1.60,  45.0),
    ]

    /// 依 PO₂ 查 NOAA 表格並線性插值，回傳允許暴露時間（分鐘）
    /// PO₂ < 0.6 → 無 CNS 風險，回傳 0；>= 1.6 → 使用最嚴格限制 45 min
    private func cnsLimitMinutes(for po2: Double) -> Double {
        let table = DiveEngine.noaaCNSTable
        guard po2 >= table.first!.po2 else { return 0.0 }
        if po2 >= table.last!.po2 { return table.last!.limitMin }
        for i in 0..<(table.count - 1) {
            if po2 >= table[i].po2 && po2 < table[i + 1].po2 {
                let frac = (po2 - table[i].po2) / (table[i + 1].po2 - table[i].po2)
                return table[i].limitMin + frac * (table[i + 1].limitMin - table[i].limitMin)
            }
        }
        return table.last!.limitMin
    }

    private func updateCNS(po2: Double, deltaT: Double) {
        let isUnderwater = state == .diving || state == .ascent
                        || state == .safetyStop || state == .decompression
        if isUnderwater && po2 >= 0.6 {
            let limitSec = cnsLimitMinutes(for: po2) * 60.0
            if limitSec > 0 {
                accumulatedCNS += (100.0 / limitSec) * deltaT
            }
        } else if !isUnderwater {
            // 水面指數衰減：半衰期 90 分鐘（NOAA 標準）
            let halfTimeSec = 90.0 * 60.0
            let decayFactor = exp(-log(2.0) / halfTimeSec * deltaT)
            accumulatedCNS *= decayFactor
        }
        accumulatedCNS = max(0.0, min(200.0, accumulatedCNS))  // 200% 上限（保護）
        cns = accumulatedCNS
    }

    private func calculateGF(depth: Double) -> Double {
        guard let firstCeil = buhlmann.firstCeilingBar else {
            return buhlmann.gfHigh
        }
        let currentP = environment.absolutePressure(at: depth)
        let denom = environment.surfacePressureBar - firstCeil
        guard abs(denom) > 0.01 else { return buhlmann.gfHigh }
        return max(buhlmann.gfLow, min(buhlmann.gfHigh,
            buhlmann.gfLow + (buhlmann.gfHigh - buhlmann.gfLow) *
            (currentP - firstCeil) / denom))
    }

    // MARK: - Alerts (Requirement #6)

    private func playHighFrequencyAlert() {
        // TODO: Integrate AVFoundation for audio warning
        // Must be implemented in SensorService
    }

    // MARK: - Reset

    func reset() {
        state = .surface
        depth = 0.0
        maxDepth = 0.0
        diveTimeSeconds = 0
        ascentRateMpm = 0.0
        ndlSeconds = 0
        ceilingDepth = 0.0
        alerts = AlertState()
        safetyStopActive = false
        safetyStopTimeRemaining = 0
        postDiveDelaySec = 0
        // ✅ FIXED Issue #8: 重置時間累積器
        accumulatedDiveTime = 0.0
        accumulatedPostDiveDelay = 0.0
        accumulatedCNS = 0.0  // ✅ FIXED Audit Fix #3: 重置 CNS 積分
        buhlmann.reset()
        buhlmann.updateSurface(deltaT: 1.0)
    }
}
