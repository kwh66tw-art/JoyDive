// FreeDive.swift — DiveKit/Algorithm
// JD2-Ultra 新增：Free 模式（業界規格）與 Apnea 間歇計時器（業界規格）
//
// Free 模式不做減壓計算（業界同樣行為），但：
//   - 自由潛水期間組織仍會吸氮 → 上層持續以 Buhlmann updateSurface/update 追蹤
//     （業界慣例：自由潛水計入潛水歷史；水肺與自潛混用時殘氮由同一組織模型承擔）
//   - 深度通知（5 組）、深度/時間警報、水面計時

import Foundation
import Observation

// MARK: - Free 模式即時引擎

@MainActor
@Observable
public final class FreeDiveEngine {

    public enum State: Equatable, Sendable {
        case surface
        case diving
    }

    public private(set) var state: State = .surface
    public private(set) var depth: Double = 0.0
    public private(set) var maxDepth: Double = 0.0
    public private(set) var diveTimeSeconds: Int = 0
    public private(set) var surfaceTimeSeconds: Int = 0
    /// 本次 session 的每趟紀錄（深度, 秒數）
    public private(set) var completedDives: [(maxDepth: Double, durationSec: Int)] = []

    /// 觸發的深度通知（低優先；同一趟每組只觸發一次）
    public var onDepthNotification: ((DepthNotification) -> Void)?
    /// 水面計時到達提醒（下一次潛水前的水面時間）
    public var onSurfaceTimerReached: (() -> Void)?
    /// 0.2.0(A9)：進入自由落體段（下降速率 ≥ 門檻持續 2 秒；每趟一次）
    public var onFreefallBegan: (() -> Void)?
    /// 0.2.0(A3)：垂直速度警報（isAscending：上升 true / 下降 false；每趟每向一次）
    public var onSpeedAlarm: ((_ isAscending: Bool) -> Void)?

    /// 目前垂直速率（m/min；上升為負——與 DiveEngine 慣例一致）
    public private(set) var verticalRateMpm: Double = 0
    /// A9：自由落體狀態（UI 顯示提示）
    public private(set) var isFreefalling = false

    public var settings = DiveSettings()

    // A9/A3 內部狀態
    private var freefallAccumSec: Double = 0
    private var freefallFiredThisDive = false
    private var ascentAlarmFired = false
    private var descentAlarmFired = false
    private var prevDepth: Double = 0

    /// A9：自由落體判定門檻（下降 ≥ 45 m/min ≈ 0.75 m/s，持續 2 秒）
    public static let freefallRateMpm: Double = 45
    public static let freefallSustainSec: Double = 2

    private var accumulatedDiveTime: Double = 0.0
    private var accumulatedSurfaceTime: Double = 0.0
    private var firedNotificationIDs: Set<Int> = []
    private var surfaceTimerFired: Bool = false
    private var lastUpdateTime: Date?

    public init() {}

    /// 每 tick 呼叫（Free 模式取樣率 1/2/5s）
    /// 業界規格：1.2m 開始、淺於 0.9m 結束
    @discardableResult
    public func tick(depth: Double, now: Date = Date()) -> Bool {
        let deltaT = max(0.001, now.timeIntervalSince(lastUpdateTime ?? now))
        lastUpdateTime = now
        let prevState = state

        // 0.2.0(A9/A3)：垂直速率（上升為負）
        verticalRateMpm = ((depth - prevDepth) / deltaT) * 60.0
        prevDepth = depth
        self.depth = depth
        if state == .diving {
            updateFreefallAndSpeedAlarms(deltaT: deltaT)
        }

        switch state {
        case .surface:
            accumulatedSurfaceTime += deltaT
            surfaceTimeSeconds = Int(accumulatedSurfaceTime)
            if let timer = settings.freeSurfaceTimerSec,
               surfaceTimeSeconds >= timer, !surfaceTimerFired {
                surfaceTimerFired = true
                onSurfaceTimerReached?()
            }
            if depth >= AlgorithmConstants.freeDiveStartDepth {
                state = .diving
                accumulatedDiveTime = 0
                diveTimeSeconds = 0
                maxDepth = 0
                firedNotificationIDs.removeAll()
                // 0.2.0(A9/A3)：每趟重置
                freefallAccumSec = 0
                freefallFiredThisDive = false
                isFreefalling = false
                ascentAlarmFired = false
                descentAlarmFired = false
            }

        case .diving:
            accumulatedDiveTime += deltaT
            diveTimeSeconds = Int(accumulatedDiveTime)
            maxDepth = max(maxDepth, depth)

            // 深度通知（業界規格：到達設定深度，低優先警報）
            for note in settings.freeDepthNotifications
            where note.enabled && depth >= note.depthMeters && !firedNotificationIDs.contains(note.id) {
                firedNotificationIDs.insert(note.id)
                onDepthNotification?(note)
            }

            if depth < AlgorithmConstants.freeDiveEndDepth {
                completedDives.append((maxDepth: maxDepth, durationSec: diveTimeSeconds))
                state = .surface
                accumulatedSurfaceTime = 0
                surfaceTimeSeconds = 0
                surfaceTimerFired = false
                isFreefalling = false
            }
        }
        return state != prevState
    }

    // MARK: - 0.2.0(A9/A3)：自由落體偵測與垂直速度警報

