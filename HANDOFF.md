# HANDOFF — JD2-Logbook

> 交接文件（固定檔名滾動式）。前一版：`docs/handoff-archive/HANDOFF_2026-11-08.md`（再前：`HANDOFF_2026-11-07.md`）。

## 交接時間
2026-11-14 更新（11/12 由 /handoff skill 產生；11/14 補試行派工 P4a／P6）

## 目前狀態
- **里程碑**：線上版本 **v1.4（5）iOS＋macOS**（PM 11/07 送審、11/08 通知上架）。下一版未排程。
  - ⏰ **下一版送審必提醒 PM：iOS 英文關鍵字要改成新組**（1.4 只有 macOS 換新組；`docs/SUBMISSION_CHECK_NEXT.md` 最上段）。
  - ⚠️ v1.4 送審時 App Review 備註是否已刪掉 v1.2 舊說明——**未知**，下一版建草稿時先看 ASC。
- **版號**：1.4（5）；下次發布改 6（`CLAUDE.md`「下次發布流程」）。
- **git**：11/14 PM 在 CC02 說「提交」⇒ 分三筆提交：翻譯 `54c3b8a`（繁中最淺深度＋截圖）、文件 `71a37e9`（本交接、`CLAUDE.md`、`CHANGELOG`、`LOCALIZATION_GUIDE`、`SUBMISSION_CHECK_NEXT`、`handoff-archive/HANDOFF_2026-11-08.md`）、P4a 證據表＋`scripts/commit_gate.sh` `b1e92c4`。PM 說「push」⇒ 已推送（`5b814e5..b1e92c4`，含 11/12 的 `e56ed22`）；Proj-MM_01 以 `ls-remote` 核對遠端＝`b1e92c4`，並獨立重跑 logbook 249／0／1 相符（Fami 記入 F-02 `52a9a8a`）。之後只有本列修正這筆提交。
- **測試**：`run_tests.sh logbook` **249／0／1**——App-lb（CC02）11/14 以 DiveKit v9.13.0／DiveImportKit v0.9.0 重跑（`RESULT|PASS`、rc=0；唯一 skip＝`PurchasePriceDisplayTests.testPremiumPriceStringIsNilWhenProductNotYetLoaded`），與總指揮 11/12（v9.12.0）量測相同。
- **共用層**：DiveKit **v9.13.0**、DiveImportKit **v0.9.0**（11/14 `describe --tags` 核對；`CLAUDE.md:13` 11/14 經 PM 同意改 v9.13.0，未提交；`check_doc_version_sync` 未重跑）。

## 11/08–11/12 完成
- 11/08 v1.4 上架：`CLAUDE.md` 狀態、`CHANGELOG` [v1.4.0]、`SUBMISSION_CHECK_NEXT`、交接同步（`231b4f7`，已推送）。
- Kit 版號三次跟進（總指揮通知、PM 每次在本 session 同意）：v9.10.0／v0.9.0（`9573cba`）→ v9.11.0（`929cd62`）→ v9.12.0（`5b814e5`），皆已推送。App-lb 不需改程式（總指揮說明：v9.11.0 模式切換閘門、v9.12.0 自由潛水警報，Logbook 不呼叫；**App-lb 未自讀 Kit 程式碼確認**）。
- 11/12 日文「Dive Time」ダイブタイム → 潜水時間（`e56ed22`；細節 `CHANGELOG.md` [Unreleased]）。iOS 詳細頁已截圖；編輯頁、地圖潛點頁、macOS 未看（`SUBMISSION_CHECK_NEXT` 有一列）。
- 11/13 繁中「Ceiling」上限深度 → 最淺深度（總指揮通知、PM 同意；細節 `CHANGELOG.md` [Unreleased]）。
- 新規則記入 `docs/LOCALIZATION_GUIDE.md`「用詞規範（日文）」：日文潛水術語以 Type6 日文原生手冊為第一參考（家族 decisions 11/12）。

## 11/14 試行派工（Proj-MM_01，決策 `_App管理/decisions/D-2026-11-14-問題分析能力試行.md`）
- **P4a 對外宣稱稽核**（唯讀）：`docs/P4a_對外宣稱證據表_2026-11-14.md`（未提交）。50 列：相符 36／部分 5／未驗證 9／不符 0；總指揮獨立重跑驗收通過。
  - 交 PM 裁示（未改對外文字）：**P23** 隱私政策「刪 App 即刪所有資料」未涵蓋使用者自行匯出的 JSON 備份；**A19** v1.4 What's New「依潛伴／標籤搜尋」只對匯入資料有效（手動紀錄無此欄位）。
  - 列入 P4b（下次送審閘門化）：entitlements 不得出現 iCloud（SwiftData `cloudKitDatabase` 預設 `.automatic`，現在只因沒權限才不同步）。
