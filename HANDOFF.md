# HANDOFF — JD2-Logbook

> 交接文件（固定檔名滾動式；前一版在 `docs/handoff-archive/HANDOFF_2026-09-25.md`）。
> v1.3 的逐項紀錄與裁示全文在 `docs/V1_3_WORK_PLAN.md`（§七、§八）；本檔只寫目前狀態與下一步。

## 交接時間

2026-10-06 06:52（/handoff；狀態以指令查證）。本輪由家族總指揮直接更新本 repo（PM 10/04 指示）。

## 目前狀態

- 工作樹：除本次 HANDOFF／CHANGELOG 提交外乾淨。HEAD 見 `git log -1`。
- ⚠️ **本地領先 `origin/main` 73 個 commit（含本提交），未 push**——push 是對外動作，由 PM 決定。
- 共用層：DiveKit **v9.2.0**、DiveImportKit **v0.7.2**（10/05 凍結期 bug 修正：Garmin FIT 氣體）。🔒 兩 Kit 仍凍結。
- 測試：`run_tests.sh logbook` **155 passed／0 failed／1 skipped**（skip＝價格未載入測試，刻意）。
- 版號：1.3（4）。

## v1.3 已完成（PM 10/05 裁示，證據見工作計劃 §七／§八與 `docs/screenshots/2026-10-04_v1.3_P0/`）

P0／P1 全部；D6 排下一版；D7 ATS 官方寫法；D9 提示列；組織負荷說明支援／不支援各一句；ⓘ 頁一段；
What's New 三語定稿（籠統寫法）；剖面讀數 label 字級；匯入失敗原因；Garmin FIT 氣體（含舊資料視為不可信）；
重放語意色（F-25 §4.4）；效能測試門檻。

## 下一步（依序，一件一件問 PM）

0. ✅ **匯入格式修正完成**（`b0d2d69`，159/0/1；DIK v0.7.3）。What's New 時區句 PM 10/06 同意，已寫入 `docs/APPSTORE_COPY.md`（三語）：
   - en：Fixed dive times from several import formats being shifted by your time zone.
   - zh-Hant：修正部分匯入格式的潛水時間因時區而偏移的問題。
   - ja：一部のインポート形式でダイブ時刻がタイムゾーン分ずれる問題を修正しました。

1. ~~翻譯~~ ✅ 2026-10-06 完成（`docs/V1_3_WORK_PLAN.md` §九；No Deco el／hr 採用 NDL）。
2. **送審收尾**：✅ 10/06 複核完成（`docs/SUBMISSION_CHECK_NEXT.md` 頂部表）。隱私權政策「定位」段已依 PM 10/06 同意修正並 push。之後 ASC 上傳由 PM。
3. P0-3 手動走匯入：PM 10/05 已在模擬器走過一次（26 檔）；匯入失敗新文案**尚未截圖驗證**（PM 同意直接提交）。

## 待 PM（未裁示，不阻擋送審）

- App-lb 另有 4 處 `minimumScaleFactor`（清單統計列、潛水列月份、匯入頁副檔名）：Xcode 27 下是否同樣被縮小**未驗證**（A/B 實驗 PM 中止）。
- ~~匯入不辨識潛水模式~~ ✅ 10/06：DM5 Mode=3、Seabear APNEA 帶入自由潛水（其他格式無證據不推測）。
- 使用者手動改氣體不會清掉「氣體不可信」標記（保守）；若要讓使用者確認後可重放，需新 UI。

## 陷阱提醒

- 🔴 **Xcode 27 的模擬器（Device Hub）不接受 Finder 拖曳檔案**。放檔案進「檔案」App：
  `xcrun simctl get_app_container booted com.apple.DocumentsApp groups` 取 `group.com.apple.FileProvider.LocalStorage`，
  複製到同目錄暫存夾再 `mv` 進 `File Provider Storage/`。**用 `find` 找到的其他 AppGroup 是錯的**（10/04 夜因此看不到檔案）。
- 🔴 **Xcode 27 建置下 `.minimumScaleFactor` 放得下也會縮小**（同程式碼 v1.2 真機正常）——改用 `ViewThatFits`。
- 測試模擬器 `LB-Upgrade-v12to13`（`F13F80D4-…`，iOS 26.4）有 PM 匯入的 27 筆資料；**拍截圖時臨時改過的資料都已還原**（10/05：Z_PK 17、137）。
- App 語言切換：`xcrun simctl launch … -jd2logbook.appLanguage zh-Hant -AppleLanguages "(zh-Hant)"`。
- 模擬器點擊偶爾漏：截圖要 `sleep 2` 後再拍；返回用左緣 swipe。
- 字串目錄（xcstrings）插入新鍵要照既有順序（近似不分大小寫排序），整檔重排會產生上萬行 diff。

## 開場指令建議

先讀本檔與 `docs/V1_3_WORK_PLAN.md` §八。驗證：`bash /Users/kevin/Documents/AppProject/_JD2-family/scripts/run_tests.sh logbook`（預期 155/0/1）。