    private func updateFreefallAndSpeedAlarms(deltaT: Double) {
        // A9：下降（正速率）≥ 門檻持續 2 秒 → freefall
        if verticalRateMpm >= Self.freefallRateMpm {
            freefallAccumSec += deltaT
            if freefallAccumSec >= Self.freefallSustainSec && !isFreefalling {
                isFreefalling = true
                if !freefallFiredThisDive {
                    freefallFiredThisDive = true
                    onFreefallBegan?()
                }
            }
        } else {
            freefallAccumSec = 0
            if verticalRateMpm < Self.freefallRateMpm * 0.6 {
                isFreefalling = false
            }
        }

        // A3：垂直速度警報（上升為負）
        if let limit = settings.freeAscentRateAlarmMpm,
           verticalRateMpm < -limit, !ascentAlarmFired {
            ascentAlarmFired = true
            onSpeedAlarm?(true)
        }
        if let limit = settings.freeDescentRateAlarmMpm,
           verticalRateMpm > limit, !descentAlarmFired {
            descentAlarmFired = true
            onSpeedAlarm?(false)
        }
    }

    public func reset() {
        state = .surface
        depth = 0
        maxDepth = 0
        diveTimeSeconds = 0
        surfaceTimeSeconds = 0
        completedDives.removeAll()
        accumulatedDiveTime = 0
        accumulatedSurfaceTime = 0
        firedNotificationIDs.removeAll()
        surfaceTimerFired = false
        lastUpdateTime = nil
        verticalRateMpm = 0
        isFreefalling = false
        freefallAccumSec = 0
        freefallFiredThisDive = false
        ascentAlarmFired = false
        descentAlarmFired = false
        prevDepth = 0
    }

    /// 審計 G10：新工作階段開始時清空上一段的趟次與計時，
    /// 防止 completedDives 無上限成長（記錄端對計數下降會自我校正基準）
    public func startNewSession() {
        reset()
    }
}

// MARK: - Apnea 間歇訓練計時器（業界規格）

/// 純狀態模型（無 Timer 依賴；UI 層以 TimelineView/Timer 驅動 tick）
public struct ApneaTimer: Equatable, Sendable {

    public enum Phase: Equatable, Sendable {
        case idle                       // 未開始
        case ventilation(remaining: Int)  // 換氣倒數（可至 -30s）
        case apnea(elapsed: Int)        // 閉氣中（不限長短，業界慣例：自行決定）
        case finished                   // 全部間隔完成
        case paused                     // 暫停
    }

    // 設定（業界規格）
    /// 起始換氣時間（秒）
    public var ventilationSec: Int = 60
    /// 每一間隔的換氣遞增（秒）
    public var incrementSec: Int = 30
    /// 間隔數（最多 20）
    public var repeats: Int = 5 {
        didSet { repeats = min(max(1, repeats), AlgorithmConstants.apneaMaxIntervals) }
    }

    public private(set) var phase: Phase = .idle
    public private(set) var currentInterval: Int = 0   // 1-based

    private var phaseAccumulator: Double = 0
    private var pausedPhase: Phase? = nil

    public init() {}

    /// 本間隔的換氣總長（業界慣例：vent + incr × (n−1)）
    public func ventilationDuration(forInterval n: Int) -> Int {
        let sec = ventilationSec + incrementSec * (n - 1)
        return min(max(sec, AlgorithmConstants.apneaVentilationMinSec),
                   AlgorithmConstants.apneaVentilationMaxSec)
    }

    // MARK: - 操作（對應 業界標準 按鍵流程）

    /// 開始第一個換氣間隔（業界慣例：SELECT 開始）
    public mutating func start() {
        guard case .idle = phase else { return }
        currentInterval = 1
        phaseAccumulator = 0
        phase = .ventilation(remaining: ventilationDuration(forInterval: 1))
    }

    /// 進入閉氣（換氣倒數中任何時間皆可，業界標準 步驟 2）
    public mutating func beginApnea() {
        guard case .ventilation = phase else { return }
        phaseAccumulator = 0
        phase = .apnea(elapsed: 0)
    }

    /// 結束閉氣 → 下一個換氣間隔（業界標準 步驟 3）
    public mutating func nextVentilation() {
        guard case .apnea = phase else { return }
        if currentInterval >= repeats {
            phase = .finished
        } else {
            currentInterval += 1
            phaseAccumulator = 0
            phase = .ventilation(remaining: ventilationDuration(forInterval: currentInterval))
        }
    }

    public mutating func pause() {
        guard phase != .idle, phase != .finished, phase != .paused else { return }
        pausedPhase = phase
        phase = .paused
    }

    public mutating func resume() {
        guard case .paused = phase, let saved = pausedPhase else { return }
        phase = saved
        pausedPhase = nil
    }

    public mutating func reset() {
        phase = .idle
        currentInterval = 0
        phaseAccumulator = 0
        pausedPhase = nil
    }

    /// 由 UI 計時器驅動。
    public mutating func tick(deltaT: Double) {
        switch phase {
        case .ventilation:
            phaseAccumulator += deltaT
            let duration = ventilationDuration(forInterval: currentInterval)
            let remaining = duration - Int(phaseAccumulator)
            // 業界慣例：倒數可超時至 -0:30，之後自動進入閉氣
            if remaining <= -AlgorithmConstants.apneaCountdownOverrunSec {
                beginApnea()
            } else {
                phase = .ventilation(remaining: remaining)
            }
        case .apnea:
            phaseAccumulator += deltaT
            phase = .apnea(elapsed: Int(phaseAccumulator))
        case .idle, .finished, .paused:
            break
        }
    }
}
