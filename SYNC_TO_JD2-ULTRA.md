# SYNC_TO_JD2-ULTRA.md — 待同步至 JD2-Ultra 問題追蹤

**方向：** JD2-Logbook → JD2-Ultra（單向記錄，本專案不會主動修改 [JD2-ultra](../JD2-ultra) 的程式碼）
**建立日期：** 2026-07-17

> 本文件與 `docs/reports/V1_1_BACKLOG_解法參考_from_JD2-Ultra.md`（Ultra → Logbook，已停止更新，2026-07-18 歸檔）
> 方向相反、獨立維護。那份是 Ultra 單向提供給 Logbook 的解法參考；這份是
> Logbook 這一側持續新增，記錄「在 JD2-Logbook 發現、且程式碼源頭可追溯到
> Ultra（DiveKit port 或架構高度相似）的問題」，供 Ultra 端開發者（或未來接手
> 的 Claude session）判斷是否需要同步查證/修復。Ultra 端不會回寫本文件。

---

## 使用方式

每次在 JD2-Logbook 發現一個「原始碼可追溯到 Ultra」的 bug 並修復時，在下方
問題清單新增一列，並標註查證過的 Ultra 對應檔案位置。

**狀態欄位定義：**

| 狀態 | 說明 |
|------|------|
| 🟡 已確認未修 | 已逐行核對 Ultra 程式碼，確認同樣存在此問題，尚未同步修復 |
| 🟢 已同步 | Ultra 已修復（備註欄記錄日期與修復方式） |
| ⚪ 不適用 | 查證後確認 Ultra 該部分架構已不同，此問題不適用 |
| ❓ 待查證 | JD2-Logbook 已修復，但尚未去核對 Ultra 對應程式碼 |

---

## 問題清單

| # | 日期 | 問題摘要 | JD2-Logbook 修復位置 | Ultra 對應位置（已查證） | 狀態 | 備註 |
|---|------|---------|---------------------|------------------------|------|------|
| 1 | 2026-07-17 | **Buhlmann chunking 迴圈 pRate 歸零 bug**：時間補償的 chunk 迴圈原本每一步都傳最終深度給 `buhlmann.update()`，導致 `Buhlmann` 內部 `prevDepth` 在第一個 chunk 後就等於最終深度，depthDelta 恆為 0、壓力變化率被誤判為 0，等同把補算期間全當恆深處理，破壞 Schreiner 方程式的均勻升降假設 | `JD2Core/Algorithm/DiveEngine.swift` `tick()` 補算迴圈 | `DiveKit/Sources/DiveKit/Algorithm/DiveEngine.swift:278-284`（逐行核對，邏輯與修復前的 Logbook 完全相同） | 🟢 已同步 | **2026-07-17 已修**：統一 DiveKit F2 合流 App-i 稽核修復 #1（同款線性內插，commit 72c1682，含回歸測試 CodeAuditFix20260713Tests）。原修復手法備考：依已耗用時間比例在「tick 開始前深度」→「本次 tick 深度」間線性插值，每個 chunk 傳插值後的深度，最後才更新 tick 層級的 prevDepth。JD2-Logbook 端 `DiveReplayEngine.swift`（本 repo 較早修復）已用相同插值手法，可直接參考該檔案 |
| 2 | 2026-07-17 | **ImportCoordinator 批次匯入去重漏洞**：`deduplicateDives` 原本只比對資料庫既有記錄的靜態快照（`let existing = try database.fetchAllDives()` 後用 `.filter`），同一批次（甚至單一檔案）內部彼此重複的日誌，因當下都還沒寫入資料庫，會互相漏檢、全數通過並寫入 | `JD2Core/Importers/ImportCoordinator.swift` `deduplicateDives()` | `JD2UltraPhone/Import/ImportCoordinator.swift:231-241`（邏輯相同：`let existing = ...`＋`.filter`，未動態累積） | 🟡 已確認未修 | 修復手法：改為逐筆比對＋動態把每筆已確認非重複的日誌併入比對陣列（`existing.append(dive)`），與 `DiveLogDatabase.importFromJSON`（JD2-Logbook 既有正確實作，備份還原用）手法一致，可直接參考 |
| 3 | 2026-07-17 | **匯入解析阻塞主執行緒**：`ImportCoordinator` 宣告為 `@MainActor`，但 Step 3 的 `importer.parse(from: filePath)` 是同步、CPU 密集操作，大檔案或批次匯入多檔時會讓 UI 卡住數秒甚至凍結掉幀，iOS/watchOS 上可能觸發 Watchdog 強制關閉 App | `JD2Core/Importers/ImportCoordinator.swift` `importFile()` Step 2+3 | `JD2UltraPhone/Import/ImportCoordinator.swift:81-89`（同樣同步呼叫 `importer.parse`，同樣 `@MainActor`） | 🟡 已確認未修 | ⚠️ **JD2-Logbook 本身的修復尚不完美**，套用前請先讀完下方「風險 #3 已知限制」章節，不要直接照搬 |
| 4 | 2026-07-17 | **OTU 跨日未主動重置**：OTU（單日氧毒性累積）的重置邏輯原本只在 `beginDive()` 觸發時檢查「距上次出水是否已超過 24 小時」，若潛水員完成潛水後在水面停留超過 24 小時卻遲遲未開始下一次潛水，`beginDive()` 永遠不會被呼叫，UI/Widget 顯示的 OTU 會一直卡在舊值，造成生理安全數值上的顯示矛盾 | `JD2Core/Algorithm/DiveEngine.swift` 新增 `resetStaleOTUIfNeeded(now:)`，被 `beginDive()`／水面 `tick()`／`restore()` 三處共用 | `DiveKit/Sources/DiveKit/Algorithm/DiveEngine.swift:532`（同樣只在 `beginDive()` 內檢查一次） | 🟢 已同步 | **2026-07-17 已修**：上收至統一 DiveKit v1.1.1（resetStaleOTUIfNeeded 三處共用＋3 回歸測試）。 Ultra 有 watchOS 常駐錶面顯示，比 JD2-Logbook（純 iOS/macOS app）更容易出現「App/錶面長時間開著、停留水面不下潛」的情境，實務影響可能比 Logbook 更明顯，建議優先評估 |
| 5 | 2026-07-19 | **F6 階段一採用 DiveImportKit 的移植備忘**（非 bug，供 Ultra 端採用 Kit 時參考）：(a) Kit 型別與 App 端同名（`DiveLogImporter`/`DiveLogFormat`/`DiveLogImportError`），只在單一 adapter 檔 import Kit＋`DiveImportKit.` 前綴限定，其他檔案零 import，避免全面歧義；(b) Kit 錯誤需逐 case 轉回 App 本地 error enum，否則 UI 端 per-case catch 全部落空、錯誤提示劣化；(c) 專案若啟用 `MemberImportVisibility`（Logbook 已啟用），`typealias MinimalZipReader = DiveImportKit.MinimalZipReader` 再匯出後其他檔案呼叫成員會編譯失敗，需改為本地薄轉發型別 | `JD2Core/Importers/DiveImportKitAdapter.swift`（完整參考實作） | `JD2UltraPhone/Import/`（Ultra 端 F6 採用時） | ❓ 待查證 | Ultra 端尚未採用 Kit；採用時本列三點可直接照抄 Logbook 的 adapter 手法 |
| 6 | 2026-07-21 | **DiveAnalysisView 剖面圖互動選取線／拖曳命中座標偏移 bug**：`chartOverlay` 的 `GeometryReader` 內直接把 `proxy.position(forX:)`（畫選取線）與手勢的 `value.location.x`（給 `proxy.value(atX:)` 查時間，即拖曳命中判定）當成 GeometryReader 本身的座標系使用；但 Swift Charts 的 `proxy.position(forX:)`/`proxy.value(atX:)` 都是相對「繪圖區域」（plot area，不含左側 Y 軸刻度標籤寬度）的座標。兩者座標系統不一致，導致選取線與拖曳命中整體往左偏移一個 Y 軸刻度標籤寬度（使用者截圖：選取線已飄移到 0 分鐘刻度左側、圖表外面） | `JD2-Logbook/JD2-Logbook/Views/Logbook/DiveAnalysisView.swift` `interactiveChart`／`select(atX:proxy:)` | `JD2UltraPhone/UI/Logbook/DiveAnalysisView.swift:66,76-78`（逐行核對，`position(forX:)`／`value(atX:)` 一樣沒有扣掉 `plotAreaFrame` 的 origin，同款 bug） | 🟡 已確認未修 | 修復手法：用 `geo[proxy.plotAreaFrame]` 取得繪圖區域在 GeometryReader 座標系裡的實際 frame，選取線改用 `.position(x: plotFrame.minX + x, y: plotFrame.midY)`；拖曳命中改用 `proxy.value(atX: x - plotFrame.minX)`。此為 App 層 UI bug，非 DiveKit／DiveImportKit 範圍，不受單一戰場規則限制，Ultra 端可直接套用同樣手法 |

