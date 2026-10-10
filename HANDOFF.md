# HANDOFF — JD2-Logbook

> 交接文件（固定檔名滾動式；前一版在 `docs/handoff-archive/HANDOFF_2026-09-25.md`）。
> v1.3 的逐項紀錄與裁示全文在 `docs/V1_3_WORK_PLAN.md`（§七、§八）；本檔只寫目前狀態與下一步。

## 交接時間

2026-10-07（滾動更新；狀態以指令查證）。前一版：`docs/handoff-archive/HANDOFF_2026-10-06午.md`。

## 目前狀態

- 最後 push：`3b3f0a0`（10/07）。之後的 commit **未 push**（`git log origin/main..HEAD` 查；push 需 PM 同意）。工作樹只剩 `docs/l10n_v1.3_待翻譯.csv`（工作檔，刻意不提交）。
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
3. ⏳ 送審：先完成下方「送審前還要做」全部項目，再由 PM 上傳 ASC。

## 🔴 送審前還要做（PM 10/07 已裁示「全採納」）——10/10 進度

依據：`_JD2-family/decisions/2026-10-06_匯入格式全面稽核與DIK-v0.7.3修正計畫.md` §十九、§二十二。commit `baa7c6a`、`0f7255b`（未 push）。

| # | 項目 | 狀態 | 驗證 |
|---|---|---|---|
| 1 | 編輯頁氣體：不可信不預選；沒動就原值保留（32.5% 不再變 33%）；百分比不取整（PM 10/10 裁示 A） | ✅ | 模擬器：EAN32.5 未動存檔，DB 仍 `0.325`、extras 不變；Lake Coleridge 不可信 Trimix 未動存檔仍原值＋unknown |
| 2 | 不可信 Trimix 開放選擇；可信 Trimix 鎖住 | ✅ | 模擬器截圖兩種情境（Lake Coleridge 可選、Garmin Tx18/20 鎖住＋提示） |
| 3 | 自由潛水時間軸改秒 | ✅（App-lb） | 模擬器：70 s Suunto 改自由潛水 ⇒ 0s/12s/…/60s。DiveKit v9.3.0 待 DK 全測試＋App-u/App-i 重跑 |
| 4 | App 內語言殘留 | ✅（主要畫面） | 約 110 處改走 `languageManager.localized`；克羅埃西亞文（系統繁中）截圖：列表、新增、編輯、詳細、匯入、選單、callout 無中文殘留。xcstrings 格式符號 0 不符 |
| 5 | ATMOS FIT | ✅ | DIK v0.7.7（402/0/0）；模擬器匯入成功、顯示 ATMOS FIT。⏳ 送審樣本資料夾**未放**：FIT 內部日期依規則不改＝6 月，PM 要的是 7 月 ⇒ 待 PM 決定 |
| 6 | 新增潛水不選模式 | ✅ | 模擬器截圖：新增頁無「潛水模式」，編輯頁有 |
| 7 | 收尾 | ⏳ | **Ceiling 膠囊、Mac ⓘ 未截圖**（本批測試資料沒有可顯示組織負荷的減壓潛水）；`SUBMISSION_CHECK_NEXT.md` 未複核；push 待 PM |

**10/10 驗證中另抓到並已修**：
- 🔴 自己引入的閃退：無障礙鍵改 `%@` 卻仍傳 Int ⇒ 開高氧潛水編輯頁 EXC_BAD_ACCESS（`0f7255b` 修）。
- 既有 bug：編輯頁存檔把潛水時間截成整分鐘（4674 → 4620 s，出水時間與水面間隔跟著變）⇒ 分鐘沒改就保留原秒數。
  ⚠️ App-u 的 `JD2UltraPhone/UI/Logbook/DiveLogEditSheet.swift` 結構相同，**未查**是否同病（家族待辦）。
- 已知未翻譯（使用者看不到）：DEBUG 開發者工具 4 鍵；上升速率警示 2 鍵（`showWarningEvents=false`）。

✅ 10/07 已完成：#3 Mac ⓘ 視窗空白（補 macOS 尺寸）、#4 Ceiling 膠囊 A 案（#1F66E0＋白字）——**macOS build 通過、165/0/1，未截圖目視**。
已答覆不改：#5 Suunto FIT 自由潛水判為水肺（模式欄讀不到，已是未知氣體；PM 接受）、#7 去重＝先匯入者留下、無格式優先、
#8 6/4 不顯示組織負荷＝96 h 內有 DAN DL7 範例檔（6/1、6/2，氣體不可信），非 6/3 DM5。

## 下一版待辦（PM 10/07）

- **列表篩選（PM 10/07 同意記入）**：氣體（空氣／高氧／未知氣體）、潛水類型（水肺／自由潛水）、組織負荷（可顯示／不可顯示）。
  目的：找出「未知氣體」逐筆補正、分開自由潛水、找出拖累殘氮鏈的紀錄。待定：地圖與頂部統計是否跟著篩選。需 18 語字串＋ui-verify。
- **搜尋範圍擴充（PM 10/07 採納，與篩選同批）**：目前「搜尋地點…」只比對地點與備註（`DiveLogListView.swift:43-44`）⇒ 加潛伴、標籤、潛點名稱；
  有固定選項的（氣體、類型、組織負荷）交給篩選。提示文字一併改（不再只寫「地點」）。
- **環境：原始檔沒有就顯示「未記錄」（PM 10/07 採納）**：目前沒有任何解析器填 `environmentType`（全 Parsers 0 處；`DiveLog.swift:108` 預設 `seawater`）。
  🔴 **先查再改**：重放讀的是 `surfacePressureBar`／`metersPerBar`（`DiveReplayInput.swift:25-30`），不是環境字串——
  匯入時 `metersPerBar` 是否依淡水調整**未查證**；湖泊潛水（例 Lake Coleridge）可能以海水密度計算。改「未記錄」時要決定重放的預設密度。

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

先讀本檔與 `docs/V1_3_WORK_PLAN.md` §八。驗證：`bash /Users/kevin/Documents/AppProject/_JD2-family/scripts/run_tests.sh logbook`（預期 165/0/1）。
