# App-lb v1.4 工作計劃——優先順序與工時估計（2026-10-26，待 PM 排程）

> **狀態：僅登記、未動工。** PM 尚未排程 v1.4；本檔供 PM 裁示範圍與順序用。
> 來源：`HANDOFF.md`「下一版待辦」、`docs/KNOWN_ISSUES.md`「v1.3 後仍開放」、PM 2026-10-26 指示（#6／#7／#8 優先；新增 GPS 座標跳轉與地圖聚合問題）、總指揮 2026-10-26 兩次查詢回覆。
> 基準：HEAD `0ae189e`；v1.3 (Build 4) 已上架；`run_tests.sh logbook` **171／0／1**（唯一允許的 skipped：`PurchasePriceDisplayTests.testPremiumPriceStringIsNilWhenProductNotYetLoaded`）；Kit 現況 DiveKit **v9.6.1**／DiveImportKit **v0.8.1**（Logbook 以 local path 引用、無版本鎖定）。
> 可寫入範圍：只限 `JD2-Logbook`；Kit 有問題走鐵律 3／8 回報總指揮，不在本 repo 繞道。
> 工時單位：工作日，含測試、18 語字串、`ui-verify`；**不含** PM build 確認等待。**全部是依程式碼大小與結構的推估，不是實測。**

## 〇、編號對照

PM 口頭用「#6／#7／#8」指 `HANDOFF.md` 待辦清單的第 6、7、8 項。本檔改用 A／B／C 編號避免混淆：

| 本檔 | 內容 | 原稱 |
|---|---|---|
| A1 | 環境欄位「未記錄」 | #8 |
| A2 | 搜尋範圍擴充 | #7 |
| A3 | 列表篩選 | #6 |
| B1 | 詳細頁 GPS 座標可點 → 跳地圖置中 | 新增（PM 10/26） |
| B2 | 地圖同座標多筆聚合後無法點開 | 新增（PM 10/26） |
| C | 其餘小項 | #1–#4、其他 |

## 一、建議順序

A1 → A2 → A3 → B1＋B2（兩者相依、同批）→ C（順手帶）。A 組與 B 組無共用程式碼，之後可並行。

| 順序 | 項目 | 估時 | 風險 |
|---|---|---|---|
| 1 | A1 環境「未記錄」 | 2.5–3 天（10/26 改 `String?`＋遷移＋高海拔閘門 D8＋VersionedSchema V1 0.5 天） | 中（SwiftData 遷移；演算法零變動） |
| 2 | A2 搜尋擴充 | 0.5 天（搜 JSON 文字）／1.5 天（新增欄位＋migration） | 低／中 |
| 3 | A3 列表篩選 | 3–4 天 | 中（效能未量） |
| 4 | B1 座標跳轉 | 0.5–1 天 | 低 |
| 5 | B2 聚合 | 1–1.5 天 | 中（成因未實機重現） |
| 6 | C 小項 | 約 2 天 | 低 |
| | **合計（不含 GDPR／UMP）** | **約 9.5–13 天**（10/26 因 A1 改估上調） | |

## 二、A 組（PM 優先）

### A1 環境欄位「未記錄」

> ✅ **2026-10-26 程式完成**（測試 185/0/1；v1.3 真實 store 升級實測通過；截圖 `docs/screenshots/v1.4-A1/`）。待辦：三段新文案 PM 定稿＋補 15 語。

