# Changelog

All notable changes to JD2-Logbook will be documented in this file.

Format: `[vX.Y.Z] — YYYY-MM-DD`

---

## [v1.0.0] — 2026-08-18 (目標)

### Added
- 潛水日誌 CRUD（新增、編輯、刪除、列表、詳情）
- 日曆視圖（DiveCalendarView）
- 多格式匯入：UDDF / Subsurface XML / Subsurface CSV / Suunto JSON / Garmin FIT / Shearwater / Seabear CSV / Oceanic
- ImportCoordinator 自動格式偵測與批量匯入
- GPS 座標記錄 + MapKit 地圖顯示（潛點聚類）
- AdMob Banner 廣告（Logbook / Import / Settings / Map 空狀態）
- StoreKit IAP「Remove Ads $1.99」
- 18 種語言本地化（繁中、簡中、英文、日文、韓文、法文、德文、西班牙文、義大利文、荷蘭文、葡萄牙文、印尼文、馬來文、越南文、泰文、希臘文、克羅埃西亞文、英國英文）
- iOS + macOS 雙平台支援
- Bühlmann ZHL-16C 減壓演算法
- WCAG 2.1 AA 可達性合規

### Technical
- SwiftUI + SwiftData，iOS 17+ / macOS 14+
- Swift 6 strict concurrency
- GoogleMobileAds SDK v11 接入
- FitFileParser SPM 套件（Garmin FIT 解析）

---

## [開發階段紀錄]

### 2026-07-19 — 補齊 Suunto DM5 最後一個遺失檔案 `Dive_2026-06-04-0819.xml`

F-07 待辦 6 原本列了 2 個確認遺失的 D4i 檔案（`0948`／`0819`），`0948` 已於同日
稍早補齊，`0819` 使用者補上傳後也已歸檔驗證（`SuuntoDM5XMLParserTests` 新增
1 個真實樣本斷言，全綠），待辦 6 全數銷項。另外，4 個 `.sde` 匯出重新下載後
依然是 0 bytes 空檔，非傳輸偶發問題，疑似 DM5 軟體端 `.sde` 匯出功能本身有
問題，使用者決定暫緩擱置，已記錄於 F-07 待辦表。

### 2026-07-19 — 使用者提供同批 4 次潛水的完整 Suunto 多格式匯出，修復 3 個真實 bug

使用者提供同一支錶（序號 99723006）4 次潛水的多格式匯出：4 個 SML、3 個新
DM5 XML（其中 `Dive_2026-06-03-0948.xml` 正是先前 F-07 確認遺失、待辦要 PM
重新匯出的那個檔案，本次補齊）、2 個真實 Suunto App JSON、2 個 Suunto FIT；
4 個 `.sde` 匯出皆為 0 bytes 空檔，未歸檔（待使用者確認匯出流程問題）。三方
（SML／DM5 XML／JSON）交叉核對同一批潛水的深度/時長/氣體數值一致。

**修復 1：`SuuntoJSONParser` 樣本剖面靜默遺失**——真機的 Suunto App JSON 匯出
樣本點只有絕對時間戳 `TimeISO8601`，從未出現解析器原本唯一支援的相對秒數
`Time` 欄位，導致 `profileSamples` 永遠是空陣列（dive 匯入成功但深度剖面圖是
空的，不報錯）。已修復：改用 `TimeISO8601 - Header.DateTime` 反推相對秒數，
`Time` 欄位保留作 fallback。**這也是本次順便補齊的最急迫格式缺口**——Suunto
JSON 先前連假資料都沒有，是全格式中驗證狀態最差者，`SuuntoJSONParserTests`
新增 3 個測試（2 真實樣本＋1 迴歸測試）全綠。

