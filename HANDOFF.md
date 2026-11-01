# HANDOFF — JD2-Logbook

> 交接文件（固定檔名滾動式；前一版在 `docs/handoff-archive/HANDOFF_2026-10-27.md`，更早的在同目錄）。

## 交接時間
2026-11-01 10:45（產生方式：/handoff skill）

## 目前狀態
- **所在里程碑**：v1.4 開發中（v1.3 Build 4 已上架）。A1 ✅、A2 ✅、D-A ✅、D-C ✅、A3 列表篩選 ✅（11/01，578bd71＋4adfa19）；
  **B1＋B2 程式完成、iOS 模擬器實測完成（修 1 個空白卡片 bug）、macOS 未測、未 commit**；C 未做。進度：`docs/V1_4_WORK_PLAN.md`（已同步）；稽核：`docs/V1_4_AUDIT_TEST_PLAN.md`（F1–F21，F20 已撤回）。
- **未 commit 變更（B1＋B2）**：
  - 新檔：`Views/Map/MapFocusRequest.swift`（跨分頁「在地圖上顯示」請求）、`Views/Map/DiveSiteClusterList.swift`（拆不開的聚合點清單）、`JD2-LogbookTests/MapClusterAndFocusTests.swift`（5 支）。
  - 修改：`MainTabView.swift`（注入請求、收到就切地圖分頁）、`MapView.swift`（處理請求、清單狀態、iOS 卡片 `IOSMapSheetContent`／macOS 面板）、
    `DiveMapRepresentable.swift`（點聚合點：座標全同或已無法再放大 ⇒ 列清單，否則放大；首次 fit 不蓋掉跳轉目標）、
    `DiveLogDetailView.swift`／`DiveSiteSheetView.swift`（座標列可點）、`Localizable.xcstrings`（+2 鍵：`Show on Map`、`Dives at This Site`，英／繁中／日草稿）。
  - 文件：本檔、歸檔、`V1_4_WORK_PLAN.md`、`CHANGELOG.md`、`D-2026-10-26-v1.4-D3至D7裁示.md`（實作方式）。
- **測試**：上次提交時 `run_tests.sh logbook` **228／0／1**（唯一允許的 skip＝`PurchasePriceDisplayTests.testPremiumPriceStringIsNilWhenProductNotYetLoaded`）。
  **B1＋B2 加 5 支後：233／0／1 ✅**（11/01，`MapClusterAndFocusTests` 5/5 過；唯一 skip 同上；xcstrings diff 仍只有 +60 行）。
  第一輪 232／1／1：`testFocusRequestIsTakenOnce` 釋放 `MapFocusRequest` ⇒ SIGABRT（`JoyDive²-2026-11-01-154714.ips`，
  `swift_task_deinitOnExecutorMainActorBackDeploy`，與 `AppLanguageManager` 同一陷阱）⇒ 測試改用 static 共用實例，App 程式碼未動。
  （同型的 `UserLocationProvider` 自 v1.1 起由 `MapView`／`SettingsView` 的 `@State` 持有、會隨畫面釋放，上架至今無當機回報 ⇒ 推論只有 XCTest 環境會崩；**未在 App 內實證**。）
- **共用層**：DiveKit **v9.8.0**、DiveImportKit **v0.8.2**（local path、無版本鎖定；`check_doc_version_sync.sh` 通過；11/01 `describe --tags` 核對）。
- **已裁示的決策檔**（`docs/decisions/`）：環境欄位未記錄、D3–D7 裁示、D-A 聯合提案、D-C 聯合提案、**`D-2026-11-01-A3-列表篩選規格.md`**（App-u 照此做）。

## 進行中的決策（尚未定案）
- **D-B**：手動新增要不要加潛伴／標籤欄位（會動 schema → V1_5）。未裁示。
- **D-E**：搜尋 2,000 筆每鍵 30–38 ms（> 16 ms，本專案門檻）。建議先記已知限制。未裁示。
- **F17／F18／F19／F21**（既有，非 v1.4）：PM 10/27 另行排程，現在不處理。
- **A3「計算中…」列**：只驗到程式邏輯＋測試，未截到圖（2,000 筆 1–2 s 即完成）。PM 未表示是否要補（可加 DEBUG 延遲再截）。
- **文案**：A1、D-A、A2、A3、B1／B2 新字串皆為草稿（英／繁中／日）；⏸ 上架前收尾＋其餘 14 語（PM 10/26）。

## 下一步（按順序）
1. ✅ **B1＋B2 測試 233／0／1**（11/01）。開場重跑對照即可；跑完看 `git diff --stat -- JD2-Logbook/JD2-Logbook/Localizable.xcstrings` 應只有 **+60 行**（數萬行＝Xcode 改寫，見陷阱第 1 條）。
2. ✅ **iOS 模擬器實測 B1／B2**（11/01，`JD2-LB-Audit`）：結果與截圖已寫回 `docs/decisions/D-2026-10-26-v1.4-D3至D7裁示.md`「MapKit 實測結果」；截圖 `docs/screenshots/v1.4-B/00–07`。
   - 實測抓到並修好：iOS 清單卡片第一次打開空白 ⇒ `MapView.swift` 卡片內容改 `IOSMapSheetContent`（Binding）。修後重跑測試 **233／0／1**、xcstrings 仍 +60 行（11/01）。
   - **待 PM 裁示**：B1 跳轉沿用 recenter span 0.05°，Komodo 目標仍在聚合點裡、看不到單一圖釘（截圖 02）。是否改成「框住目標」放大由 PM 決定。
   - **未做**：macOS 實測（audit bundle ID，陷阱第 3 條；側面板清單要「全螢幕控制」授權）；`ui-verify` 表格已在對話中回報（iOS）。
   - 模擬器資料已改：Banana Reef PK 46、12 座標＝PK 96；PK 88 經度＝PK 105 +1e-6。保留供 macOS／App-u 比對；不需要時重新注入假資料即可。
