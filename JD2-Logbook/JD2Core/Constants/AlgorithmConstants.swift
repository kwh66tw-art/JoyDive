// AlgorithmConstants.swift — JoyDiveCore/Constants/AlgorithmConstants.swift
// v14 FINAL 🔒（v13升級：水面間隔改為3分鐘、加入Safety Stop Hold區間、EMA動態係數）

import Foundation

enum AlgorithmConstants {

    // === 潛水判斷閾值 ===
    static let diveStartDepth: Double       = 1.2
    static let diveEndDepth: Double         = 1.0   // 統一為 1.0m 以對齊 UI 倒數
    static let diveStartConfirmSec: Int     = 3
    static let diveEndConfirmSec: Int       = 180   // 3分鐘（取代舊版的600s）

    // === Safety Stop ===
    static let safetyStopTriggerDepth: Double  = 6.0
    static let safetyStopValidMin: Double      = 3.0
    static let safetyStopValidMax: Double      = 5.0   // 配合 UI 嚴格藍圖
    static let safetyStopHoldMax: Double       = 7.0   // 5.1~7.0m 為發黃暫停區
    static let safetyStopResetDepth: Double    = 10.0
    static let safetyStopMinDiveDepth: Double  = 10.0
    static let safetyStopDuration: Int         = 180

    // === 上升速率（ATMOS 手冊標準）===
    static let maxAscentRateWarn: Double         = 10.0    // m/min，單一閾值
    static let ascentWarnConsecutiveSec: Int     = 5       // 連續 5s 才觸發 Warning
    static let ascentSustainedWarnSec: Int       = 10      // 持續 10s 升級 Sustained

    // === NDL 警報 ===
    static let ndlWarnMinutes: Int       = 3
    static let ndlCriticalSeconds: Int   = 60

    // === No-fly（DAN 標準）===
    static let noFlyMinHoursSingle: Int          = 12
    static let noFlyMinHoursMulti: Int           = 18
    static let noFlyDecoViolationHours: Int      = 48
    static let noFlyShowThresholdMin: Int        = 75

    // === 氣體常數 ===
    // ⚠️ DO NOT UNIFY — 兩個常數職責不同，不得合併為同一個值：
    //   fO2Air  → PO₂/CNS/MOD 計算，對齊 GasMix.air.fO2 = 0.21
    //   fN2Air  → initialTissuePN2 計算，Bühlmann 原著基準 0.7902
    static let fO2Air: Double = 0.21
    static let fN2Air: Double = 0.7902
    static let pWvp: Double   = 0.0627   // bar，37°C 體溫恆定

    // === 感測器與計算保護 ===
    static let sensorBaseAlpha: Double        = 0.2
    static let sensorAlphaDynamicK: Double    = 0.5   // 用於計算 Dynamic Alpha EMA
    static let sensorSpikeThreshold: Double   = 3.0   // m，跳變閾值
    static let depthStableThreshold: Double   = 0.1   // m，低於此值 pRate = 0
    static let pRateClampMax: Double          = 3.0   // bar/min（≈ 30 m/min 極端上限）

    // === Timer Recovery（Time-Chunking + 熔斷機制）===
    // ⚠️ 這兩個常數共同定義 DiveEngine.tick() 的時間補償策略：
    //   ① rawDeltaT > maxCompensateTotalSec → 熔斷，不補算，hasDataGap = true
    //   ② rawDeltaT ≤ maxCompensateTotalSec → while 迴圈，每步 tickChunkSizeSec
    //      確保高壓曝露時間 1 秒都不漏失（避免 NDL 過於樂觀）
    static let maxCompensateTotalSec: Double  = 120.0  // 超過此值 → 熔斷
    static let tickChunkSizeSec: Double       = 10.0   // 每次補算的步長（秒）

    // === TTS / 同步 / 電量 ===
    static let ttsAscentRateMpm: Double       = 10.0   // m/min
    static let flushIntervalSeconds: Int      = 30
    static let supabaseSampleIntervalSec: Int = 5
    static let batteryWarnPercent: Int        = 25
    static let batteryEmergencyPercent: Int   = 15
}