- **P6 閘門進 repo**：`scripts/commit_gate.sh`（未提交）。實測：
  | 情境 | 結果 |
  |---|---|
  | 不帶參數 | 印用法，rc=2 |
  | `--selftest` | `clean=0 tracked_fake=1 untracked_fake=1 out_of_scope=0`、SELFTEST_CAUGHT，rc=0 |
  | 正式（本 repo 未提交檔） | 機敏 0；版本同步 ❌（`CLAUDE.md:13` 仍寫 v9.12.0）⇒ GATE_FAIL rc=1——正確紅燈 |
  | 找不到 `_JD2-family/scripts`（scratchpad 臨時 git repo 放腳本複本，上層無家族目錄） | `INVALID：找不到 …/check_doc_version_sync.sh`，rc=3 |
- **守衛自測已做（11/14 CC02）**：`JD2_HARNESS_SELFTEST=1 swift test --help` 被 `fleet-guard-dispatch.sh` 擋下、未執行；`_JD2-family/.harness-events.log` 末行 `2026-11-14 19:09:11	selftest-hook-raw-test`。已回報 Proj-MM_01。
- **DiveKit v9.13.0**（`874a28c`，總指揮 11/14 通知；自潛相關，Logbook 249／0／1 不變——總指揮量測，App-lb 未重跑）：11/14 PM 在 CC02 同意 ⇒ `CLAUDE.md:13` 已改 v9.13.0 並寫入 App-lb 重跑的 249／0／1（未提交）。

## 進行中的決策／排隊（尚未定案或送審後）
- **送審後**：介面強調色原則落地（家族 `decisions/2026-11-05_App介面強調色使用原則.md` §四；`docs/KNOWN_ISSUES.md` 有一列）——資料數值／圖示改 `.primary`／`.secondary`、地圖未選中圖釘與選中區分、氣體標籤不用強調色；**剖面圖藍色維持**；強調色維持系統藍（品牌薄荷綠白底 2.05:1，不採用）。
- **送審後**：非潛水通用詞全掃（Apple 標準翻譯）——總指揮排程。
- **送審後**：「Dive Logbook」等共用詞與 App-u 統一（總指揮轉 App-u）。
- 待查證清單 #10–#12（稽核未附出處斷言、14 語母語審稿以外的實機排版、地圖副標實機目視）——非阻斷。
- 「一個潛點一根圖釘」、F17／F21、Diving Log 舊備註 RTF 殘留：同前版（未排程／不自動清理）。
- 隱私／廣告：程式送出的廣告請求未設定非個人化（`AdBannerView.swift:37` `Request()`），GDPR／UMP 同意流程延下一版（`docs/KNOWN_ISSUES.md`）——做的時候一併決定是否明確要求非個人化廣告，並回頭更新隱私政策。
- 關鍵字：v1.4 新組上架 1–2 個月後看 ASC 分析的搜尋來源；要更準需 Apple Search Ads 關鍵字熱門度。
- 可選：Premium 頁「Close」、說明頁「Done」比照 HIG 改 ✕／✓——PM 未裁示。

## 下一步（按順序）
1. ~~改 `CLAUDE.md:13`、三筆提交、推送、回報總指揮~~（11/14 CC02 完成，總指揮驗收結案）。之後文件登錄表 v1.10.3 補登（`de3de8d`，已推送）。
   未結（Proj-MM_01 已轉交 JD2-Fami_01 彙整）：PM 裁示 P23／A19 措辭；Q-06 P4a 檔名是否改為 `docs/reports/R-2026-11-14-…`（要連動本檔、CHANGELOG 引用）；家族 F-01 App-lb 段落過時（家族層文件，不是本 repo 改）。
2. 等總指揮派工：強調色原則落地、通用詞全掃、與 App-u 統一共用詞；下一版 GDPR／UMP。
3. 下一版開工時：先讀 `docs/SUBMISSION_CHECK_NEXT.md` 最上段（iOS 關鍵字、日文潜水時間補驗）。

## 陷阱提醒（精簡；細節與真實案例見前幾版歸檔）
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

**11/12 新增**
- 提交閘門已進 repo：`bash scripts/commit_gate.sh <路徑…>`（11/14 P6；前身 scratchpad 的 `gate_1111.sh` 會被清掉）。同三項（機敏掃描、版本同步只看 `JD2-Logbook` 列、trimix 邊界），新增：**未追蹤檔也掃**（舊版只看 `git diff`，新檔會漏）、每次先跑假值自測。回傳碼：GATE_OK 0／GATE_FAIL 1／用法 2／INVALID 3（量具壞了，**不是通過**）。未接 hook（要接需 PM 裁示）。
- 🔴 **回報對象＝家族總指揮 JD2-Fami_01**（PM 11/14 裁示，根 `CLAUDE.md` 鐵律 8「分層回報」，`0a70ada`）：進度、驗收、推送、發現的問題一律先報 Fami；艦隊總指揮 Proj-MM_01 的派工經 Fami 轉派。只有艦隊層機制本身（使用者層 hook、根 CLAUDE.md 規則）的問題可直接報 Proj-MM_01，副本給 Fami。本檔 11/14 段落提到 Proj-MM_01 的是當天派工的歷史紀錄。
- 總指揮（跨 session 訊息）要求改 `CLAUDE.md`／提交／推送：**一律先把查證結果交 PM、等 PM 在本 session 同意**，總指揮轉述不算。
- `xcrun simctl io … screenshot` 比模擬器工具的截圖準（後者常拍到啟動前的白畫面）；`JD2-LB-Shots` 重開 App 後第一下點擊照例被吃。