- **現況（已查證）**：`DiveLog.environmentType` 預設 `"seawater"`（`JD2Core/Models/DiveLog.swift:108`）；DiveImportKit 所有解析器都不填此欄（唯一提及是 `DivingLogSQLiteParser.swift` 一則「刻意不映射 Water」的註解）⇒ **每筆資料現在都是預設值**，無法分辨真海水或沒記錄。
- **重放與環境字串無關**：重放讀 `surfacePressureBar`／`metersPerBar`（`JD2Core/Algorithm/DiveReplayInput.swift:20-29`），註解明寫「不做 environmentType 字串分支」。
- **家族裁示（總指揮 10/26 轉述，我未逐檔核對）**：匯入與重放不依 environmentType 調整密度（`_JD2-family/decisions/2026-09-12_P3查證結果-匯入端壓力欄位盤點.md` §5.4）。⇒ **「未記錄」時重放仍用 1.0 bar／10.0 m/bar（現況），演算法輸出零變動。**
- **做法（10/26 裁示，見 `docs/decisions/D-2026-10-26-環境欄位未記錄.md`）**：`environmentType` 改 `String?`，`nil`＝未記錄（**不用 `"unknown"` 哨兵**——原草稿做法作廢）。需 SwiftData 遷移（v1.3 真實 store 實測）＋`DiveLogBackup` 改可選（舊備份相容測試）；手動新增預設未記錄、Picker 加選項；詳細頁／地圖面板 `switch` 補 nil 分支；「重放限制說明」頁加一句揭露（三語草稿在決策檔 §四，待 PM 看）。**有值的紀錄絕不覆寫**（簽章欄位）。
- **限制**：舊資料（含全部既有紀錄）**不回溯**，維持顯示「海水」（D2 已裁示採納）。
- **估時更新**：因改 schema，A1 由 1 天改估 **1.5–2 天**；再加高海拔閘門（D8）＋0.5 天 ⇒ **2–2.5 天**；再加 VersionedSchema V1（D3，PM 10/26 接受 0.5 天）⇒ **2.5–3 天**。
- **已知殘留風險**：湖泊潛水仍以海水密度計算深度換算（家族「深度顯示換算密度」仍列待確認，`2026-09-29_入水前出水後畫面-盤點與裁示.md` §三-3）；本項不處理，需在說明中標明。
- **驗證**：新匯入無環境資料的檔案 → 詳細頁顯示「未記錄」；既有紀錄不變；重放輸出前後比對一致。

### A2 搜尋範圍擴充

- **現況**：搜尋只比對 `location` 與 `notes`（`DiveLogListView.swift:43-44`）。
- **查證結果改變範圍**：
  - 潛伴、標籤**不是** `DiveLog` 欄位，只存在 `importExtrasJSON` 的 key-value dump（`DiveLog.swift:194` 註解）。
  - **沒有獨立的「潛點名稱」欄位**，`location` 即潛點 ⇒ 「潛點名稱」那半項大概已被現有搜尋涵蓋（待 PM 確認意圖）。
- **家族狀況（總指揮 10/26）**：App-u 搜尋只有地點、無 buddy／tags；App-i 無；搜尋範圍家族無規格；Kit 的 adapter 層「各自照抄、不強迫拉齊」。⇒ 無跨 App 約束，Logbook 自行決定。
- **方案**：
  - **A2-1** 搜 `importExtrasJSON` 文字（0.5 天）：快，但會誤中鍵名（例如搜「name」命中 JSON key）。
  - **A2-2** 新增欄位 `buddy`／`tags` 並在匯入時填入（1.5 天）：精確，需 SwiftData migration（v1.3 起有 `DatabaseOpenFailureTests`，但 **`SchemaMigrationPlan` 尚未建立**，見 `KNOWN_ISSUES.md`），風險較高。
- 提示文字一併改（不再只寫「地點」），需 18 語字串。

### A3 列表篩選（氣體、潛水類型、組織負荷）