**修復 2：`GarminDescentParser` 誤接受非 Garmin 廠牌的 FIT 檔案**——用 2 個真實
Suunto FIT 匯出驗證時發現，`canHandle` 原本只驗證 FIT magic bytes（通用容器
格式），會誤判非 Garmin 廠牌的 `.fit` 為可解析；解析時因缺少 Garmin 專屬的
`dive_gas`（GMN 269）訊息，`gasMixJSON` 靜默退回預設值 `"air"`，但深度/時長
（來自通用的 `session` GMN 18）看起來完全正常、不會報錯——實測兩筆皆為
Nitrox 30%，被誤判成 Air，是最危險的一種靜默資料錯誤。已修復：新增
`file_id.manufacturer` 檢查，非 Garmin 廠牌在 `canHandle`／`validateContent`
階段明確拒絕，`parse` 拋出寫明實際廠牌的 `unsupportedFormat` 錯誤。
`GarminFITParserTests` 新增 2 個迴歸測試全綠。Suunto FIT 樣本已歸檔為負向
測試 fixture，不會被任何解析器誤用。

真實樣本已歸檔至 `_JD2-family/dive-log-samples/Suunto/`（原始檔，SML/DM5/JSON/
FIT 各自子目錄）與 `_JD2-family/00_Import_samples/`（Suunto_SML 更新、
Suunto_DM5 新增第 3 筆、**新增 `Suunto_JSON/` 首次涵蓋此格式**）。
`JD2-LogbookTests` 全套件 209 通過／15 略過／0 失敗。詳見
`_JD2-family/F-07-IMPORT_FORMAT_COVERAGE.md` Suunto 各行。

### 2026-07-19 — 修復 Suunto SML 解析器真實 bug（使用者提供真實裝置匯出後發現）

使用者提供 2 個真實 Moveslink 裝置匯出（序號 99723006，2021-09-01／2021-09-04，
共 141／156 筆採樣），取代先前 F-07 稽核確認的模擬樣本。實測發現
`SuuntoSMLParser.parseISO8601` 對真機常見的無時區 `DateTime`（如
`2021-09-01T15:14:26`，不含 `Z`／offset）一律回傳 `nil`，導致整筆解析失敗——
舊的模擬樣本因誤植了 `Z` 後綴而長期未曝光此問題。已修復（加無時區格式
fallback，與 `ShearwaterXMLParser`／`UDDFParser` 既有慣例一致）；另外發現真機
Header 其實有 `<Depth><Max>` 欄位（舊文件誤記「Header 沒有 MaxDepth」），已更正
檔頭註解，解析行為本身不變（仍從樣本點推算 maxDepth，較穩健）。
`SuuntoSMLParserTests` 新增 3 個測試（2 個真實樣本斷言＋1 個無時區迴歸測試）
全綠。真實樣本已歸檔至 `_JD2-family/dive-log-samples/Suunto/SML/`（原始檔）與
`_JD2-family/00_Import_samples/Suunto_SML/`（改日期版，取代原模擬樣本）。詳見
`_JD2-family/F-07-IMPORT_FORMAT_COVERAGE.md` Suunto 表格。

### 2026-07-19 — 修復 DAN DL7 解析器兩個真實 bug

家族樣本庫 `DL7.zxu` 從截斷版（誤植，只有 1 筆採樣點）補回 Subsurface 官方完整
內容（3 組潛水記錄＋1 個真實 `ZDP{...}` 剖面區塊）後，發現解析器完全無法正確
處理：① `ZDH`/`ZDT` 配對用錯欄位（`fields[1]` 應為 `fields[2]`），導致唯一帶
剖面資料的那筆潛水配對失敗被靜默丟棄；② `ZDP{...ZDP}` 多行區塊語法完全不被
支援，只認合成測試用的單行格式。依 PyDL7 開源實作核實欄位語意後修正兩者，
新增區塊語法解析（與既有單行語法並存）。修復後正確解析出 3 筆潛水，`ZDP`
剖面路徑首次被真實資料驗證通過。iOS+macOS build 成功、`DANDL7ParserTests`
全綠、全套件無回歸。詳見 `_JD2-family/F-07-IMPORT_FORMAT_COVERAGE.md` 第七節。

