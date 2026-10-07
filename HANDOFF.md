# HANDOFF — JD2-Logbook

> 交接文件（固定檔名滾動式；前一版在 `docs/handoff-archive/HANDOFF_2026-09-25.md`）。
> v1.3 的逐項紀錄與裁示全文在 `docs/V1_3_WORK_PLAN.md`（§七、§八）；本檔只寫目前狀態與下一步。

## 交接時間

2026-10-06 夜（/handoff；狀態以指令查證）。前一版：`docs/handoff-archive/HANDOFF_2026-10-06午.md`。

## 目前狀態

- HEAD `065403d`（origin 落後 2：交接 `0392afc`＋SDE 遷移；**未 push**）。工作樹只剩 `docs/l10n_v1.3_待翻譯.csv`（工作檔，刻意不提交）。
- 共用層：DiveKit **v9.2.0**、DiveImportKit **v0.7.6**（10/06 匯入稽核＋逐點水溫、匯出逐點水溫；10/07 Subsurface XML 多氣瓶）。🔒 兩 Kit 凍結（僅 bug 修正）。
- 測試：`run_tests.sh logbook` **165／0／1**（10/07：Subsurface XML 舊資料不可信、改氣體＝確認；注入 2 項 RED）。版號 1.3（4）。

## v1.3 已完成

P0／P1、D7、D9、翻譯 18 語、送審收尾複核、隱私權政策定位段、What's New（三語，含時區修正句）、ⓘ 接在句尾（截圖 24）、
匯入修正（時區、舊資料氣體記號 `jd2GasVerified`、剖面 CSV 不進殘氮鏈、自由潛水模式、Suunto FIT 顯示名）。
細節：`docs/V1_3_WORK_PLAN.md` §七～§九、`_JD2-family/decisions/2026-10-06_匯入格式全面稽核與DIK-v0.7.3修正計畫.md`。

## 下一步（依序）

1. ✅ **SDE 舊紀錄 0 °C → 未記錄**（`065403d`）：`DiveLogDatabase.migrateLegacySDEZeroWaterTemperature`，旗標 `jd2.migration.v13.sdeZeroWaterTemp`；
   測試 +2；**模擬器 LB-Upgrade 實測**：唯一一筆 SDE 紀錄水溫 0 → NULL（sqlite 查證；此為預期遷移，不還原）。
2. ✅ Kit 側 **UDDF／剖面 CSV 逐樣本水溫，不補值**（DIK v0.7.5，395/0/0，注入 4 項 RED；匯出也寫逐點水溫）；App 映射已接（`DiveImportKitAdapter.swift:85`）。
   ⚠️ **未驗證**：App 拖曳剖面 Temp 顯示（需重新匯入 UDDF；舊匯入的 UDDF 不會自動補，屬預期）。
3. ⏳ 送審：PM 重新匯入 test42／Lake Coleridge 目視拖曳 Temp 後，ASC 上傳。

## 下一版待辦（PM 10/07）

- 「原始匯入資料」6 個來源鍵名（`cns`／`minPPO2`／`maxPPO2`／`altitudeRange`／`decoRequired`／`gasSwitches`）補在地化名稱（18 語）；`gasSwitches` 值是 JSON，需整理成可讀格式。

## 待 PM（未裁示，不阻擋送審）

- App-lb 另有 4 處 `minimumScaleFactor`（清單統計列、潛水列月份、匯入頁副檔名）：Xcode 27 下是否同樣被縮小**未驗證**（A/B 實驗 PM 中止）。
- ~~匯入不辨識潛水模式~~ ✅ 10/06：DM5 Mode=3、Seabear APNEA 帶入自由潛水（其他格式無證據不推測）。
- ~~使用者手動改氣體不會清掉「氣體不可信」標記~~ ✅ 10/07 PM：改了氣體＝已確認（`DiveLog.userEditConfirmations`）。

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
