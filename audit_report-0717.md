# 專案程式碼首席稽核報告：JD2-Logbook

本報告針對專案中的核心算法模組（減壓演算法、組織分壓計算、單位轉換）與系統架構（MVVM 解耦、SwiftData 並行安全與資料庫管理）進行深度邏輯審查。本稽核完全基於程式碼靜態分析，不依賴任何外部文件，旨在確保系統的安全性、一致性與高可用性。

---

## 🚨 風險 (Risks)

以下為可能導致潛水安全隱患、物理模擬失真或程式崩潰的邏輯與並行錯誤，必須優先處理：

### 1. `DiveEngine.tick` 時間補償分塊 (Chunking) 更新中壓力變化率 `pRate` 歸零 Bug
* **檔案位置**：[DiveEngine.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Algorithm/DiveEngine.swift#L276-L287) 與 [Buhlmann.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Algorithm/Buhlmann.swift#L74-L109)
* **邏輯缺陷**：
  在 `DiveEngine.tick` 的時間補償機制中，當偵測到資料時間差較大（但未達 120s 熔斷值）時，會進入 while 迴圈分塊（以 `chunkSize = 10s` 為步長）呼叫 `buhlmann.update(depth: depth, gasMix: gasMix, deltaT: chunk)`。
  然而在 `buhlmann.update` 的實作末尾，會直接將 `prevDepth` 更新為當前的 `depth`：
  ```swift
  prevDepth = depth
  ```
  這導致在 while 迴圈的**第二個及後續的 chunk** 執行時，`prevDepth` 已經在第一個 chunk 被修改為與當前 `depth` 相同，使得 `depthDelta` 降為 `0`（低於穩定閾值 `depthStableThreshold`），壓力變化率 `pRate` 被判定為 `0.0`。
* **安全隱患**：
  這會導致補算期間除了前 10 秒外，其餘時間都被算法當作「在目標深度恆深停留」進行計算，而非「均勻上升/下降」，破壞了 Schreiner 方程式在均勻變壓過程中的物理假設。雖然對組織壓力的整體影響在短時間內受限，但在非等深上升/下潛且有時間差補算時，會降低算法精度。
* **修復建議**：
  應避免在 `buhlmann.update` 內部立即更新 `prevDepth`，或是在 `DiveEngine` 的 chunking 迴圈中，根據當前步長所對應的線性插值深度來傳入 `depth`，並在整個 tick 的所有 chunking 結束後才更新 `prevDepth`。

### 2. `ImportCoordinator` 批次匯入的重複日誌漏檢漏洞
* **檔案位置**：[ImportCoordinator.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Importers/ImportCoordinator.swift#L237-L247)
* **邏輯缺陷**：
  `deduplicateDives` 的去重邏輯僅與「當前資料庫中已存的日誌」進行對比：
  ```swift
  let existing = try database.fetchAllDives()
  return dives.filter { dive in
      !existing.contains { existing in
          abs(existing.dateTime.timeIntervalSince(dive.dateTime)) < 60
              && existing.location == dive.location
              && existing.maxDepth == dive.maxDepth
      }
  }
  ```
  如果用戶匯入的批次檔案內（或單個匯入檔案中）包含相互重複的潛水日誌，由於這些日誌在此時均未寫入資料庫，此 filter 無法偵測到它們彼此之間的重複，導致這些重複日誌全數通過篩選，最終同時寫入資料庫。
* **安全隱患**：
  容易導致資料庫中產生重複的潛水記錄，破壞數據的唯一性與統計數據的準確性。
* **修復建議**：
  參考 [DiveLogDatabase.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Models/DiveLogDatabase.swift#L179-L214) 的設計，在遍歷去重時，將已判定為非重複的日誌動態加入臨時的比對陣列中，防止批次內部的自我重複。

### 3. `ImportCoordinator` 於主線程執行同步 CPU 密集解析（主線程卡死風險）
* **檔案位置**：[ImportCoordinator.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Importers/ImportCoordinator.swift#L68-L116)
* **邏輯缺陷**：
  `ImportCoordinator` 類別被宣告為 `@MainActor`，其異步方法 `importFile` 亦運行於主線程。但在 Step 3 中，解析檔案的 `importer.parse(from: filePath)` 是一個同步的 CPU 密集型操作。
* **安全隱患**：
  當用戶批次匯入多個檔案，或單個檔案非常大時，主線程會被同步阻塞數秒，這會導致 App 的 UI 直接凍結、掉幀，在 iOS/watchOS 上甚至可能因觸發系統的 Watchdog 機制而導致 App 被強行終止。
* **修復建議**：
  將 `importer.parse` 移至非主線程的專用 Actor 或 Task.detached 背景執行緒中執行，解析完成後再回傳至主線程進行資料庫寫入。

### 4. 跨日水面間隔未主動重置 `otuUnits`（OTU 數值顯示矛盾）
* **檔案位置**：[DiveEngine.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Algorithm/DiveEngine.swift#L528-L533)
* **邏輯缺陷**：
  OTU 的單日重置邏輯僅在水面狀態轉為潛水狀態的 `beginDive()` 中觸發：
  ```swift
  if let last = surfaceStatus.lastSurfacedAt,
     let now = lastUpdateTime,
     now.timeIntervalSince(last) > 24 * 3600 {
      oxygen.resetDailyOTU()
  }
  ```
* **安全隱患**：
  當潛水員完成潛水後在水面休息超過 24 小時（或數天），由於沒有開始新的潛水，`beginDive()` 從未被觸發。此時，UI 或 Widget 顯示的氧暴露指數（OLF% / OTU）仍會一直顯示上一次潛水後的舊數值，而不會隨著時間推移在水面上主動歸零，對用戶造成顯示數值上的生理安全恐慌與矛盾。
* **修復建議**：
  在水面 `tick` 或 `restore` 狀態還原時，若發現當前時間距離上一次出水時間 `lastSurfacedAt` 已超過 24 小時，應主動將 `oxygen.otuUnits` 歸零。

---

## ⚠️ 建議 (Suggestions)

1. **初始殘氮計算與水面空氣呼吸的常數微小不一致**
   * **檔案位置**：[DiveEnvironment.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Models/DiveEnvironment.swift#L72-L75) 與 [GasMix.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Models/GasMix.swift#L18-L33)
   * **細節說明**：
     初始組織氮分壓 `initialTissuePN2` 的計算使用的是 `AlgorithmConstants.fN2Air = 0.7902`，即在海平面為 `0.740654 bar`。然而，在氣體組成 `GasMix` 中，空氣的氮氣分率 `GasMix.air.fN2` 定義為 `0.79`。這導致在水面更新 `updateSurface` 時，使用 `.air`（fN2 = 0.79）算出的水面肺泡氮分壓為 `0.740207 bar`。這使得剛初始化的組織壓力在水面上呼吸空氣時，會緩慢進行脫飽和（降至 `0.740207 bar`）。
   * **建議**：
     此偏差非常微小（`0.00045 bar`），在安全上無影響。但為求物理模型一致性，建議在未來版本評估是否統一，使初始狀態與水面穩態完全吻合。

---

## ✅ 通過 (Pass)

經稽核，以下模組之核心邏輯與演算法完全正確，符合標準：

1. **Buhlmann ZHL-16C 參數精確性**
   - 隔室參數表 `zhl16cTable` 的半衰期、a 值與 b 值完全符合標準的 Buhlmann ZHL-16C 氮氣模型規範。
2. **Schreiner 組織方程式計算精確**
   - `TissueMath.schreiner` 完整且正確地實現了 Schreiner 指數方程式，在壓力變化率 `Pr` 與肺泡初始分壓 `Palv_initial` 的輸入上也符合氣體分壓隨時間變化的物理性質。
3. **單位轉換與環境模型設計精準**
   - 壓力與深度之間的轉換 `absolutePressure` 與 `depth(from:)` 設計嚴謹，且能根據 `metersPerBar` 正確區分海水（10.0）與淡水（10.2）環境，並支持高海拔氣壓插值。
4. **GF 限制線線性插值精確**
   - `currentGF(at:)` 將插值轉移到壓力空間（Pressure space），相較於直接在深度空間插值，能更精準地適應高海拔等不同大氣壓力的環境，防禦性 guard 與 clamp 也足夠健壯。
5. **SwiftData 模型與 DTO 解耦優良**
   - [DiveLogBackup.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Models/DiveLogBackup.swift) 作為 DTO 解耦了 SwiftData Model 與 JSON 的 Codable 序列化，有效地保護了資料庫架構升級時的資料遷移相容性，且 DTO 結構在 Swift 6 下均能保證 `Sendable` 屬性，符合並行安全規範。
6. **Apnea 訓練計時器狀態機無狀態依賴**
   - `ApneaTimer` 設計為純狀態機模型，不依賴系統 Timer 物件，方便 UI 使用 `TimelineView` 進行無縫渲染，操作邏輯與閉氣、換氣流程符合業界標準。

---

> [!IMPORTANT]
> **Xcode 同步警告**
> 
> 若後續根據此報告的建議進行程式碼修改，如需建立任何新檔案（例如建立獨立的背景解析 Actor 類別），**必須手動透過 Xcode GUI 建立或使用 `xcode-control` 進行註冊**，切勿直接在檔案系統中新增檔案，以避免專案檔 (`.xcodeproj`) 結構損壞。
