# HANDOFF — JD2-Logbook

> 交接文件（固定檔名滾動式；前一版在 `docs/handoff-archive/HANDOFF_2026-11-01.md`，更早的在同目錄）。

## 交接時間
2026-11-04 10:30（產生方式：/handoff skill）；**14:50 追加「B1-A 進行中」一節（PM 暫離，模擬器已由 PM 關機）**

## 🆕 B1-A 進行中（14:50，未提交；PM 裁示 B1-A 全做＋GPS 根因修正併入）
- **程式（未提交）**：`Views/Map/DiveClusterLabel.swift`（規則 ①–④）、`DiveMapRepresentable.swift`（聚合點標題／副標「+%lld more」／含選取＝藍色；選取或語言變更重加標註；**focus 縮放區塊設 `lastCenteredID = targetID`**，修「動畫 setCenter 4 ms 後蓋掉縮放」）、`Services/UserLocationProvider.swift`（只有按按鈕後的授權回呼才定位）、測試 `DiveClusterLabelTests`（7/0/0）、`UserLocationAuthorizationTests`（3/0/0）。
- ⚠️ **`DiveMapRepresentable.swift` 仍含暫時 log**（`TEMP-S2`、`NSLog("[S2] …")` 3 處）。乾淨版在 scratchpad `DMR.B1A.v1.swift`（14:45 已 diff：只差 log，含 setCenter 修正）；scratchpad 若已消失，就**手動刪掉那 4 段**（`regionDidChangeAnimated`＋`s2Dump` 整段、3 行 NSLog），刪完先 build。
- **字串檔已依總指揮裁示重做**：從 HEAD 取原檔、Xcode 格式（`separators=(',', ' : ')`、空物件 `{\n\n<indent>}`；HEAD round-trip 逐位元相同）只加 2 鍵（`+%lld more` index 14、`Multiple Dive Sites` index 130，順序＝`localizedStandardCompare`）。`git diff --stat` **+60/−0**；兩個 stale 標記維持 HEAD。**不另開格式還原提交**。
- **已驗（17 Pro）**：截圖 `docs/screenshots/v1.4-B/27–30、34、37`（B1-A）、`31–33、35、36`（GPS）、`38、40、41`（setCenter 修正：log 只有 FOCUS、無 SELECT setCenter）、`39`（規則 ③）、`42`（B2 清單選第 2 列 ⇒「3」變藍＋標題）。SE：`43`（世界地圖日文規則 ③）。
- **15:40 更新**：① SE 已驗（43–46）② 暫時 log 已撤（grep 0；對照樣本 4）、iOS＋macOS build 成功 ③ `run_tests.sh logbook` **243/0/1** ④ 決策檔已補（B1-A／GPS／setCenter／字串檔事件／多尺寸 Banana Reef 補記）⑤ 已送總指揮驗收。
- **16:10 更新**：macOS 已驗（47–55，PM 直接授權；正式 store SHA 不變、audit store 已還原）；提交前故障注入 I1／I2a RED、I2b GREEN ⇒ 補回呼路徑測試（`handleAuthorizationChange`）後 I2b′ RED；`run_tests.sh logbook` **245/0/1**；iOS＋macOS build 成功；稽核機 App 語言已改回日文（container plist，模擬器已關機）。
- **提交**：PM「直接做完」＋總指揮驗收後分兩次逐檔提交（程式／文件＋截圖）。**未推送**——推送等 PM 明確指示。
- **陷阱（新）**：`inject.sh` 只能在乾淨工作樹跑、`run_tests.sh logbook` 只測主 checkout ⇒ 提交前注入只能手動照搬守衛（見決策檔「故障注入」節）。`simctl spawn … defaults write` 寫的是模擬器全域偏好、**不是 App 沙盒**；改 App 設定要關機後改 container 內的 plist。macOS 地圖標註點不到背景點擊（無 AX 動作），要全螢幕控制。
- **模擬器狀態**：兩台已關機（PM 14:43 關）。稽核機 App 語言目前 zh-Hant，收尾要改回日文；GPS 設定已還原。地圖右上地球鈕＝切換地圖類型（衛星），不是縮放。

