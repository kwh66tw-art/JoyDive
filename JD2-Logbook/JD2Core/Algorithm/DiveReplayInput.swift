// DiveReplayInput.swift — JD2Core/Algorithm/
// DiveLog（SwiftData 模型）→ DiveKit `DiveReplayEngine.DiveInput` 的一次性映射。
//
// 由來：2026-08-22 重放引擎收斂進 DiveKit（原本 Logbook / ultra 各有一份獨立
// 複製，稽核模式2）。本 repo 的 `JD2Core/Algorithm/DiveReplayEngine.swift` 已刪除，
// 所有重放一律呼叫 `DiveKit.DiveReplayEngine`。規格見
// `_JD2-family/decisions/2026-08-22_重放連續潛水殘氮與前置判斷-設計.md`。
//
// 本檔是 App 層唯一負責「把 Logbook 自己的 model 攤平成 Kit 中性輸入」的地方
// ——Kit 內不出現任何 App 型別（家族鐵律 4），映射責任在這一側。

import Foundation
import SwiftData
import DiveKit

extension DiveLog {

    /// SwiftData 儲存的環境欄位 → DiveKit `DiveEnvironment`。
    ///
    /// 直接取用紀錄自身的 `surfacePressureBar` / `metersPerBar`（海水預設 1.0 / 10.0
    /// 恰等於 `DiveEnvironment.seaLevel`），不做 environmentType 字串分支——分支會讓
    /// 高海拔紀錄的實測氣壓被丟掉。⚠️ 一條殘氮鏈只能在單一環境下模擬（`Buhlmann`
    /// 一改 environment 就 `reset()`），環境不同的前導潛水由 Kit 判為
    /// `Anomaly.inconsistentEnvironment`，不會靜默近似。
    var replayEnvironment: DiveEnvironment {
        DiveEnvironment(
            surfacePressureBar: surfacePressureBar,
            waterVaporPressureBar: DiveEnvironment.seaLevel.waterVaporPressureBar,
            metersPerBar: metersPerBar
        )
    }

    /// 解碼氣體配置。**⚠️ R-058 修復前**這裡解不出來時直接退回 `.air`——`DiveInput.gasMix`
    /// 是 non-optional，重放引擎拿到的就是「確定是空氣」，會用空氣去算一支可能是
    /// trimix 的潛水且沒有任何但書。修復後：仍然要回傳一個具體值（型別要求），但真正的
    /// 「是否可信」訊號改由 `replayGasMixConfidence` 攜帶，`replayInput` 一併帶給
    /// DiveKit，讓 precheck（R-008 同一機制，`GasMixConfidence.unknown` →
    /// `Anomaly.unknownGasMix`）保守拒算，不再靜默算出一堆看似正常的數字。
    var replayGasMix: GasMix {
        decodedGasMix ?? .air
    }

    /// R-058／R-008：`replayGasMix` 這個具體值是否真的可信。
    var replayGasMixConfidence: DiveReplayEngine.GasMixConfidence {
        decodedGasMix != nil ? .confirmed : .unknown
    }

    /// 攤平成 Kit 的中性輸入。
    ///
    /// ⚠️ `recordedSeriesIndex` 恆為 nil：**Logbook 沒有 `diveNumberInSeries` 欄位**
    /// （ultra / immersion 由 `SurfaceStatus.divesInSeries` 在潛水當下寫入，Logbook
    /// 的資料來源是事後匯入，沒有這個裝置事實）。Kit 遇到 nil 會跳過 P4（不是判為
    /// 異常），這是三個 App 之間真實的偵測強度落差，**不得假造一個值來填**。
    ///
    /// `maxDepthMeters` 一定要帶：它是保守上界截斷的方形剖面估算依據，正是讓
    /// 「幾天前那筆手動輸入、沒有剖面樣本的紀錄」不會誤觸 P6 把整個組織艙顯示
    /// 關掉的關鍵（設計文件第六之二節）。真正的重放仍以 `profileSamples` 為準。
    ///
    /// `isBreathHold` 由 `diveMode`（自由潛水／浮潛）決定：Bühlmann 假設潛水者在深度
    /// 持續呼吸環境氣體，閉氣潛水只有下水前那一口氣，算進殘氮鏈會產生物理上錯誤的
    /// 高估（設計文件第六之三節）。Kit 會把閉氣的前導潛水濾出鏈外、目標潛水本身為
    /// 閉氣則回報 `Anomaly.breathHoldTarget`。
    /// ⚠️ **已知限制**：匯入路徑帶不進 dive mode（DiveImportKit `ParsedDiveLog` 沒有
    /// 此欄位，需改 Kit，不在本 repo 範圍），匯入紀錄一律是 `.scuba`，見
    /// `DiveLog.diveMode` 說明與 `V1_2_BACKLOG.md`。
    var replayInput: DiveReplayEngine.DiveInput {
        DiveReplayEngine.DiveInput(
            startedAt: dateTime,
            durationSeconds: Double(diveTimeSeconds),
            profileSamples: profileSamples.map {
                DiveKit.DiveProfileSample(timeSeconds: $0.timeSeconds,
                                          depthMeters: $0.depthMeters,
                                          waterTemp: $0.waterTemp)
            },
            maxDepthMeters: maxDepth,
            gasMix: replayGasMix,
            environment: replayEnvironment,
            recordedSeriesIndex: nil,
            isBreathHold: diveModeValue.isBreathHold,
            gasMixConfidence: replayGasMixConfidence
        )
    }
}

// MARK: - 前導潛水查詢

enum DiveReplayChainQuery {

    /// 目標潛水之前、`AlgorithmConstants.replayChainMaxLookbackHours`（96h）內的紀錄。
    ///
    /// 只負責給候選集合——真正的窗口過濾、排序與保守上界截斷都由
    /// `DiveReplayEngine.replayChain` 自己做（96h 是殘氮物理上界，**不是** 12h
    /// 系列判定窗口，兩者概念不同、不得共用同一個常數）。
    @MainActor
    static func precedingDives(of target: DiveLog, in context: ModelContext) -> [DiveLog] {
        let lookback = Double(AlgorithmConstants.replayChainMaxLookbackHours) * 3600
        let windowStart = target.dateTime.addingTimeInterval(-lookback)
        let targetStart = target.dateTime
        let targetID = target.persistentModelID

        var descriptor = FetchDescriptor<DiveLog>(
            predicate: #Predicate { $0.dateTime >= windowStart && $0.dateTime < targetStart },
            sortBy: [SortDescriptor(\.dateTime, order: .forward)]
        )
        descriptor.fetchLimit = 64   // 96h 內不可能有更多真實潛水；防呆上界
        let fetched = (try? context.fetch(descriptor)) ?? []
        return fetched.filter { $0.persistentModelID != targetID }
    }
}