3. **等 PM build 確認後 commit＋push**（逐檔 add、閘門照陷阱第 2 條）。
4. **依鐵律 8 回報總指揮**：App-u 同寫法（`JD2UltraPhone/UI/Map/DiveMapRepresentable.swift:53-54`），同座標聚合點應同病；附 Logbook 做法與實測結果，由總指揮評估跟進。
5. **v1.4 剩餘**：C 組小項（`docs/V1_4_WORK_PLAN.md` §四）。
6. **待 PM 手動**：iOS 模擬器文字輸入（T4、T27、T28）。

## 陷阱提醒
- 🆕 **Xcode 開著時 build 可能整份改寫 `Localizable.xcstrings`**（11/01：差異 3.6 萬行，改成 ` : ` 分隔、重排鍵、加入 `""`、`" *"` 等自動擷取空鍵）。
  不是本次改動 ⇒ **不得提交**：`git checkout -- <xcstrings>` 還原後，再用 Python `json.dumps(..., ensure_ascii=False, indent=2, separators=(',', ': '))` 加鍵（先斷言讀寫往返不變）。
  commit 前必看 `git diff --stat` 只有新增行。
- **提交閘門**：bash 腳本（`bash -euo pipefail`）串機敏掃描（附對照樣本）＋`check_doc_version_sync.sh`，失敗就停；**逐檔 `git add`**。
  ⚠️ **zsh 不拆 `$var`、會展開 `--include=*.swift` 的 glob** ⇒ 11/01 兩次量具回 0（一次 commit 加檔失敗、一次 grep 計數）——檔案清單與 grep 一律在 `bash` 裡跑，並看「掃描行數 > 0」。
- **macOS 實測不得用正式 bundle ID**：PM 這台 Mac 的 `~/Library/Containers/com.jd2logbook.JD2-Logbook` 是 v1.3 真實資料。
  `xcodebuild … PRODUCT_BUNDLE_IDENTIFIER=com.jd2logbook.JD2-Logbook.audit CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=`，`defaults read <app>/Contents/Info CFBundleIdentifier` 確認，測前測後比對真實 store SHA-256。
  macOS 下拉選單（篩選選單等）背景模式點不開 ⇒ 要「全螢幕控制」授權；**授權視窗可能被蓋住，PM 第一次沒看到、逾時**，申請前先請 PM 留意。
- **iOS 模擬器截圖慢一步**：截圖常是上一個動作前的畫面，判斷前多截一張；剛 launch 後第一次點擊常不生效。1–2 秒內就結束的狀態（如「計算中…」）抓不到——別一直重試。
- **iOS 模擬器文字輸入**三種方式都進不了欄位 ⇒ 不要再試。改 App 語言用 App 內選單。
- **改模擬器資料**：先 `simctl terminate`、`PRAGMA wal_checkpoint(TRUNCATE)`、備份 `default.store*`；`simctl get_app_container` 每次重新取（重新安裝後路徑會變）。
- **Kit 可能未通知就更新**：開工前 `git -C ../_JD2-family/DiveKit describe --tags`、`DiveImportKit` 同。
- 假資料剖面 JSON 鍵 `t`／`d`／`w`；氣體 JSON `"air"`／`{"nitrox":{"fO2":0.32}}`／`{"trimix":{"fO2":..,"fHe":..}}`。
- 測試中不得釋放任何 `@MainActor @Observable` 類別（`AppLanguageManager`、`MapFocusRequest`…，SIGABRT）⇒ static 共用實例；
  某支測試 0.000 秒「failed」且其餘測試換了 pid ＝當機，去 `~/Library/Logs/DiagnosticReports/JoyDive²-*.ips` 看堆疊（xcodebuild 還會再卡 10 分鐘收診斷）；測試用到 Kit 型別要 `import DiveKit`（否則 MemberImportVisibility 編譯失敗，`run_tests.sh` 回 INVALID）。
- `inject.sh` 需乾淨工作樹 ⇒ 先 commit 再注入。

## 專用模擬器與測試資料（可刪）
- iOS：`JD2-LB-UpgradeTest`、`JD2-LB-Upgrade-v10／v12／v13`（T1–T3）、`JD2-LB-Audit`（105 筆；第 5 筆「T12 未記錄」11/01 實測後氣體標記為 `user`；App 內語言日文）。
- macOS：`~/Library/Containers/com.jd2logbook.JD2-Logbook.audit`（audit 版獨立資料，可整個刪除）。
- 截圖：`docs/screenshots/v1.4-A1/`、`v1.4-A2/`、`v1.4-audit-sim/`、`v1.4-A3/`（01–14）、`v1.4-B/`（00–07）。

## 開場指令建議（給下一個 session）
先讀本檔、`docs/V1_4_WORK_PLAN.md`（B 組）、`docs/decisions/D-2026-10-26-v1.4-D3至D7裁示.md`（D6／D7）；
確認 Kit 版號：`git -C /Users/kevin/Documents/AppProject/_JD2-family/DiveKit describe --tags`（v9.8.0）；
`git status` 應看到上列 B1＋B2 未提交檔案；跑 `run_tests.sh logbook` 對照 **233／0／1**（11/01 已達成），再看「下一步」第 2 項待 PM 裁示與 macOS 實測。