## 目前狀態
- **所在里程碑**：v1.4 開發中（v1.3 Build 4 已上架）。A1 ✅、A2 ✅、D-A ✅、D-C ✅、A3 ✅、**B1＋B2 ✅ 已提交並推送**（32e369e、212e606）；C 未做。
  進度：`docs/V1_4_WORK_PLAN.md`（已同步）；稽核：`docs/V1_4_AUDIT_TEST_PLAN.md`（F1–F21，F20 已撤回）。
- **未 commit 變更**：本次交接的文件（本檔、歸檔、`CHANGELOG.md`、`docs/V1_4_WORK_PLAN.md`）。程式碼工作樹乾淨（HEAD 212e606，已推送）。
- **測試**：`run_tests.sh logbook` **233／0／1**（11/04，總指揮重跑相同；唯一 skip＝`PurchasePriceDisplayTests.testPremiumPriceStringIsNilWhenProductNotYetLoaded`）。
- **共用層**：DiveKit **v9.8.0**、DiveImportKit **v0.8.2**（11/04 `describe --tags` 核對；`check_doc_version_sync.sh` 通過）。
- **B1／B2 的完整經過都在** `docs/decisions/D-2026-10-26-v1.4-D3至D7裁示.md`（MapKit 實測、A／H5 失敗紀錄、問題重新定義、根因追溯、依資料縮放三輪、多尺寸表）。截圖 `docs/screenshots/v1.4-B/00–18`（含 17b）。

## 進行中的決策（尚未定案）
- **B1「聚合點標題不固定」**（11/04 macOS 發現）：同一筆跳轉兩次，「2」的標題一次是目標名、一次是鄰居名（MapKit 原生聚合點取哪一筆不固定）。
  與 PM 確認的問題定義「讓使用者認得哪一筆是這筆，同時知道還有其他筆」直接相關。**總指揮正在與 PM 重新釐清，未裁示前不要動程式**。
  總指揮先前提過的候選：目標不拆出，改在含目標的聚合點上標示（目標色、標題用目標名稱＋「其他 N 件」）。
- **App-u 的 B2 跟進**（同座標聚合點點不開，`JD2UltraPhone/UI/Map/DiveMapRepresentable.swift:52-55`）：PM 裁示排隊；鐵律 8 已通報總指揮。
- **D-B**（手動新增要不要加潛伴／標籤欄位，動 schema）、**D-E**（搜尋 2,000 筆每鍵 30–38 ms）：未裁示。
- **F17／F18／F19／F21**：PM 10/27 另行排程，現在不處理。
- **文案**：A1／D-A／A2／A3／B1／B2／B1-A 新字串皆為草稿（英／繁中／日）；⏸ 上架前收尾＋其餘 14 語。
  - ⚠️ **上架前補語言待辦**：B1-A 的「+%lld more」用 `String(format:)` 帶數字、沒有複數形；克羅埃西亞語、希臘語等要依數量變化（F-09），而 Logbook 的 `languageManager` 路徑目前**不支援依數量選複數形**——補語言前先決定做法（見決策檔 B1-A 節）。

## 下一步（按順序）
1. **commit＋push 本次交接文件**（逐檔 add，閘門照陷阱第 2 條）——等 PM 指示。
2. **等總指揮／PM 對「聚合點標題不固定」的定義與解法**，再動 `DiveMapRepresentable.swift`。
3. **macOS 未測的一項**：B2 清單（座標完全相同的聚合點 ⇒ 右側面板列清單）。B1 的 macOS 已測（截圖 17、17b、18）。
4. **v1.4 剩餘**：C 組小項（`docs/V1_4_WORK_PLAN.md` §四）。
5. **待 PM 手動**：iOS 模擬器文字輸入（T4、T27、T28）。

