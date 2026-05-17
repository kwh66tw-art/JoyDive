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

        // Calculate ascent rate (m/min)
        let depthDelta = depth - prevDepth
        if deltaT > 0 {
            ascentRateMpm = (depthDelta / deltaT) * 60.0
        }
        prevDepth = depth

        // Determine data gap level
        determinateDataGapLevel(deltaT: deltaT)

        // ✅ FIXED Issue #5: 避免 NDL 被覆蓋，邏輯整理
        // Update Buhlmann algorithm (但 > 40m 時不更新)
        if !hasDataGap && depth < HARD_DEPTH_LIMIT {
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
        cns = calculateCNS(po2: po2)  // Simplified
        gf = calculateGF(depth: depth)

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

        // ✅ FIXED Issue #8: 精確的時間累積，避免四捨五入誤差
        // Update timers with double precision accumulation
        if state == .diving {
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
                buhlmann.firstCeilingBar = buhlmann.rawCeiling()  // Lock GF baseline
            }
            // Check if safety stop depth reached
            else if depth <= AlgorithmConstants.safetyStopTriggerDepth
                && maxDepth >= AlgorithmConstants.safetyStopMinDiveDepth {
                state = .safetyStop
                safetyStopActive = true
                safetyStopTimeRemaining = AlgorithmConstants.safetyStopDuration
            }

        case .ascent:
            // Check if safety stop required
            if ceilingDepth > 0 && depth <= ceilingDepth + 0.5 {
                state = .decompression
                alerts.decoViolation = true
            }
            // Check if safety stop triggered
            else if depth <= AlgorithmConstants.safetyStopValidMax
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
            // Wait for ceiling to clear
            if ceilingDepth <= 0 && depth < AlgorithmConstants.diveEndDepth {
                state = .postDive
                alerts.decoViolation = false
                postDiveDelaySec = 180
                buhlmann.firstCeilingBar = nil
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

        if abs(ascentRateMpm) > ascentRateThreshold {
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

    private func calculateCNS(po2: Double) -> Double {
        // Simplified CNS calculation (0-100%)
        // Full implementation tracks minute ventilation
        let po2Threshold = 1.6
        if po2 < 0.5 {
            return 0.0
        }
        // Proportional increase above threshold
        return min(100.0, (po2 - 0.5) / po2Threshold * 50.0)
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
        buhlmann.reset()
        buhlmann.updateSurface(deltaT: 1.0)
    }
}