### 2026-07-19 — 匯入批次結果 UI：不再靜默丟棄失敗清單

實測 `00_Import_samples`（20 個真實樣本）批次匯入時發現 UI 只顯示
「Import Successful」，完全不顯示哪些檔案失敗。追查根因：
`ImportWizardView.runBatchImport` 逐檔錯誤只記 `firstError`（第 2 個以後的失敗
直接丟棄），只要批次裡有一筆成功就跳到 `.success`；`skipped` 也永遠寫死 0，
即使 `ImportCoordinator` 內部確實算出 dedup 略過筆數，只印到 console 沒回傳。

- `ImportCoordinator.importFile` 回傳型別改 `ImportFileResult`（`dives` +
  `skippedDuplicates`），把原本只印 console 的 dedup 筆數一併回傳。
- `ImportWizardView`：新增 `ImportFailure`（檔名+原因）；`ImportStep.success`
  加 `failures` 參數；`runBatchImport` 改單一 catch block 蒐集**全部**失敗
  （含原本被特殊跳過的 `emptyFile`），不再只留第一個；成功畫面依
  `failures`/`count` 三態呈現（全成功綠勾勾／部分完成橘色警示+失敗清單／
  全失敗紅色 X+失敗清單），不再有任何一筆錯誤資訊被靜默丟棄。
- 驗證：iOS+macOS build 成功、測試套件全綠、`00_Import_samples` 全部 20 個
  真實檔案批次匯入 **100% 成功**（0 失敗——搭配同日 DiveImportKit v0.2.1 的
  Seabear／SubsurfaceCSV 格式覆蓋補強後，先前的 4 個失敗樣本已全部修正）。

分支 `feature/import-failure-visibility`（總指揮驗收後 merge）。

### 2026-07-19 — F6 階段一：改用家族共用匯入解析器套件 DiveImportKit

家族 F6（Importers 合流）第一步：Logbook 端採用新建的 `../DiveImportKit`
（獨立 git repo，v0.1.0，130 tests 全綠），5 個已抽取的格式解析器
（UDDF／Subsurface XML／Subsurface CSV／Shearwater／Seabear CSV）改為
Kit 引用＋App 端薄包裝，App 內對應實作刪除。分支
`feature/F6-shared-import-kit`，三個 commit（總指揮驗收後 merge）：

1. **`project.pbxproj` 新增 `../DiveImportKit` local package**（主 target +
   Tests target，比照 F5 DiveKit 手法；plutil -lint ＋ resolvePackageDependencies
   兩道驗證通過）。
2. **新增 `JD2Core/Importers/DiveImportKitAdapter.swift`**——全 App 唯一
   `import DiveImportKit` 的檔案（Kit 與本地型別同名，只在 adapter 內以
   `DiveImportKit.` 前綴限定，避免全面歧義）：
   - `ParsedDiveLog → DiveLog` 逐欄位對映；`profileSamples` 陣列編回
     `profileSamplesJSON`（短鍵 t/d/w）、`importExtras` 陣列走既有
     `buildImportExtrasJSON` 編回 `importExtrasJSON`，SwiftData schema 零變動。
   - **Kit 錯誤 → 本地 `DiveLogImportError` 逐 case 轉換**（ImportWizardView
     以本地 case 逐一 catch，不轉換 UI 錯誤提示會劣化）。
   - 5 個薄包裝 struct 沿用原名（`UDDFParser` 等），`DiveLogImporterFactory`
     清單與 priority 順序、既有測試（F5 E2E 等）零改動。
   - `MinimalZipReader` 本地薄轉發 enum（`SuuntoSDEParser` 仍在用；因專案啟用
     `MemberImportVisibility`，typealias 再匯出行不通，Ultra 端採用時同樣要注意）。
   刪除已搬遷實作：monolith 內 4 個解析器＋私有 delegate/資料結構
   （`DiveLogImporter.swift` 2483→911 行）、`ShearwaterXMLParser.swift`、
   `MinimalZipReader.swift` 整檔。保留：protocol／`DiveLogFormat`／
   `DiveLogImportError`／Factory／Peregrine·Oceanic 本地 stub／其餘 Logbook
   專屬解析器／`ImportCoordinator`（去重/並發邏輯不動，SYNC #2/#3 另案）。