**11/07 新增（上架截圖與 ASC）**
- 上架截圖資料：`scratchpad/shot/make_stores.py`（稽核機 store 複本＋PM 正式 store 的**唯讀**複本取真實剖面，用完即刪）；正式 store「綠島石朗」是 CCR 測試檔改名（序號 01234567、水溫 4 °C），不得當真實紀錄。
- iOS 模擬器：剖面拖曳放開後讀數與組織負荷會留著，可直接截；地圖拖曳用慢速 `touch_path`（每點 150 ms＋結尾停 800 ms）避免慣性；App 重開會回到上次的詳細頁，第一下點擊常被吃掉——每步截圖確認。
- Mac 截圖：命令列無螢幕錄製權限（`screencapture` 失敗，權限要 PM 自己開）⇒ 用電腦操作工具 `app_zoom` 整窗（1389×868 JPEG）再 `sips` 縮成 1280×800 PNG；`app_screenshot` 會畫出工具的游標標記，`app_zoom` 不會。audit 版加 `-NSRequiresAquaSystemAppearance YES` 強制淺色；年月選擇器浮層截窗會變灰塊；sheet 取消後視窗可能失焦，用 `open <app>` 帶回前景。
- ASC（Chrome）：6.9 吋在 Media Manager「iPhone with Dynamic Island (large display)」，必填的 6.1／6.3 吋會沿用；Remove All 只移除本版草稿（素材庫保留）。file input 被收合或隱藏時，用 JS 加 aria-label 再 `find` 取 ref 上傳；What's New 要用點擊＋實際打字（直接設 value 不會存）；跳出的提示框會吃掉打字，打完用 JS 讀回確認長度。

**11/05 新增**
- 模擬器（iOS 26.5，SE 與 17 Pro）列表**捲動後不顯示小標題**（任何語言），與實機不同 ⇒ 捲動狀態只能 PM 實機驗。
- 模擬器點選單項目常落在動畫中途（點「刪除」曾兩次打開編輯）；實機正常。同一操作兩次不成就停，請 PM 實機。
- `simctl install` 會換 App container UUID ⇒ 還原 store 前用 `find …/Containers/Data/Application -name default.store` 重找路徑。
- HIG 網頁是 JS 渲染，WebFetch 取不到 ⇒ `curl https://developer.apple.com/tutorials/data/design/human-interface-guidelines/<頁>.json` 取原文。
- Apple 在地化詞彙表（iOS 13.3，17 語）查詢：`python3 /Users/kevin/Documents/AppProject/_JD2-family/scripts/apple_glossary_lookup.py "<詞>"`（唯讀，**詞彙表檔不得進版控**）。非潛水通用詞一律採 Apple 標準（例外登錄於家族 decisions，例：zh-Hant Import 維持「匯入」）。
- 本 repo 公開：報告不寫品牌與出處網址（品牌／URL 只給總指揮存家族內部）；不得以 GPL 專案翻譯檔為出處。
- 撇號：法、義文全檔用 `’`（U+2019）；xcstrings 改動一律 round-trip 腳本＋JSON 對 HEAD 比對（value／state／comment 分開計數）。

## 專用模擬器與測試資料（可刪）
- iOS：`JD2-LB-Audit`（iPhone 17 Pro，105 筆＋DA／T 系列特製紀錄）、`JD2-LB-B1-SE`（SE 3，資料同稽核機；11/05 多語截圖用，store 已由備份還原、SHA 相同）、`JD2-LB-FreshInstall`、`JD2-LB-UpgradeTest`、`JD2-LB-Upgrade-v10／v12／v13`、`JD2-LB-Shots`（iPhone 17 Pro Max，11/07 上架截圖用，截圖專用資料 84 筆）。全部關機。11/05 測試時 SE 外觀曾切深色後改回淺色。
- macOS：`~/Library/Containers/com.jd2logbook.JD2-Logbook.audit`（104 筆）。
- 截圖：`docs/screenshots/` 下各 v1.4 資料夾；11/05 多語版面 `v1.4-L10N-layout/01`–`25`。11/07 上架截圖 `v1.4-appstore-iphone-6.9/`、`v1.4-appstore-mac-1280x800/`（三語）。11/12 日文潜水時間 `2026-11-12_ja-dive-time/`（`JD2-LB-Shots`，已關機）。

## 開場指令建議（給下一個 session）
先讀本檔與 `docs/SUBMISSION_CHECK_NEXT.md` 最上段；`git status`／`git log origin/main..HEAD` 確認推送狀態；`git -C /Users/kevin/Documents/AppProject/_JD2-family/<Kit> describe --tags` 對照 v9.13.0／v0.9.0（不同就是 Kit 又升了，更新 `CLAUDE.md` 要 PM 同意）；跑 `run_tests.sh logbook` 對照 **249／0／1**。
