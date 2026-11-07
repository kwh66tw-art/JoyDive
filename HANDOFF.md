# HANDOFF — JD2-Logbook

> 交接文件（固定檔名滾動式）。前一版：`docs/handoff-archive/HANDOFF_2026-11-07.md`（再前：`HANDOFF_2026-11-04_3.md`）。

## 交接時間
2026-11-07 晚（產生方式：/handoff skill；PM 指示「先更新文件、交接」）

## 目前狀態
- **里程碑**：v1.4 **PM 2026-11-07 已送審（iOS＋macOS 1.4（5））**，等審核結果（v1.3 Build 4 仍為線上版）。
  - ⏰ **下一版送審必提醒 PM：iOS 英文關鍵字要改成新組**——11/07 PM 只改了 macOS，iOS 1.4 送出的是 v1.3 舊組（`docs/SUBMISSION_CHECK_NEXT.md` 最上段「下一版送審前必做」）。
  - **ASC iOS 1.4／macOS 1.4 內容（App-lb 11/07 經 Chrome 操作、PM 授權；PM 檢查後送審）**：三語截圖（iPhone 6.9 吋各 6 張、Mac 各 5 張，取代 v1.3 舊圖；舊圖仍在素材庫）、三語 What's New（`APPSTORE_COPY.md` v1.4 定稿）、建置 1.4（5）皆已存；英文關鍵字 PM 自行改——**只改到 macOS，iOS 仍是舊組**。
  - ⚠️ App Review 備註（Notes）草稿時仍是 v1.2 退件的舊說明（"This submission addresses the two issues…"）；PM 送審前是否刪改**未知**——若被問到或下一版，先查 ASC。
- **版號**：1.4（5），Release 產物已驗；下次發布改 6（`CLAUDE.md`「下次發布流程」）。
- **git**：見下方「未提交／未推送」。
- **測試**：`run_tests.sh logbook` **249／0／1**（11/07 後無程式變更）。
- **共用層**：DiveKit **v9.8.0**、DiveImportKit **v0.8.3**（11/07 核對）。

## 未提交／未推送（交接當下）
- **未推送提交**：`39c9b1b`（TestFlight 結案）、`7a98d93`（上架截圖初版）、`f8eb4dc`（上架截圖重做）——推送要 PM 在本 session 直接同意。
- **未提交**（等 PM「提交」）：`logbook/privacy.md`（三語：刪除無程式依據的「廣告不個人化」句、廣告段標「僅 iOS」並寫明 Mac 版不含 AdMob（Mac Release／Debug 產物 0 筆、iOS 對照 11 筆）、更新日改 11/7）；`docs/APPSTORE_COPY.md`、`docs/KEYWORDS_NEXT_DRAFT.md`（英文關鍵字 v1.4 新組）；本交接與 `SUBMISSION_CHECK_NEXT`、`KNOWN_ISSUES`、`CHANGELOG` 同步。
- **線上隱私頁**（GitHub Pages）要推送後才會更新；ASC 隱私問卷不需改（v1.4 無新增資料收集，已逐項查證）。

## 11/07 完成（細節見 `CHANGELOG.md` [v1.4.0]「送審收尾」）
- TestFlight 覆蓋升級首次啟動 PM 實機結案；iOS／macOS 1.4（5）上傳（上傳前需同意更新的 PLA）。
- 上架截圖重做：構圖比照 ASC v1.3，詳細頁用 PM 真實紀錄（蘭嶼母雞岩外礁，組織負荷 6 格黃）；`docs/screenshots/v1.4-appstore-*`。
- ASC 1.4 草稿（見上）。
- 隱私政策審查與修正（見上）；英文關鍵字網路查證後改組（證據等級＝實際用詞、非搜尋量；出處含品牌已交總指揮存家族內部）。

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
1. PM「提交」⇒ 提交上述未提交檔（閘門照舊）；PM「推送」⇒ 推送（含 3 筆未推提交），線上隱私頁隨之更新。
2. ~~PM 送審~~ ✅ 11/07 已送（iOS＋macOS）。等審核結果；被退件時先讀退件信再對照 `app-store-submission-guide`。**下一版送審：提醒 PM 改 iOS 英文關鍵字。**
3. 送審後：強調色原則落地、通用詞全掃、與 App-u 統一共用詞（等總指揮派工）；下一版 GDPR／UMP。

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
- 截圖：`docs/screenshots/` 下各 v1.4 資料夾；11/05 多語版面 `v1.4-L10N-layout/01`–`25`。11/07 上架截圖 `v1.4-appstore-iphone-6.9/`、`v1.4-appstore-mac-1280x800/`（三語）。

## 開場指令建議（給下一個 session）
先讀本檔與 `docs/SUBMISSION_CHECK_NEXT.md` 最上段；`git status`／`git log origin/main..HEAD` 確認是否已提交、推送；確認 Kit 版號（`git -C /Users/kevin/Documents/AppProject/_JD2-family/<Kit> describe --tags` ⇒ v9.8.0／v0.8.3）；跑 `run_tests.sh logbook` 對照 **249／0／1**；再問 PM 送審結果（審核中／被退件）或向總指揮確認送審後項目。