- **PM 10/07 同意記入；PM 10/26 同意轉交總指揮評估。**
- **氣體**（空氣／高氧／未知氣體）、**潛水類型**（水肺／自由潛水）：欄位已存在（`gasMixJSON`／`DiveLog.displayGasMix`、`diveMode`），各約 0.5 天。
- **組織負荷（支援／不支援）**——採總指揮評估的方案 B：
  - 篩選開啟時，在**記憶體**一次 fetch 全部紀錄、按時間排序，以 96 小時滑動窗口逐筆呼叫 DiveKit 既有的 `DiveReplayEngine.precheck(target:precedingDives:)`；**不存資料庫、不改 Kit**。
  - 核對（本 session 讀碼）：`precheck` 為 public（`DiveKit/.../DiveReplay.swift:405`，`@MainActor`）；該檔唯一的 `return .anomaly` 在 `:353`；Logbook 生產路徑目前**零呼叫**。
  - 否決方案：A（每筆各自 fetch，N 次查詢）；C（在 `DiveLog` 存「是否支援」欄位——某筆狀態取決於其前 96 小時的其他潛水，任何新增／編輯／刪除都會讓後面的值安靜地過期）。
  - **三個條件（總指揮）**：
    1. 前導候選挑法只能有一份——把 `DiveReplayChainQuery.precedingDives`（`DiveReplayInput.swift:200-221`，含排除 `hasUnknownDateTime`）抽成「吃排序後陣列」的純函式，詳細頁與列表共用（約 0.5 天；動到現有詳細頁路徑，需回歸測試）。
    2. 一致性測試：對 fixture 每一筆斷言「篩選判定 == `replayChain` 是否 `.anomaly`」，並用 `inject.sh` 注入驗證測試會變紅（0.5–1 天）。
    3. 先量再優化：大量紀錄實測（例：2,000 筆×300 樣本），同時看 `@MainActor` 的 UI 卡頓（0.5 天）。**速度目前完全未量。**不夠快才考慮請 Kit 加「摘要版 precheck」——那是 Kit 改動，走鐵律 3／8 回報，不得在 App 內繞道。
- 待定（PM 10/07 已記）：地圖與頂部統計是否跟著篩選。
- 需 18 語字串＋`ui-verify`。**估時 3–4 天**（含上列條件；若需 Kit 改動不含在內）。

## 三、B 組（PM 10/26 新增）

### B1 詳細頁 GPS 座標可點 → 跳地圖頁並置中

- **現況（已查證）**：座標列是純文字，無點擊行為（`DiveLogDetailView.swift:223`，`DetailRow`）；`Views/Map/DiveSiteSheetView.swift:242` 有同款座標列。分頁狀態是 `MainTabView` 的本地 `@State`（iOS `selectedTab`，macOS `sidebarSelection`），詳細頁碰不到。
- **可重用機制**：`DiveMapRepresentable._updateMapView` 已有「選取＋置中」（`selectedDive`、`lastCenteredID`、`setCenter`），註解寫「支援未來 list→map 跳轉」。
- **做法**：environment 注入一個共用的「地圖跳轉請求」物件；詳細頁寫入目標潛水，`MainTabView` 切到地圖分頁，`MapView` 出現時讀取請求並置中（需處理 TabView 內容延遲建立、macOS 側欄切換兩平台）。座標列加 accessibility hint（18 語）。在地圖頁內的卡片（`DiveSiteSheetView`）點座標時只置中、不切分頁。
- **相依**：目標潛水若被聚合在群組內，置中後看不到單獨大頭針 ⇒ 與 B2 同批。
- **App 家族對照（總指揮 10/26）**：App-u 詳細頁座標也只是文字；App-i 是內嵌小地圖；家族無規格 ⇒ Logbook 自行設計。
- **估時 0.5–1 天。**

### B2 同座標 2 筆以上聚合後無法點開

