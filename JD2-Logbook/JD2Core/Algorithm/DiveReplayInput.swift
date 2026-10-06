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
    ///
    /// v1.3（PM 2026-10-05）：另讀匯入時的 `importExtras["gasMixConfidence"] == "unknown"`。
    /// DiveImportKit 七支解析器（v0.7.2 起含 Garmin FIT：多氣體／循環呼吸器／缺氣體）在來源
    /// 無法確定單一氣體時寫入此標記，但先前本 App 只看解碼失敗、**從未讀它**⇒ 這些潛水仍被
    /// 當成確定的空氣／高氧重放。標記只在匯入時寫入；使用者手動改氣體**不會**清掉它（保守）。
    ///
    /// Garmin FIT（PM 2026-10-05 裁示 A）：DiveImportKit v0.7.2 前讀錯訊息號，**所有** Garmin FIT
    /// 的氣體一律被寫成 "air"（技術潛水也是）。沒有 `garminGasVerifiedKey` 標記的 Garmin 紀錄
    /// ＝舊版匯入（含 v1.2 使用者資料、備份還原），一律視為不可信——不需要遷移，備份還原也涵蓋。
    var replayGasMixConfidence: DiveReplayEngine.GasMixConfidence {
        guard decodedGasMix != nil else { return .unknown }
        let extras = importExtras
        if extras["gasMixConfidence"] == "unknown" { return .unknown }
        if Self.garminFITSourceFormats.contains(sourceFormat.lowercased()),
           extras[Self.garminGasVerifiedKey] == nil { return .unknown }
        // PM 2026-10-06（同 Garmin A 案）：DiveImportKit v0.7.3 前，這幾種格式的循環呼吸器／多氣體／
        // 無氣體欄位紀錄都被當成確定的單一氣體。舊版匯入（無 `gasVerifiedKey`）一律視為不可信。
        // UDDF 依 PM 裁示維持原狀（不套用）。
        if Self.gasRuleV073SourceFormats.contains(sourceFormat.lowercased()),
           extras[Self.gasVerifiedKey] == nil { return .unknown }
        return .confirmed
    }

    /// 匯入時寫入的標記：這筆的氣體由 DiveImportKit v0.7.3 的判定規則解析（值＝Kit 版本）。
    static let gasVerifiedKey = "jd2GasVerified"
    /// v0.7.3 修正氣體判定的格式（`sourceFormat` 字串，經 Kit 原始碼與模擬器資料庫查證）。
    static let gasRuleV073SourceFormats: Set<String> = ["seabear", "divinglog", "shearwater", "csv", "csv-profile"]

    /// 日期是否為代填值（Subsurface 剖面 CSV 沒有日期，以匯入當下時間代填）。
    /// 使用者在編輯頁改過日期後記為 `"user"`，即恢復參與殘氮鏈。
    /// 舊版匯入沒有標記，但此格式本來就沒有日期 ⇒ 以格式判定。
    var hasUnknownDateTime: Bool {
        guard sourceFormat.lowercased() == "csv-profile" else { return false }
        return importExtras[Self.dateTimeConfidenceKey] != "user"
    }
    static let dateTimeConfidenceKey = "dateTimeConfidence"

    /// 匯入時寫入的標記：這筆 Garmin FIT 的氣體由修正後的 DiveImportKit 解析（值＝Kit 版本）。
    static let garminGasVerifiedKey = "jd2GarminGasVerified"
    /// `DiveLogDetailView.sourceFormatDisplayName` 中對應 "Garmin Descent" 的兩個字串
    static let garminFITSourceFormats: Set<String> = ["garmin", "garmin-fit"]

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
    /// `isBreathHold` 由 `diveMode`（自由潛水／浮潛）決定：`Buhlmann` 假設潛水者在深度
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
        // PM 2026-10-06 裁示 B：日期是代填值的紀錄（剖面 CSV）不參與殘氮鏈——它的時間不是潛水發生的時間。
        return fetched.filter { $0.persistentModelID != targetID && !$0.hasUnknownDateTime }
    }
}