3. **測試調整**：刪除 5 個已搬遷解析器的測試檔（邏輯已在 Kit 測過），新增
   `DiveImportKitAdapterTests`（test42.uddf 走 factory→包裝→DiveLog 全流程，
   關鍵欄位斷言與搬遷前期望值一致）。

驗證：iOS＋macOS build 成功；iOS 模擬器與 macOS 本機均實際啟動；測試套件
（排除既有已知崩潰的 `ImportCoordinatorTests`）0 failures（SuuntoJSON 樣本
缺檔 skip 為既有現象）。UI 完全未動，匯入流程仍走原 factory 入口。

### 2026-07-18 — F5：改用家族統一 DiveKit（取代 JD2Core 演算法 fork）

三個 JD2 家族 App 中 ultra／immersion 已於 F3a/F3b 改用統一 `DiveKit`（SPM 引用），
本次 Logbook 跟進，家族「共用演算法只有一份」目標達成。分支
`feature/F5-divekit-migration`，三個 commit：

1. **`project.pbxproj` 新增 `../DiveKit` local package**（主 target + Tests target）。
2. **刪除 JD2Core 12 個死碼/重複檔**（Algorithm 7 檔＋Constants 1 檔＋State 3 檔＋
   Models 4 檔），改吃 DiveKit 對應型別；`DiveReplayEngine.swift`（Logbook 專屬回放
   引擎，語意不同不遷移）與 21 個消費檔補 `import DiveKit`。刪除
   `DiveEngineTests.swift`（測試已刪除的死碼，其回歸場景已在 DiveKit 自己的測試
   套件覆蓋）。**根因排查**：`DiveReplayEngineTests` 先前的 malloc 崩潰證實是被
   `DiveEngineTests` 汙染共享測試行程，刪除後單獨執行 4/4 全過、無崩潰。
3. **發現並繞過 DiveKit 已知缺口**：`Buhlmann` 只追蹤氮氣（`Compartment` 無 `pHe`
   欄位），trimix 的 `ndlSeconds()` 會 `assertionFailure`（v2.0 項目，尚未實作）；
   用真實 trimix 樣本（`00_Import_samples/`）走完整匯入→剖面分析流程時首次踩到。
   PM 決策：F5 繞過（不動 DiveKit 演算法本體），`DiveReplayEngine.replay()` 偵測
   trimix 即跳過生理計算、只給深度/時間/溫度剖面（`decoDataUnavailable`），
   `DiveAnalysisView` 對應隱藏 Ceiling/NDL/組織艙 UI。真正的 trimix 氦氣支援
   另排（家族層追蹤）。

新增 `F5DiveKitMigrationE2ETests.swift`：真實 trimix 樣本驗證短路路徑正確、合成
空氣潛水驗證完整 DiveKit 重放路徑正常。驗證：iOS+macOS build 成功；測試套件
（排除既有已知崩潰的 `ImportCoordinatorTests`，與本次無關）0 failures。

### 2026-07-17 — 外部稽核報告修復（4 項風險）+ 建立 Ultra 同步追蹤文件

外部稽核報告 `docs/reports/R-2026-07-17-audit_report.md`（原 `audit_report-0717.md`，2026-07-18 歸檔更名）針對核心演算法與匯入流程提出 4 項風險，
逐項核對程式碼後確認全數屬實（非誤報），並全數修復：