## 陷阱提醒
- 🆕 **MapKit 聚合**：貼邊（兩圖釘距離＝圖釘大小）甚至多 1 個實體像素仍會聚合，另有未公開間距（三輪實測）；剛切到地圖分頁時聚合還沒算（`MKClusterAnnotation`＝0），在那一刻判斷「是否被聚合」會誤判。不要再用自訂門檻或計時去追。
- 🆕 **MapKit 套用範圍會因安全區調整**：iOS 分頁列（safeAreaInsets.bottom 83）讓實際縮放比要求大 12–16%；`mapRectThatFits` 先問再補償。macOS 無此問題。
- 🆕 **圖釘大小因裝置而異**：17 Pro 31.3×34.9 pt；iPhone SE 3 與 macOS 33.0×36.8 pt（成因未查）。從實際 view 讀，不寫死。
- 🆕 **macOS 的 NSLog 會被遮成 `<private>`**：要看數字就直接執行 `.app/Contents/MacOS/JoyDive²` 並把 stderr 導到檔案。zsh 的 `log` 是內建指令，要用 `/usr/bin/log`。
- 🆕 **撤暫時 log 用備份覆蓋，不要用正則刪**：11/04 正則多留一個 `}`，`run_tests.sh` 回 INVALID（編譯失敗）。撤完先 build 再跑測試。
- 🆕 **SwiftUI sheet 閉包讀到舊的 @State**：`.sheet(isPresented:)` 內容若讀了 body 沒讀過的 @State 會拿到舊值（卡片空白）⇒ 用 Binding 傳進子 View。
- 🆕 **測試中不得釋放任何 `@MainActor @Observable` 類別**（`AppLanguageManager`、`MapFocusRequest`…，SIGABRT）⇒ static 共用實例。某支測試 0.000 秒失敗且其餘換 pid＝當機，看 `~/Library/Logs/DiagnosticReports/JoyDive²-*.ips`（xcodebuild 還會再卡 10 分鐘收診斷）。
- **Xcode 開著時 build 可能整份改寫 `Localizable.xcstrings`**：不得提交；`git checkout -- <xcstrings>` 還原後用 Python `json.dumps(..., ensure_ascii=False, indent=2, separators=(',', ': '))` 加鍵。commit 前看 `git diff --stat` 只有新增行。
- **提交閘門**：bash 腳本（`bash -euo pipefail`）串機敏掃描（附對照樣本）＋`check_doc_version_sync.sh`，失敗就停；**逐檔 `git add`**。zsh 不拆 `$var`、會展開 `--include=*.swift` ⇒ 檔案清單與 grep 一律在 bash 跑。
- **macOS 實測不得用正式 bundle ID**：`PRODUCT_BUNDLE_IDENTIFIER=com.jd2logbook.JD2-Logbook.audit CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=`，測前測後比對正式 store SHA-256。電腦操作要 PM 在本 session **直接**授權（總指揮轉述不算）。
- **iOS 模擬器**：截圖常慢一步；剛 launch 後第一次點擊常不生效；詳細頁捲到底會回彈，等穩定再點座標列。文字輸入進不了欄位，不要再試。
- **改模擬器資料**：先 `simctl terminate`、`PRAGMA wal_checkpoint(TRUNCATE)`、備份 `default.store*`；`get_app_container` 每次重新取。
- **Kit 可能未通知就更新**：開工前 `describe --tags` 兩個 Kit。
- 測試用到 Kit 型別要 `import DiveKit`；`inject.sh` 需乾淨工作樹。

## 專用模擬器與測試資料（可刪）
- iOS：`JD2-LB-UpgradeTest`、`JD2-LB-Upgrade-v10／v12／v13`（T1–T3）、`JD2-LB-Audit`（105 筆；Banana Reef PK46、PK12 座標改成與 PK96 完全相同、PK88 經度＝PK105＋1e-6；第 5 筆氣體標記 `user`；App 內語言日文）、
  🆕 `JD2-LB-B1-SE`（iPhone SE 3，11/04 多尺寸驗證用，資料複製自稽核機）。
- macOS：`~/Library/Containers/com.jd2logbook.JD2-Logbook.audit`（audit 版，104 筆，已還原；視窗寬度停在 918 pt，下次開可手動拉回）。
- 截圖：`docs/screenshots/v1.4-A1/`、`v1.4-A2/`、`v1.4-audit-sim/`、`v1.4-A3/`（01–14）、`v1.4-B/`（00–18、17b）。

## 開場指令建議（給下一個 session）
先讀本檔、`docs/decisions/D-2026-10-26-v1.4-D3至D7裁示.md`（B1 各節）、`docs/V1_4_WORK_PLAN.md`；
確認 Kit 版號：`git -C /Users/kevin/Documents/AppProject/_JD2-family/DiveKit describe --tags`（v9.8.0）；
`git status` 應只看到本次交接的文件變更（或已提交）；跑 `run_tests.sh logbook` 對照 **233／0／1**；再向總指揮確認「聚合點標題」的裁示。
