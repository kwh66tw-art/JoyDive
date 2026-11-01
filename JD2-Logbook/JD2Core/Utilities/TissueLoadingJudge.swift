// TissueLoadingJudge.swift — JD2Core/Utilities
// v1.4 A3（PM 2026-11-01 同意做法）：列表篩選「組織負荷」的逐步判定。
//
// 判定本身只有一份（`TissueLoadingSupport.isSupported`）；這裡只管**執行順序、分段與快取**：
// - 由新到舊（列表新的在上 ⇒ 第一屏先出來），每 `chunkSize` 筆讓出主執行緒（Kit `precheck` 為 `@MainActor`，
//   不能移到背景執行緒——DiveKit 放寬隔離列為家族待辦，見決策檔 §五）。
// - 每筆只在算出正確結果後才進 `results`；**不先顯示近似再修正**（決策檔 §五：不採「先取 12 筆前導」）。
// - 快取鍵＝目標的 `replayInputsFingerprint`＋其前導候選（同一挑法）的 ID 與指紋。新增、刪除、改時間會改變
//   候選集合，編輯會改變指紋 ⇒ 鍵變了才重算；等價於「改了 X ⇒ 重算 X 與其後 96h 內的紀錄」（總指揮 11/01），
//   但不另寫窗口邏輯。剖面樣本不在指紋內：匯入後不會再改（見 `replayInputsFingerprint` 說明）。
// 量測：2,000 筆 × 300 樣本全部判定約 1.8 s（Debug，`TissueLoadingSupportPerformanceTests`）。

import Foundation
import SwiftData
import DiveKit

@MainActor
@Observable
final class TissueLoadingJudge {
    /// 每段判定筆數。單筆約 0.9 ms（2,000 筆實測）⇒ 一段約 15 ms，接近 60 Hz 一幀（本專案決定）。
    static let chunkSize = 16

    /// 已算出的結果（true＝有組織負荷）。不在這裡的紀錄＝還沒算出來。
    private(set) var results: [PersistentIdentifier: Bool] = [:]
    private(set) var isComputing = false

    @ObservationIgnored private var keys: [PersistentIdentifier: Int] = [:]
    @ObservationIgnored private var inputs: [PersistentIdentifier: (fingerprint: Int, input: DiveReplayEngine.DiveInput)] = [:]

    /// - Parameter sortedAscending: 全部紀錄，依 `dateTime` 遞增。呼叫端以 `.task(id:)` 驅動：資料變了就重新呼叫，舊的被取消。
    func update(sortedAscending dives: [DiveLog]) async {
        isComputing = true
        defer { isComputing = false }

        let ids = dives.map(\.persistentModelID)
        let alive = Set(ids)
        results = results.filter { alive.contains($0.key) }
        keys = keys.filter { alive.contains($0.key) }
        inputs = inputs.filter { alive.contains($0.key) }
        let fingerprints = dives.map(\.replayInputsFingerprint)

        var judgedInChunk = 0
        for index in dives.indices.reversed() {
            if Task.isCancelled { return }
            let candidates = DiveReplayChainQuery.precedingIndices(of: dives[index], inAscending: dives)
            var hasher = Hasher()
            hasher.combine(fingerprints[index])
            for candidate in candidates {
                hasher.combine(ids[candidate])
                hasher.combine(fingerprints[candidate])
            }
            let key = hasher.finalize()
            if keys[ids[index]] == key, results[ids[index]] != nil { continue }

            let supported = TissueLoadingSupport.isSupported(
                target: input(dives[index], fingerprint: fingerprints[index]),
                preceding: candidates.map { input(dives[$0], fingerprint: fingerprints[$0]) })
            results[ids[index]] = supported
            keys[ids[index]] = key

            judgedInChunk += 1
            if judgedInChunk == Self.chunkSize {
                judgedInChunk = 0
                // 計時器回到 run loop，讓畫面在兩段之間更新與回應觸控。
                try? await Task.sleep(for: .milliseconds(1))
            }
        }
    }

    /// `replayInput` 每筆只映射一次（含剖面 JSON 解碼，約佔逐筆成本一半）；指紋變了才重映射。
    private func input(_ dive: DiveLog, fingerprint: Int) -> DiveReplayEngine.DiveInput {
        let id = dive.persistentModelID
        if let cached = inputs[id], cached.fingerprint == fingerprint { return cached.input }
        let input = dive.replayInput
        inputs[id] = (fingerprint, input)
        return input
    }
}