- **成因（讀碼推斷，⚠️ 未在模擬器重現）**：點聚合徽章時只做 `mapView.showAnnotations(cluster.memberAnnotations, animated: true)`（`DiveMapRepresentable.swift:54-56`）。成員座標相同時框住範圍是一個點，縮放後仍然疊在一起、MapKit 仍聚合 ⇒ 點了無反應。
- **家族狀況**：App-u 同一寫法（`JD2UltraPhone/UI/Map/DiveMapRepresentable.swift:53-54`），依讀碼推斷同病；家族查無「同座標無法拆開」紀錄。Logbook 修完後依鐵律 8 **回報總指揮**，由他評估 App-u 是否跟進。
- **建議解法**：偵測聚合成員重疊時**不縮放，改列出該位置的潛水清單**讓使用者選——iOS 底部卡片、macOS 側欄；點一筆進現有 `DiveSiteSheetView`。同時解決 B1「目標被聚合」的問題。
- **不建議**：jitter（把重疊點錯開）——地圖會顯示不存在的位置，對潛點資料有誤導風險。
- **「幾公尺內算同一點」的門檻**：**不自己編**（艦隊規則：每個數值要有出處，否則標「本專案決定」並寫理由）。先在模擬器實測 MapKit 在最大縮放下是否仍聚合，再定。
- 需 18 語字串、兩平台、`ui-verify`。**估時 1–1.5 天。**

## 四、C 組：其餘小項（順手帶）

| 項目 | 位置 | 估時 | 備註 |
|---|---|---|---|
| 換用 v5 新 App Icon | `Assets.xcassets/AppIcon.appiconset`（只換 4 個檔，`Contents.json` 不動） | 0.25 天 | 來源 `_JD2-family/brand-assets/ICON_v5/`；詳見 HANDOFF；不手改圖檔 |
| 匯入頁格式清單補 ATMOS FIT | `ImportWizardView.swift:281-306` | 0.25 天 | 補完需 PM 重拍 macOS 匯入頁截圖 |
| "Manual Entry" 走在地化 | `DiveLogDetailView.swift:496` | 0.1 天 | catalog 已有鍵 |
| 4 處 `.minimumScaleFactor` 改 `ViewThatFits` | `DiveLogListView.swift:307,313`、`DiveRowView.swift:114`、`ImportWizardView.swift:694` | 0.5 天 | 與 v1.2 截圖對照 |
| 清理 `%lld%%`（stale） | `Localizable.xcstrings` | 0.1 天 | build 前後 `git diff --stat` 防 reflow |
| 「原始匯入資料」6 個鍵名補 18 語 | `cns`／`minPPO2`／`maxPPO2`／`altitudeRange`／`decoRequired`／`gasSwitches` | 0.5–1 天 | `gasSwitches` 值是 JSON 需整理 |
| GDPR／UMP 同意流程 | — | 2–3 天 | PM 10/05 裁示延下一版；本次未點名優先 |

## 五、不在本計劃內

- **多氣體換氣重放**（PM 10/10 B：排 v1.4）：需 DiveKit 支援，屬跨 repo，須回報總指揮，未估時。
- **驗 App-i 紀錄簽章**：排 v1.4 之後、不急（見 HANDOFF）。
- **第三方 SDK 的 Required Reason API**：送審前重查（見 HANDOFF）。

## 六、待 PM 裁示

