# HANDOFF — JD2-Logbook

> 交接文件（固定檔名滾動式；前一版在 `docs/handoff-archive/HANDOFF_2026-11-04.md`，更早的在同目錄）。

## 交接時間
2026-11-04 16:30（產生方式：/handoff skill）

## 目前狀態
- **所在里程碑**：v1.4 開發中（v1.3 Build 4 已上架）。A1 ✅、A2 ✅、D-A ✅、D-C ✅、A3 ✅、B1＋B2 ✅、**B1-A ✅（cd9ecc8＋5fdc8e5，已推送）**；C 未做。
  進度：`docs/V1_4_WORK_PLAN.md`（已同步）；稽核：`docs/V1_4_AUDIT_TEST_PLAN.md`（F1–F21，F20 已撤回）。
- **未 commit 變更**：無。本次交接文件（本檔、歸檔 `docs/handoff-archive/HANDOFF_2026-11-04.md`、`CHANGELOG.md`／`docs/V1_4_WORK_PLAN.md` 補 B1-A 的 hash）已在 5fdc8e5 之後的「文件：交接」commit 提交並推送（hash 以 `git log -1` 為準）。
- **測試**：`run_tests.sh logbook` **245／0／1**（11/04 提交前實跑，總指揮重跑相同；唯一 skip＝`PurchasePriceDisplayTests.testPremiumPriceStringIsNilWhenProductNotYetLoaded`）。
- **共用層**：DiveKit **v9.8.0**、DiveImportKit **v0.8.2**（11/04 `describe --tags` 核對；`check_doc_version_sync.sh` 通過）。
- **B1／B1-A 的完整經過**：`docs/decisions/D-2026-10-26-v1.4-D3至D7裁示.md`（MapKit 實測、A／H5 失敗、問題重新定義、依資料縮放、多尺寸表、B1-A 規則與情境×平台表、開地圖自動置中根因、跳轉縮放被置中蓋掉、故障注入、字串檔事件）。截圖 `docs/screenshots/v1.4-B/00–55`。

## 進行中的決策（尚未定案）
- **App-u 的 B2 跟進**（同座標聚合點點不開）：由總指揮與 PM 處理，本 repo 不動。~~App-u 是否有同樣的「開地圖自動置中」~~ 總指揮 11/04 查過：沒有（只在按鈕後置中），不用跟進。
- **「一個潛點一根圖釘」改版**：排入待辦，卡在「同一潛點」怎麼判定（名稱撞名／座標完全相同合不了 22–73 m／距離合併需要門檻），見決策檔 B1-A 節。
- 🗑 「Safety stop became mandatory…」死鍵：PM 11/04 裁示刪除（xcstrings 258→257）；`DiveAnalysisView.swift:503` 的歷史註解保留。
- ~~D-B、D-E~~ ✅ PM 11/04 皆選①，列為已知限制（`docs/decisions/D-2026-11-04-DB-DE已知限制與F-09複數形實驗.md`）。
- **F17／F18／F19／F21**：PM 10/27 另行排程，現在不處理。
- **文案**：A1／D-A／A2／A3／B1／B2／B1-A 新字串皆為草稿（英／繁中／日）；⏸ 上架前收尾＋其餘 14 語。
  - ⚠️ **上架前補語言待辦**：B1-A 的「+%lld more」要依數量變形時，**只需在 xcstrings 加 Vary by Plural，程式碼不用動**（`DiveMapRepresentable.swift:72` 的 `String(format:locale:)` 已帶 `languageManager.locale`；11/04 實驗 hr 1／2／5／21 選出 one／few／other／one，見 `docs/decisions/D-2026-11-04-DB-DE已知限制與F-09複數形實驗.md` 第三節）。**hr 只有三類**：one（1, 21…）／few（2–4, 22–24…）／other（總指揮 11/04 核對 CLDR，F-09 已更正原寫的四類）。

## 下一步（按順序）
1. ~~commit＋push 本次交接文件~~ ✅（PM 11/04 指示）。
2. **v1.4 剩餘**：C 組小項（`docs/V1_4_WORK_PLAN.md` §四）。
3. **macOS 未驗證兩格**（可選）：「選取中按回到我的位置」、「GPS 開著冷啟動」在 macOS 判別力有限——要驗得先由 PM 在系統設定確認 audit App 的定位授權狀態；授權相關情境目前以 iOS 31–33、35、36 為準。
4. **待 PM 手動**：iOS 模擬器文字輸入（T4、T27、T28）。

