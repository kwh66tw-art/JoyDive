# HANDOFF — JD2-Logbook

> 交接文件（固定檔名滾動式）。前一版（含已結案項目的完整敘述）：`docs/handoff-archive/HANDOFF_2026-11-04_2.md`。

## 交接時間
2026-11-04 22:00（產生方式：/handoff skill；PM 指示「更新文件、交接，壓縮文件後再推送」——本版為精簡版）

## 目前狀態
- **里程碑**：v1.4 開發中（v1.3 Build 4 已上架）。功能面全部完成：A1／A2／A3、D-A／D-C、B1／B2／B1-A、搜尋收合（B 案）、C 組；GDPR ⏸ 下一版（PM 10/05）。
  進度：`docs/V1_4_WORK_PLAN.md`；稽核：`docs/V1_4_AUDIT_TEST_PLAN.md`；**送審前待辦：`docs/SUBMISSION_CHECK_NEXT.md` 最上段**。
- **git**：本交接提交並推送後工作樹乾淨、與 origin/main 相同（hash 以 `git log -1` 為準）。
- **測試**：`run_tests.sh logbook` **249／0／1**（Kit v0.8.3，11/04 CH-23 修正後；唯一 skip＝`PurchasePriceDisplayTests.testPremiumPriceStringIsNilWhenProductNotYetLoaded`）。
- **共用層**：DiveKit **v9.8.0**、DiveImportKit **v0.8.3**（v0.8.3＝Diving Log 備註 RTF 修正，91b960f）；`check_doc_version_sync.sh` 通過。
- **決策檔**（本週）：`docs/decisions/D-2026-10-26-v1.4-D3至D7裁示.md`（B1／B1-A）、`D-2026-11-01-A3-列表篩選規格.md`、`D-2026-11-04-DB-DE已知限制與F-09複數形實驗.md`、`D-2026-11-04-搜尋收合成按鈕.md`。

## 進行中的決策／排隊（尚未定案）
- **App-u 的 B2 跟進**：總指揮與 PM 處理，本 repo 不動。
- **「一個潛點一根圖釘」**：待辦，卡在「同一潛點」判定（見 D3–D7 決策檔 B1-A 節）。
- **F17／F21**：PM 10/27 另行排程（F18／F19 已於 11/05 v1.4 送審收尾修正）。
- **已匯入的 Diving Log 舊備註 RTF 殘留**：PM 11/04 裁示不自動清理（`docs/KNOWN_ISSUES.md`）。

## 下一步（按順序）
1. **送審前待辦**（`docs/SUBMISSION_CHECK_NEXT.md` 最上段）：
   - **TestFlight 覆蓋升級首次啟動是否卡住**（PM 11/04 用 Xcode 裝到 iPhone 16 時卡 10–20 秒、重開不卡）。候選：Xcode 偵錯器、Debug 建置、首次遷移（lightweight，可能性低）。仍卡 ⇒ 先在 Release 實機用 Time Profiler／`os_signpost` 量測，再提案。
   - ~~PM 重拍 macOS 匯入頁上架截圖~~ ✅ PM 11/05 確認 OK。
   - **翻譯審稿（PM）**：11/05 已補 16 鍵 × 14 語草稿＋`+%lld more` 依數量變形（18 語）；C 組 8 鍵草稿維持。審稿表 `docs/reports/R-2026-11-05-v1.4翻譯審稿對照表.md`；**PM 審完才把 `needs_review` 改 `translated`**。
     - zh-Hant「最高／最低 PO₂」（紀錄值）與 App-i「PO₂ 上限」（設定上限）**刻意不同，不要統一**。
   - What's New v1.4 三語草稿待 PM 定稿（`docs/APPSTORE_COPY.md`）。
2. **v1.4 送審準備**：版號 ✅ 1.4（5）（11/05，Release 產物已驗）；F18／F19 ✅；其餘照 `app-store-submission-guide` 與 `SUBMISSION_CHECK_NEXT.md` 逐項查證。⚠️ `CLAUDE.md`「下次發布流程」仍寫「目前 4、下次 5」，改 CLAUDE.md 要 PM 直接同意。
3. （可選）macOS 兩格未驗：「選取中按回到我的位置」、「GPS 開著冷啟動」——需 PM 先確認 audit App 定位授權。
4. 待 PM 手動：iOS 模擬器文字輸入（T4、T27、T28）。

