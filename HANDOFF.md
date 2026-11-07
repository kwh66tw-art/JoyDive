# HANDOFF — JD2-Logbook

> 交接文件（固定檔名滾動式）。前一版：`docs/handoff-archive/HANDOFF_2026-11-04_3.md`（再前：`_2.md`）。

## 交接時間
2026-11-07（產生方式：/handoff skill；PM 指示「確認文件、交接更新全面正確，push，通知我壓縮」）

## 目前狀態
- **里程碑**：v1.4 **送審準備**（v1.3 Build 4 已上架）。功能面完成；11/05 介面與翻譯收尾完成；**11/07 PM：翻譯審核通過（26 鍵 391 條 → `translated`）、What's New 三語定稿**。
  送審前清單：`docs/SUBMISSION_CHECK_NEXT.md` 最上段——TestFlight 覆蓋升級首次啟動 **✅ PM 11/07 結案**（v1.3＋既有資料 → TestFlight 1.4（5），無延遲）；1.4（5）iOS＋macOS 皆已上傳 ASC（11/07，Organizer 顯示 Uploaded to Apple）。**只剩 ASC 送審（PM）**。
- **版號**：1.4（5），Release 產物已驗；下次發布改 6（`CLAUDE.md`「下次發布流程」）。
- **git**：本交接提交並推送後工作樹乾淨、與 origin/main 相同（hash 以 `git log -1` 為準）。
- **測試**：`run_tests.sh logbook` **249／0／1**（唯一 skip＝`PurchasePriceDisplayTests.testPremiumPriceStringIsNilWhenProductNotYetLoaded`）。
- **共用層**：DiveKit **v9.8.0**、DiveImportKit **v0.8.3**（11/07 `describe --tags` 核對）。

## 11/05–11/07 完成（細節見 `CHANGELOG.md` [v1.4.0]「送審收尾」）
- 送審收尾派工：版號、F18／F19、16 鍵補 14 語、「+%lld more」依數量變形、What's New。
- 外部翻譯稽核 → 採用 5 處；待查證清單 `docs/reports/R-2026-11-05-v1.4翻譯待查證清單.md`（#1–#9 結案）。
- 法、義文撇號全檔 `’`；組織負荷說明頁標題 12 語縮短；列表標題「Dive Logbook」18 語＝分頁「Logbook」譯文（含英文；PM 實機希臘／德文確認）。
- iOS 詳細頁刪除＋編輯收進「…」（PM 實機確認刪除正常）；編輯／新增 sheet ✕／✓（✓ 為 iOS 26 `.confirm`）；篩選圖示無外框＋啟用強調色（HIG）。
- 冗字 16 處改單一說法（`docs/reports/R-2026-11-05-翻譯冗字盤點.md`）；Nitrox 中文「高氧」；日文匯入用語統一「読み込み」；義文 Done＝Fine（Apple 詞彙表）。

## 進行中的決策／排隊（尚未定案或送審後）
- **送審後**：介面強調色原則落地（家族 `decisions/2026-11-05_App介面強調色使用原則.md` §四；`docs/KNOWN_ISSUES.md` 有一列）——資料數值／圖示改 `.primary`／`.secondary`、地圖未選中圖釘與選中區分、氣體標籤不用強調色；**剖面圖藍色維持**；強調色維持系統藍（品牌薄荷綠白底 2.05:1，不採用）。
- **送審後**：非潛水通用詞全掃（Apple 標準翻譯）——總指揮排程。
- **送審後**：「Dive Logbook」等共用詞與 App-u 統一（總指揮轉 App-u）。
- 待查證清單 #10–#12（稽核未附出處斷言、14 語母語審稿以外的實機排版、地圖副標實機目視）——非阻斷。
- 「一個潛點一根圖釘」、F17／F21、Diving Log 舊備註 RTF 殘留：同前版（未排程／不自動清理）。
- 可選：Premium 頁「Close」、說明頁「Done」比照 HIG 改 ✕／✓——PM 未裁示。

## 下一步（按順序）
1. ~~TestFlight 覆蓋升級首次啟動~~ ✅ PM 11/07 結案（同機 v1.3＋既有資料升級，無延遲）。iOS 1.4（5）已上傳（11/07；上傳前需先在開發者帳號同意更新的 PLA）。
2. ~~macOS Archive／上傳~~ ✅ 11/07 14:11（Organizer 截圖）。ASC 送審（PM；`CLAUDE.md`「下次發布流程」、`app-store-submission-guide`）。
3. 送審後：強調色原則落地、通用詞全掃、與 App-u 統一共用詞（等總指揮派工）。

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

**11/05 新增**
- 模擬器（iOS 26.5，SE 與 17 Pro）列表**捲動後不顯示小標題**（任何語言），與實機不同 ⇒ 捲動狀態只能 PM 實機驗。
- 模擬器點選單項目常落在動畫中途（點「刪除」曾兩次打開編輯）；實機正常。同一操作兩次不成就停，請 PM 實機。
- `simctl install` 會換 App container UUID ⇒ 還原 store 前用 `find …/Containers/Data/Application -name default.store` 重找路徑。
- HIG 網頁是 JS 渲染，WebFetch 取不到 ⇒ `curl https://developer.apple.com/tutorials/data/design/human-interface-guidelines/<頁>.json` 取原文。
- Apple 在地化詞彙表（iOS 13.3，17 語）查詢：`python3 /Users/kevin/Documents/AppProject/_JD2-family/scripts/apple_glossary_lookup.py "<詞>"`（唯讀，**詞彙表檔不得進版控**）。非潛水通用詞一律採 Apple 標準（例外登錄於家族 decisions，例：zh-Hant Import 維持「匯入」）。
- 本 repo 公開：報告不寫品牌與出處網址（品牌／URL 只給總指揮存家族內部）；不得以 GPL 專案翻譯檔為出處。
- 撇號：法、義文全檔用 `’`（U+2019）；xcstrings 改動一律 round-trip 腳本＋JSON 對 HEAD 比對（value／state／comment 分開計數）。

## 專用模擬器與測試資料（可刪）
- iOS：`JD2-LB-Audit`（iPhone 17 Pro，105 筆＋DA／T 系列特製紀錄）、`JD2-LB-B1-SE`（SE 3，資料同稽核機；11/05 多語截圖用，store 已由備份還原、SHA 相同）、`JD2-LB-FreshInstall`、`JD2-LB-UpgradeTest`、`JD2-LB-Upgrade-v10／v12／v13`。全部關機。11/05 測試時 SE 外觀曾切深色後改回淺色。
- macOS：`~/Library/Containers/com.jd2logbook.JD2-Logbook.audit`（104 筆）。
- 截圖：`docs/screenshots/` 下各 v1.4 資料夾；11/05 多語版面 `v1.4-L10N-layout/01`–`25`。

## 開場指令建議（給下一個 session）
先讀本檔與 `docs/SUBMISSION_CHECK_NEXT.md` 最上段；確認 Kit 版號（`git -C /Users/kevin/Documents/AppProject/_JD2-family/<Kit> describe --tags` ⇒ v9.8.0／v0.8.3）；`git status` 應乾淨；跑 `run_tests.sh logbook` 對照 **249／0／1**；再向總指揮確認下一項（TestFlight 驗證或送審後項目）。