## 陷阱提醒
- 🆕 **提交前故障注入**：`inject.sh` 只能在乾淨工作樹跑（還原用 `git checkout`），`run_tests.sh logbook` 又固定測主 checkout ⇒ 提交前只能手動注入，並照搬守衛：恰好命中 1 次、備份＋SHA 還原比對、`run_tests.sh --only`、FAIL 但 failed=0／passed=0／無 RESULT 一律 ABORT。單一類別跑一次可能超過 10 分鐘，用背景執行；注入期間不得動該檔。
- 🆕 **只測判斷函式會漏掉呼叫路徑**：B1-A 的 I2b（回呼繞過判斷函式）原本全綠。新邏輯要讓「實際副作用」可替換（如 `requestLocationAction`），測呼叫路徑本身。
- 🆕 **`simctl spawn … defaults write` 寫的是模擬器全域偏好，不是 App 沙盒**：改 App 設定（如 `jd2logbook.appLanguage`）要先 `simctl shutdown`，再用 Python `plistlib` 改 container 內的 `Library/Preferences/com.jd2logbook.JD2-Logbook.plist`（鍵名有點，`plutil -replace` 會當成路徑）。
- 🆕 **macOS 地圖標註點不到背景點擊**（無 AX 動作），要全螢幕控制；**全螢幕截圖會拍到 PM 的 Dock／桌面**，入庫前裁成 App 視窗。`screencapture -l` 從終端拍視窗沒有權限。
- 🆕 **提交閘門的 grep**：零命中時 grep 回 1，`set -euo pipefail` 會當成失敗 ⇒ 用 `{ grep … || true; }`。
- 🆕 **iOS 模擬器捲動**：滑動起點落在列表上方的統計列（SE 約 y < 195 pt）不會捲；快速滑動的慣性會讓下一張截圖還在動，再截一次確認停住才點。地圖右上地球鈕＝切換地圖類型（衛星），不是縮放。
- **MapKit 聚合**：貼邊甚至多 1 個實體像素仍會聚合；剛切到地圖分頁時聚合還沒算。不要再用自訂門檻或計時去追。動畫 `setCenter` 會取消進行中的 `setVisibleMapRect` 動畫。
- **MapKit 套用範圍會因安全區調整**：用 `mapRectThatFits` 先問再補償。圖釘大小因裝置而異，從實際 view 讀。
- **macOS 的 NSLog 會被遮成 `<private>`**：直接執行 `.app/Contents/MacOS/JoyDive²` 並把 stderr 導到檔案。zsh 的 `log` 是內建指令，要用 `/usr/bin/log`。
- **撤暫時 log 用備份覆蓋，不要用正則刪**；撤完先 build 再跑測試。
- **SwiftUI sheet 閉包讀到舊的 @State** ⇒ 用 Binding 傳進子 View。
- **測試中不得釋放任何 `@MainActor @Observable` 類別**（`AppLanguageManager`、`MapFocusRequest`、`UserLocationProvider`…，SIGABRT）⇒ static 共用實例。
- **Xcode 開著時 build 可能整份改寫 `Localizable.xcstrings`**：不得提交。加鍵做法：從 HEAD 取原檔，`json.dumps(indent=2, separators=(',', ' : '), ensure_ascii=False)`＋空物件寫成 `{\n\n<indent>}`（先拿 HEAD round-trip 逐位元相同），鍵序依 `localizedStandardCompare`。commit 前 `git diff --numstat` 只有新增行、行數與新增鍵相符。
- **提交閘門**：bash 腳本（`bash -euo pipefail`）串機敏掃描（附對照樣本）＋`check_doc_version_sync.sh`，失敗就停；**逐檔 `git add`**，有已 staged 的其他變更時用 `git commit -- <paths>` 隔開。zsh 不拆 `$var`、會展開 `--include=*.swift`、沒有 `PIPESTATUS` ⇒ 檔案清單與 grep 一律在 bash 跑。
- **macOS 實測不得用正式 bundle ID**：`PRODUCT_BUNDLE_IDENTIFIER=com.jd2logbook.JD2-Logbook.audit CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=`，測前測後比對正式 store SHA-256。電腦操作要 PM 在本 session **直接**授權（總指揮轉述不算）。
- **iOS 模擬器**：截圖常慢一步；剛 launch 後第一次點擊常不生效；詳細頁捲到底會回彈，等穩定再點座標列。文字輸入進不了欄位，不要再試。
- **改模擬器資料**：先 `simctl terminate`、`PRAGMA wal_checkpoint(TRUNCATE)`、備份 `default.store*`；container 路徑每次重新取。
- **Kit 可能未通知就更新**：開工前 `describe --tags` 兩個 Kit。
- 測試用到 Kit 型別要 `import DiveKit`。

## 專用模擬器與測試資料（可刪）
- iOS：`JD2-LB-UpgradeTest`、`JD2-LB-Upgrade-v10／v12／v13`（T1–T3）、`JD2-LB-Audit`（105 筆；Banana Reef PK46、PK12 座標改成與 PK96 完全相同、PK88 經度＝PK105＋1e-6；第 5 筆氣體標記 `user`；**App 內語言日文、GPS 未開（已還原）**）、`JD2-LB-B1-SE`（iPhone SE 3，多尺寸驗證用，資料複製自稽核機，App 內語言日文）。兩台目前關機。
- macOS：`~/Library/Containers/com.jd2logbook.JD2-Logbook.audit`（audit 版，104 筆，11/04 測後由備份還原、`cmp` 相同；`gpsLocationEnabled` 已刪）。
- 截圖：`docs/screenshots/v1.4-A1/`、`v1.4-A2/`、`v1.4-audit-sim/`、`v1.4-A3/`（01–14）、`v1.4-B/`（00–55、17b）。

## 開場指令建議（給下一個 session）
先讀本檔、`docs/V1_4_WORK_PLAN.md`（§四 C 組）、需要時讀 `docs/decisions/D-2026-10-26-v1.4-D3至D7裁示.md`；
確認 Kit 版號：`git -C /Users/kevin/Documents/AppProject/_JD2-family/DiveKit describe --tags`（v9.8.0）、DiveImportKit（v0.8.2）；
`git status` 應為乾淨；跑 `run_tests.sh logbook` 對照 **245／0／1**；再向總指揮確認下一項（C 組或 App-u 跟進）。
