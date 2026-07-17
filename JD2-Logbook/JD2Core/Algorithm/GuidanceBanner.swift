// GuidanceBanner.swift — DiveKit/Algorithm
// 0.2.0(M9)：跨頁安全引導狀態階梯（UI 容器的 overlay 資料來源）
//
// 設計動機（UI_REFACTOR_ASSESSMENT RUI-2）：
//   水下多頁化後，安全引導必須與頁面解耦——潛水員停在羅盤頁時，
//   Er/違規/停留倒數仍須恆顯。本型別把原 DiveDashboardView.centerStatus
//   的優先級階梯抽成純函式，DiveKit 單元測試直接覆蓋。
//
// 優先級（高→低）：Er 鎖定 > 超越 ceiling > 減壓引導 > 深停 > 安全停留 > NDL
// A5（停留三態）：readyToStop / counting / done / missed 併入階梯。

import Foundation

public enum GuidanceBanner: Equatable, Sendable {

    public enum SafetyStopPhase: Equatable, Sendable {
        case ready                 // 接近停留區（上升中、無減壓義務、夠深的潛水）
        case counting(remaining: Int)
        case done                  // 倒數完成、仍在水中
        case missed                // 未完成即離開（本次潛水內）
    }

    case algorithmLocked(remainingHours: Int)
    case ceilingViolated(ceilingMeters: Double)
    case decoGuidance(DecoStatus)
    case deepstop(depthMeters: Double, remainingSec: Int)
    case safetyStop(phase: SafetyStopPhase, mandatory: Bool)
    case ndl(seconds: Int, warning: Bool, critical: Bool, exceeds40m: Bool)
    /// 水面/無資料（容器不顯示 overlay）
    case none

    // MARK: - 階梯判定（純函式；DiveEngine 擴充屬性包裝於下）

    public static func compute(state: DiveState,
                               alerts: AlertState,
                               deco: DecoStatus,
                               ceilingDepth: Double,
                               ndlSeconds: Int,
                               deepstopDepth: Double,
                               deepstopRemaining: Int,
                               safetyStopRemaining: Int,
                               safetyStopMandatory: Bool,
                               depth: Double,
                               maxDepth: Double,
                               lockRemainingHours: Int) -> GuidanceBanner {
        let underwater = state != .surface && state != .postDive
        guard underwater else { return .none }

        if alerts.algorithmLocked {
            return .algorithmLocked(remainingHours: max(lockRemainingHours, 48))
        }
        if alerts.decoViolation {
            return .ceilingViolated(ceilingMeters: ceilingDepth)
        }
        if state == .decompression || ceilingDepth > 0 {
            return .decoGuidance(deco)
        }
        if state == .deepstop {
            return .deepstop(depthMeters: deepstopDepth, remainingSec: deepstopRemaining)
        }
        if state == .safetyStop {
            let phase: SafetyStopPhase = safetyStopRemaining > 0
                ? .counting(remaining: safetyStopRemaining)
                : .done
            return .safetyStop(phase: phase, mandatory: safetyStopMandatory)
        }
        // A5：missed——停留違規後仍在水中（再下潛情境）
        if alerts.safetyStopViolated {
            return .safetyStop(phase: .missed, mandatory: true)
        }
        // A5：ready——上升中接近停留區（夠深的潛水、無減壓義務）
        if state == .ascent
            && maxDepth >= AlgorithmConstants.safetyStopMinDiveDepth
            && depth > AlgorithmConstants.safetyStopTriggerDepth
            && depth <= AlgorithmConstants.safetyStopResetDepth {
            return .safetyStop(phase: .ready, mandatory: false)
        }
        return .ndl(seconds: ndlSeconds,
                    warning: alerts.ndlWarning,
                    critical: alerts.ndlCritical,
                    exceeds40m: alerts.exceeds40m)
    }
}

@MainActor
extension DiveEngine {
    /// 目前的跨頁引導狀態（UI 容器 overlay 直讀）
    /// 0.2.0(A7)：Gauge 模式不提供任何演算引導（bottom timer 語意）
    public var guidanceBanner: GuidanceBanner {
        if settings.mode == .gauge { return .none }
        return GuidanceBanner.compute(
            state: state,
            alerts: alerts,
            deco: deco,
            ceilingDepth: ceilingDepth,
            ndlSeconds: ndlSeconds,
            deepstopDepth: deepstopDepth,
            deepstopRemaining: deepstopTimeRemaining,
            safetyStopRemaining: safetyStopTimeRemaining,
            safetyStopMandatory: safetyStopMandatory,
            depth: depth,
            maxDepth: maxDepth,
            lockRemainingHours: surfaceStatus.algorithmLockRemainingSeconds() / 3600)
    }
}
