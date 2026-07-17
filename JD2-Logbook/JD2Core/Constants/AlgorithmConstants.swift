// AlgorithmConstants.swift — DiveKit/Constants
// 基底：JD2Core v14 FINAL（v13升級：水面間隔改為3分鐘、加入Safety Stop Hold區間、EMA動態係數）
// JD2-Ultra: 新增 Deepstop / 演算法鎖定 / OLF / PLAN / Free 模式常數

import Foundation

public enum AlgorithmConstants {

    // === 潛水判斷閾值 ===
    public static let diveStartDepth: Double       = 1.2
    public static let diveEndDepth: Double         = 1.0   // 統一為 1.0m 以對齊 UI 倒數
    public static let diveStartConfirmSec: Int     = 3
    public static let diveEndConfirmSec: Int       = 180   // 3分鐘（取代舊版的600s）

    // === Safety Stop ===
    public static let safetyStopTriggerDepth: Double  = 6.0
    public static let safetyStopValidMin: Double      = 3.0
    public static let safetyStopValidMax: Double      = 5.0   // 配合 UI 嚴格藍圖
    public static let safetyStopHoldMax: Double       = 7.0   // 5.1~7.0m 為發黃暫停區
    public static let safetyStopResetDepth: Double    = 10.0
    public static let safetyStopMinDiveDepth: Double  = 10.0
    public static let safetyStopDuration: Int         = 180

    // === 上升速率（潛水電腦手冊標準）===
    public static let maxAscentRateWarn: Double         = 10.0    // m/min，單一閾值
    public static let ascentWarnConsecutiveSec: Int     = 5       // 連續 5s 才觸發 Warning
    public static let ascentSustainedWarnSec: Int       = 10      // 持續 10s 升級 Sustained

    // JD2-Ultra: 上升超速 → 強制安全停留（業界規格：超速 5s 以上，依違規程度加時）
    public static let mandatoryStopBaseSec: Int          = 60     // 每次超速事件的基礎加時
    public static let mandatoryStopMaxSec: Int           = 300    // 強制停留加時上限

    // === NDL 警報 ===
    public static let ndlWarnMinutes: Int       = 3
    public static let ndlCriticalSeconds: Int   = 60

    // === No-fly（DAN 標準）===
    public static let noFlyMinHoursSingle: Int          = 12
    public static let noFlyMinHoursMulti: Int           = 18
    public static let noFlyDecoViolationHours: Int      = 48
    public static let noFlyShowThresholdMin: Int        = 75

    // JD2-Ultra: 連續潛水系列判定（業界規格：no-fly 未結束前的潛水屬同一系列）
    public static let repetitiveDiveWindowHours: Int    = 12

    // === JD2-Ultra: Deepstop（業界規格）===
    public static let deepstopActivationDepth: Double   = 20.0   // 超過 20m 啟用
    public static let deepstopDurationSec: Int          = 120    // 停留時間（業界標準 以秒顯示）
    public static let deepstopWindowMeters: Double      = 1.5    // 停留深度容許範圍 ±
    public static let deepstopMinStopDepth: Double      = 8.0    // 深停最淺深度（再淺併入安全停留）

    // === JD2-Ultra: 演算法鎖定 Er（業界規格）===
    public static let decoViolationGraceSec: Int        = 180    // 超越 ceiling 3 分鐘寬限
    public static let algorithmLockHours: Int           = 48     // 鎖定 48 小時

    // === JD2-Ultra: 氧暴露（業界規格）===
    public static let olfWarnPercent: Double            = 80.0
    public static let olfCriticalPercent: Double        = 100.0
    public static let otuDailyLimit: Double             = 300.0  // OTU 100% 基準（單日）
    public static let cnsSurfaceHalfTimeMin: Double     = 90.0   // NOAA 水面衰減半衰期

    // === JD2-Ultra: PLAN 模式（業界規格）===
    public static let planMinDepth: Double              = 9.0
    public static let planMaxDepth: Double              = 45.0
    public static let planDepthStep: Double             = 3.0

    // === JD2-Ultra: Free 模式（業界規格）===
    public static let freeDiveStartDepth: Double        = 1.2
    public static let freeDiveEndDepth: Double          = 0.9
    public static let freeDepthNotificationCount: Int   = 5
    public static let apneaMaxIntervals: Int            = 20
    public static let apneaVentilationMinSec: Int       = 5
    public static let apneaVentilationMaxSec: Int       = 20 * 60
    public static let apneaCountdownOverrunSec: Int     = 30     // 倒數可超時 -0:30

    // === JD2-Ultra: 取樣率（業界規格）===
    public static let scubaSampleRates: [Int]           = [10, 20, 30, 60]
    public static let scubaSampleRateDefault: Int       = 20
    public static let freeSampleRates: [Int]            = [1, 2, 5]
    public static let freeSampleRateDefault: Int        = 2

    // === 氣體常數 ===
    // ⚠️ DO NOT UNIFY — 兩個常數職責不同，不得合併為同一個值：
    //   fO2Air  → PO₂/CNS/MOD 計算，對齊 GasMix.air.fO2 = 0.21
    //   fN2Air  → initialTissuePN2 計算，Bühlmann 原著基準 0.7902
    public static let fO2Air: Double = 0.21
    public static let fN2Air: Double = 0.7902
    public static let pWvp: Double   = 0.0627   // bar，37°C 體溫恆定

    // === 感測器與計算保護 ===
    public static let sensorBaseAlpha: Double        = 0.2
    public static let sensorAlphaDynamicK: Double    = 0.5   // 用於計算 Dynamic Alpha EMA
    public static let sensorSpikeThreshold: Double   = 3.0   // m，跳變閾值
    public static let depthStableThreshold: Double   = 0.1   // m，低於此值 pRate = 0
    public static let pRateClampMax: Double          = 3.0   // bar/min（≈ 30 m/min 極端上限）

    // === Timer Recovery（Time-Chunking + 熔斷機制）===
    // ⚠️ 這兩個常數共同定義 DiveEngine.tick() 的時間補償策略：
    //   ① rawDeltaT > maxCompensateTotalSec → 熔斷，不補算，hasDataGap = true
    //   ② rawDeltaT ≤ maxCompensateTotalSec → while 迴圈，每步 tickChunkSizeSec
    //      確保高壓曝露時間 1 秒都不漏失（避免 NDL 過於樂觀）
    public static let maxCompensateTotalSec: Double  = 120.0  // 超過此值 → 熔斷
    public static let tickChunkSizeSec: Double       = 10.0   // 每次補算的步長（秒）

    // === TTS / 電量 ===
    public static let ttsAscentRateMpm: Double       = 10.0   // m/min
    public static let ttsSimulationStepSec: Double   = 6.0    // JD2-Ultra: ASC TIME 模擬步長
    public static let ttsMaxMinutes: Int             = 999    // 業界規格：ascent time 0–999
    public static let batteryWarnPercent: Int        = 25
    public static let batteryEmergencyPercent: Int   = 15
}