---

## 風險 #3 已知限制（套用前必讀）

JD2-Logbook 對風險 #3 的修復（用 `Task.detached` 包住 select+parse）在目前的
編譯設定（Swift 5 language mode + 部分 `-enable-upcoming-feature`、
`-default-isolation=MainActor`）下**只產生 compiler warning，不是徹底的 actor
隔離修復**。實際編譯輸出的 warning 訊息明確標註：

> "this is an error in the Swift 6 language mode"

原因：`DiveLogImporterFactory`/`DiveLogImporter` 協定的方法沒有標記
`nonisolated`（模組預設全部繼承 `@MainActor`），`DiveLog`（SwiftData `@Model`）
也不是 `Sendable`。要徹底解決需要：

1. 將 `DiveLogImporter` 協定三個方法（`parse`/`canHandle`/`validateContent`）
   與全部解析器實作（JD2-Logbook 這邊約 20 個檔案）標記 `nonisolated`
2. 處理 `DiveLog` 跨 actor 邊界傳遞的 Sendable 問題（官方建議方向：改用
   `ModelActor`，或改傳 `persistentModelID` 而非完整物件——但這裡是尚未寫入
   context 的新解析物件，不完全適用）

這兩項規模明顯大於本次稽核修復範圍，JD2-Logbook 這邊也還沒做。**若要在 Ultra
同步這項修復，建議先評估是否值得一次做完整的 actor 隔離重構，而不是重複套用
同一個不完美的 `Task.detached` workaround。**

---

**文件版本：** v1.0 | **建立日期：** 2026-07-17 | **最後更新：** 2026-07-17（#1/#4 已同步至統一 DiveKit——F2 合流與 v1.1.1 上收；#2/#3 屬 Ultra App 層，已登錄 JD2-ultra/PM_ACTION_ITEMS.md）