| # | 決定 | 我的建議 |
|---|---|---|
| D1 | A1：編輯頁 Picker（`DiveLogEditSheet.swift:501`）要不要提供「未記錄」選項 | ✅ 10/26 裁示：提供；手動新增預設未記錄（PM 10/26 於本 session 確認） |
| D2 | A1：既有舊資料不回溯，維持顯示「海水」 | ✅ 10/26 裁示：不回溯（同上） |
| D8 | A1 衍生：編輯頁選「高海拔」不改 `surfacePressureBar`，重放仍用 1.0 bar（會低估組織負荷；`DiveLogEditSheet.swift:504`）——只靠揭露，還是另做處理 | ✅ 10/26 裁示（PM 確認）：移除 Altitude 選項、改由 `surfacePressureBar < 0.95` 推導顯示；既有 altitude＋1.0 bar 紀錄重放判不支援（A3 篩選共用閘門）。見決策檔 §四之二；A1 估時再 +0.5 天 |
| D3 | A2：潛伴／標籤用 A2-1（搜 JSON 文字）或 A2-2（新增欄位）；「潛點名稱」是否就是 `location` | 先 A2-1。**✅ PM 10/26 裁示採納總指揮建議（轉述）**：家族無 buddy／tags 正式欄位計畫（方案 b 只准 App-lb 加備註／地點）⇒ 同意 A2-1，但須**解析 JSON、只比對指定鍵的值**，不做原始文字搜尋（搜「buddy」會命中鍵名）；潛點名稱＝`location`（家族 schema 無 site 欄位）。附帶：趁 A1 把 v1.3 立成 `VersionedSchema` V1（全艦隊 0 先例），估工分開列交 PM 選；見 `docs/decisions/D-2026-10-26-v1.4-D3至D7裁示.md` |
| D4 | A3：組織負荷篩選採總指揮方案 B（共用 Kit `precheck`） | 同意；先量效能（2,000 筆×300 樣本，含主執行緒卡頓）再定 Kit。**✅ PM 10/26 裁示採納（轉述）**：高海拔閘門放 App 層 OK，但詳細頁與篩選**呼叫同一個判定函式**，一致性測試含 altitude＋1.0；見 `docs/decisions/D-2026-10-26-v1.4-D3至D7裁示.md` |
| D5 | A3：地圖與頂部統計是否跟著篩選 | ✅ PM 10/26 裁示：**統計與地圖維持全部紀錄、不跟篩選**（同 App-u 現況）；見 `docs/decisions/D-2026-10-26-v1.4-D3至D7裁示.md` |
| D6 | B1：跳轉後「只置中」或「置中＋選取大頭針（彈出卡片／側欄）」 | 置中＋選取（沿用現成機制）。**✅ PM 10/26 裁示採納（轉述）**：同意；App-u 無座標跳轉，無先例要對齊；見 `docs/decisions/D-2026-10-26-v1.4-D3至D7裁示.md` |
| D7 | B2：重疊判斷 | **✅ PM 10/26 裁示採納總指揮建議（轉述）**：不錯開圖釘、改列清單；**不用距離門檻**，只用兩個事實——①聚合成員座標完全相同，或②地圖已到最大縮放仍是聚合點 ⇒ 列清單，否則照現在放大。實測 MapKit 行為後寫進決策檔；App-u 同病，定案後總指揮排跟進；見 `docs/decisions/D-2026-10-26-v1.4-D3至D7裁示.md` |

## 七、查證狀態與未驗證事項

- 已核對（本 session 讀碼／指令）：`DiveLog.swift` 環境與欄位、`DiveReplayInput.swift` 環境註解與 `precedingDives`、`DiveLogListView.swift:43-44`、`DiveMapRepresentable.swift:54-56`、`MainTabView` 分頁狀態、`DiveReplay.swift` 的 `precheck`／`return .anomaly`、Kit 內 `environmentType` 命中點。
- **未核對**：總指揮轉述的家族 decisions／App-u／App-i 檔案行號（他自己註明「未實機重現任何一項」）；`replayInput` 映射全部剖面樣本的成本；`DiveAnalysisView.swift:174-177` 的支援／不支援裁示。
- **未重現**：B2 的聚合成因；使用者資料中是否實際存在同座標多筆。
- **未量測**：A3 的效能。
- 所有估時為推估。

## 八、開工前置

1. `bash /Users/kevin/Documents/AppProject/_JD2-family/scripts/run_tests.sh logbook`，對照 171／0／1（只允許那一支 StoreKit 測試 skipped）。
2. 讀 `_JD2-family/decisions/` 有無新增的相關「生效中」裁示。
3. 每項改動後 `git diff --stat` 檢查 `Localizable.xcstrings` 是否被 Xcode 重排；改 code 後先停下等 PM build 確認再 commit（專案慣例）。