1. **`Buhlmann` chunking 迴圈 pRate 歸零 bug**（[DiveEngine.swift](JD2-Logbook/JD2Core/Algorithm/DiveEngine.swift)）
   ：時間補償的 chunk 迴圈原本每一步都傳最終深度給 `buhlmann.update()`，導致
   `Buhlmann` 內部 `prevDepth` 在第一個 chunk 後就等於最終深度，depthDelta 恆為
   0、壓力變化率被誤判為 0，等同把補算期間全當恆深處理。改為依已耗用時間比例
   在「tick 開始前深度」→「本次 tick 深度」間線性插值，與同一份程式碼庫內
   `DiveReplayEngine.swift`（本 session 較早修復）已驗證過的手法一致。
2. **匯入批次去重漏洞**（[ImportCoordinator.swift](JD2-Logbook/JD2Core/Importers/ImportCoordinator.swift)）
   ：`deduplicateDives` 原本只比對資料庫既有記錄的靜態快照，同一批次（甚至單一
   檔案）內部彼此重複的日誌會互相漏檢、全數寫入。改為逐筆比對＋動態把已確認
   非重複的日誌併入比對陣列，抽成可獨立單元測試的 `Self.dedupe(_:against:)`，
   與 `DiveLogDatabase.importFromJSON` 既有正確做法一致。
3. **匯入解析阻塞主執行緒**：`ImportCoordinator` 為 `@MainActor`，`importer.parse()`
   為同步 CPU 密集操作，大檔案/批次匯入會讓 UI 卡住甚至觸發 Watchdog 強制關閉。
   改用 `Task.detached` 包住選格式＋解析。⚠️ 已知限制：專案預設
   `-default-isolation=MainActor`、`DiveLogImporter`/`DiveLog` 皆非 `nonisolated`/
   `Sendable`，此修復在目前編譯設定下僅為 warning（非 error），警告訊息明確標註
   「this is an error in the Swift 6 language mode」；徹底解法需將協定三方法與
   全部 20 個解析器實作標記 `nonisolated`＋處理 `DiveLog` 跨 actor 傳遞，規模較大，
   本次未一併處理，已記錄於 `SYNC_TO_JD2-ULTRA.md`。
4. **OTU 跨日未主動重置**（[DiveEngine.swift](JD2-Logbook/JD2Core/Algorithm/DiveEngine.swift)）
   ：OTU 單日重置原本只在 `beginDive()` 觸發時檢查，若潛水員完成潛水後在水面
   停留超過 24 小時卻未再下潛，UI/Widget 顯示的 OTU 會卡在舊值。抽成共用的
   `resetStaleOTUIfNeeded(now:)`，同時掛在 `beginDive()`、水面 `tick()`、
   `restore()`（App 重啟還原）三處呼叫。

**測試**：新增 `DiveEngineTests.swift`（4 項，涵蓋風險 #1 的 chunking 插值正確性
與風險 #4 的三種歸零情境）＋ `ImportCoordinatorTests.swift` 新增 4 項純邏輯去重
測試（不碰資料庫）。全數通過，iOS/macOS 雙平台建置成功。

**Ultra companion 風險評估**：逐一核對 [JD2-ultra](../JD2-ultra) 對應檔案
（`DiveKit/Sources/DiveKit/Algorithm/DiveEngine.swift`、
`JD2UltraPhone/Import/ImportCoordinator.swift`），確認 4 項風險**全數同樣存在、
尚未修復**（DiveKit 演算法程式碼為早期整包 port 自 Ultra，ImportCoordinator 架構
高度相似）。本次僅評估、未修改 Ultra 程式碼（不同專案，需另行決定是否同步）。
新增 `SYNC_TO_JD2-ULTRA.md` 作為長期追蹤文件，記錄「JD2-Logbook 發現且可能同樣
影響 Ultra」的問題，供 Ultra 端未來參考同步。

### 2026-07-17 — Import 格式清單重新規劃 + 剖面資訊列比照 Ultra companion