## 陷阱提醒（精簡；細節與真實案例見前一版歸檔）
**流程／閘門**
- 提交前跑 bash 閘門（`bash -euo pipefail`）：機敏掃描附對照樣本＋`check_doc_version_sync.sh`；逐檔 `git add`；零命中的 grep 用 `{ grep … || true; }`。zsh 不拆 `$var`、會展開 `--include=*.swift`、沒有 `PIPESTATUS` ⇒ 一律寫成腳本檔用 bash 跑（內嵌引號易壞）。
- 提交前故障注入只能手動（`inject.sh` 要乾淨工作樹）：恰好命中 1 次、備份＋SHA 還原、`run_tests.sh --only`；FAIL 但 failed=0／無 RESULT 一律 ABORT。只測判斷函式會漏掉呼叫路徑。
- 暫時 log／DEBUG 預填一律用備份覆蓋撤回，撤完 build＋`grep` 0 處再測。
- 推送、電腦操作、改 `CLAUDE.md`：要 PM 在本 session **直接**同意（總指揮轉述不算）。
- Kit 可能未通知就更新：開工前 `describe --tags` 兩個 Kit。
- 🔴 生產碼不得建構 `.trimix(`（CH-23 `check_trimix_boundary.sh`，用途不分顯示或計算；白名單要 PM 裁示）——要 trimix 名稱用 `GasMix.percentText` 組字串。提交前跑一次該腳本。

**xcstrings**
- Xcode 開著 build 可能整份改寫 ⇒ 不得提交。加／刪鍵：HEAD round-trip 逐位元相同後用 `json.dumps(indent=2, separators=(',', ' : '), ensure_ascii=False)`＋空物件 `{\n\n<indent>}`；鍵序依 `localizedStandardCompare`。
- 插很多鍵時預設 `git diff --numstat` 有對齊假象 ⇒ 用 `--diff-algorithm=patience`，再以 JSON 對 HEAD 比舊鍵順序與內容。

**iOS 模擬器**
- 文字輸入（貼上、鍵盤按鍵）都進不了欄位 ⇒ 用暫時 DEBUG 啟動參數預填，截完移除。
- 截圖常慢一步；剛 launch 後第一次點擊常不生效；詳細頁捲到底會回彈（DisclosureGroup 因此點不開，**實機正常**），等停住再點。
- `simctl spawn … defaults write` 寫的是模擬器全域，不是 App 沙盒 ⇒ shutdown 後用 `plistlib` 改 container plist。
- 改模擬器資料：terminate、`PRAGMA wal_checkpoint(TRUNCATE)`、備份 `default.store*`，用完還原。
- App 的 `print` 拿不到 ⇒ 暫時改 `NSLog`，用 `simctl spawn <udid> log show --predicate 'eventMessage CONTAINS "…"'` 讀。
- Xcode 27.2（11/04 自動更新）第一次 xcodebuild 會自動裝模擬器元件，之後才正常。

**macOS**
- 實測只用 audit bundle ID（`com.jd2logbook.JD2-Logbook.audit`、`CODE_SIGN_IDENTITY=-`…），測前測後比對正式 store SHA-256。
- 地圖標註與選單點不到背景點擊 ⇒ 需全螢幕控制；全螢幕截圖會拍到 PM 的 Dock／桌面，入庫前裁成 App 視窗。
- 工具列：父子 view 各宣告一組時子組固定排後 ⇒ 要固定順序就放同一個 `ToolbarItemGroup`（`macToolbarExtras`）。
- NSLog 會被遮成 `<private>` ⇒ 直接執行 `.app/Contents/MacOS/JoyDive²` 並把 stderr 導到檔案。

**MapKit／SwiftUI／測試**
- 聚合貼邊仍會聚合、剛切到地圖分頁時聚合還沒算；不要用自訂門檻或計時去追。動畫 `setCenter` 會取消進行中的 `setVisibleMapRect`。套用範圍會因安全區調整 ⇒ `mapRectThatFits`。
- sheet 閉包讀到舊的 `@State` ⇒ 用 Binding 傳進子 View。
- 測試中不得釋放 `@MainActor @Observable` 類別 ⇒ static 共用實例；測試用到 Kit 型別要 `import DiveKit`。

## 專用模擬器與測試資料（可刪）
- iOS：`JD2-LB-Audit`（105 筆，App 內語言日文、GPS 未開）、`JD2-LB-B1-SE`（SE 3，資料同稽核機）、`JD2-LB-FreshInstall`（11/04 全新安裝測試，0 筆）、`JD2-LB-UpgradeTest`、`JD2-LB-Upgrade-v10／v12／v13`（T1–T3）。全部關機。
- macOS：`~/Library/Containers/com.jd2logbook.JD2-Logbook.audit`（104 筆，11/04 測後由備份還原）。
- 截圖：`docs/screenshots/` 下 `v1.4-A1`、`v1.4-A2`、`v1.4-audit-sim`、`v1.4-A3`、`v1.4-B`（00–55）、`v1.4-search`（含 README）、`v1.4-C`（含 README）。

## 開場指令建議（給下一個 session）
先讀本檔與 `docs/SUBMISSION_CHECK_NEXT.md` 最上段；確認 Kit 版號（DiveKit v9.8.0、DiveImportKit v0.8.3：`git -C /Users/kevin/Documents/AppProject/_JD2-family/<Kit> describe --tags`）；`git status` 應乾淨；跑 `run_tests.sh logbook` 對照 **249／0／1**；再向總指揮確認下一項（送審準備或 App-u 跟進）。