**Import tab「Supported Formats」**：格式數擴充到 16 種後，原本無分類的 2 欄
卡片格線難以掃視，改為依品牌/來源分 4 組（Universal / Suunto / Garmin /
Other Brands）＋單欄列表列。列的視覺語彙 port 自 JD2-Ultra companion
`DiveComponents.swift` 的 `SectionHeader`／`ValueRow` 慣例（圖示＋標題置左、
次要資訊置右，grouped 卡片背景＋列間 Divider），對齊 iOS 原生
`List(.insetGrouped)` 視覺語言，而非沿用舊版無來源依據的卡片格線設計。

**Dive Profile 互動剖面圖／組織艙負荷資訊列**：原本的圖示膠囊列（icon+text
pill）改為與 JD2-Ultra companion `DiveAnalysisView.calloutRow` 完全一致的
五欄等寬排版（Time / Depth / Temp / Ceiling / No Deco，label 在上、數值在
下）；新增「安全語意數值才用填色膠囊強調」規則——一般狀態為純深色文字，
只有真的減壓中（紅底白字）或免減壓時間逼近 10 分鐘（黃底黑字）時膠囊才
亮起，其餘與 Ultra 邏輯（`PlanModel.ndlText`：99+ / 分鐘）一致。

新增 4 個 xcstrings 翻譯 key（"Temp"／"No Deco"／"Universal"／"Other Brands"），
18 種語言全數補齊，優先沿用 Ultra 既有翻譯值。

### 2026-07-17 — 匯入格式全面擴充（10 個新解析器，8 個確認無法安全實作）

PM 指示全面查證 `/file_format_research` 盤點的 18 種潛水電腦/軟體格式，不接受
「叫使用者自己轉檔」的退讓方案。逐一重新驗證研究文件的假設（多處與真實樣本
不符，例如 Suunto SDE 內部其實是舊版 DM3 格式而非 DM5、DAN DL7 的 ZDT 記錄
語意與初版猜測相反），並在可能時搜尋開源參考實作交叉驗證byte-level正確性。

**新增 10 個格式解析器**：
- `SuuntoDM5XMLParser`：Suunto DM4/DM5 WCF XML（D4i 等錶款直傳），真實樣本逐欄位驗證
- `SHEARWATERParser`：從空 stub 改為真實實作，同時修正原本用預設 canHandle 誤攔截所有 `.xml`（含 D4i 檔）的根因 bug
- `SuuntoSMLParser`：Moveslink XML，含 Kelvin 水溫轉換
- `DANDL7Parser`：業界標準交換格式，欄位對照依開源 PyDL7 校正（研究文件誤判 ZDT 為逐樣本剖面，實為 dive trailer）
- `DivesoftDLFParser`：二進位格式，欄位偏移依開源 divesoft-parser 逐位元核對，並用真實樣本 3 個獨立欄位（start_time/max_depth/min_temperature）精確驗證吻合；v2 header（"DiVE" magic）明確拒絕而非臆測
- `SuuntoSDEParser`：ZIP 包裝的舊版 DM3 XML（非原研究猜測的 DM5 格式），歐式逗號小數處理
- `ReefnetSensusParser`：CSV，壓力→深度公式依 ReefNet 官方換算說明驗證；水溫欄位因無法可靠確認編碼，刻意不猜測轉換
- `DivingLogSQLiteParser`：原生 SQLite3（無需第三方套件），RTF 備註欄位手寫剝除器（避免引入 UIKit 依賴破壞 JD2Core 跨平台界線）
- `GarminConnectJSONParser`、`DeepbluCOSMIQParser`：格式假設（無公開 API 文件），待真實樣本驗證

**新增 `MinimalZipReader.swift`**：純 Swift 跨平台 ZIP 讀取器（PKWARE 公開規格，
支援 stored/deflate），取代原本只在 macOS 用 `/usr/bin/unzip` 的做法，順便修正
UDDF 的 ZIP 包裝格式在 iOS 原本完全無法匯入的既有缺口。

**確認 8 個格式目前無法安全實作**（Scubapro LogTRAK、Mares Dive Organizer、
Heinrichs Weikamp OSTC、Cressi PC Interface、Ratio iDive、Cochran CAN、
Aqualung i-Trak、APD LogViewer）：逐一檢查後證實為 Microsoft Access/SQL Server
Compact 等專有二進位資料庫無公開規格、或研究樣本僅為文字佔位符（無真實資料
可驗證），非偷懶跳過。具體理由見 `file_format_research/format_inventory.md`。

### 2026-07-17 — v1.1 backlog 完工（6/7 項，widget 決定不做）

**功能**：
- #6/#7 `importExtrasJSON` 欄位：buddy / 裝置序號 / 韌體不再塞進 notes 文字，改結構化存儲；Detail 頁新增可折疊「原始資料」區塊
- #8 `avgDepth` 欄位：來源值優先，無則以剖面樣本梯形近似重建
- #14 Export/Import 備份：`DiveLogDatabase.exportAsJSON/importFromJSON` 從拋錯 stub 改為真正可用，Settings 頁新增入口
- #4/#5 移植 Ultra `DiveKit`：取代本地死碼 `Buhlmann.swift`/`DiveEngine.swift`/`AlgorithmConstants.swift`（9 項已知安全問題）；新增互動剖面圖（拖曳查看深度/水溫/ceiling/NDL，放開後保留選取）＋組織艙飽和度長條圖（預設收合，互動後才顯示）
- #12 Garmin Connect JSON 解析器（FIT 的替代匯入路線）
- #13 解析器測試覆蓋率：`DiveLogImporter.swift` 82.2% → 89.1%
- #9/#10 iOS 18 Widget：PM 確認不需要，終止規劃

**技術債（順手修復，與今日改動無關的舊問題）**：
- `project.pbxproj` 測試 target `TEST_HOST` 殘留改名前的 `JD2-Logbook.app`（應為 `JoyDive².app`），導致 `xcodebuild test` 完全無法建置
- 9 個測試檔案的 `@testable import JD2_Logbook` 未隨模組改名同步（實際模組為 `JoyDive_`）

**架構重點**：互動剖面圖與組織艙圖的選取狀態統一由 `DiveAnalysisView` 管理（非各自為政），重放引擎改為直接驅動 `Buhlmann` + 樣本間 ≤10s 線性內插（比對 JD2-Ultra companion `DiveReplay.swift` 對齊，取代原本用 `DiveEngine.tick()` 逐樣本呼叫、樣本間隔大時深度會瞬間跳變的失真做法）。

**待決策**（下次上架前）：macOS `Info.plist` 的 `LSApplicationCategoryType = public.app-category.sports-games` 會觸發系統誤判為遊戲、自動開啟 macOS 遊戲模式（`gamepolicyd` 只檢查分類值是否以 `games` 結尾）；需決定改為 `public.app-category.sports` 或 `public.app-category.healthcare-fitness`，同時要對齊 App Store Connect 的上架分類。

### 2026-06-03 — AdMob 正式接入（commit 656a246）
- 接入 GoogleMobileAds SDK v11
- 更新 4 個正式 Ad Unit ID
- 修正 SDK v11 API 改名（BannerView / AdSizeBanner / Request）
- 修正 PremiumAwareAdBanner 高度約束問題

### 2026-06-02 — 死碼清理 + 部署目標統一（commit deda6ca / 56dc1a3）
- 刪除 ContentView、placeholder views 等死碼
- SwiftData schema 移除 `buddy` 欄位
- 修正 macOS DiveLogEditSheet O₂ 重複顯示 bug
- 統一部署目標 iOS 17.0 / macOS 14.0
- 新增 .gitignore

### 2026-05-xx — i18n 實裝（commit 84b7b47 / 682087c）
- 匯入 V7.2 多語系校訂版
- 中文用詞統一（繁中 / 簡中 區分）
- 修正 navigationTitle("") 空字串 key 問題

### 2026-05-17 — 專案初始化
- Xcode 專案建立，SwiftData 初始化
- JD2Core 模組架構確立
