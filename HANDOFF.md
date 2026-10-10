# HANDOFF — JD2-Logbook

> 交接文件（固定檔名滾動式；前一版在 `docs/handoff-archive/HANDOFF_2026-10-06午.md`）。
> v1.3 的逐項紀錄與裁示全文在 `docs/V1_3_WORK_PLAN.md`（§七、§八）；本檔只寫目前狀態與下一步。

## 交接時間

2026-10-10（滾動更新；狀態以指令查證）。前一版：`docs/handoff-archive/HANDOFF_2026-10-06午.md`。

## 目前狀態

- 最後 push：見 `git log -1 origin/main`（10/10 晚 PM 同意 push 至本檔所在提交）。**App-lb 自 10/10 晚由 App-lb session 負責，總指揮不再寫入**（除非 PM 另行指示）。工作樹只剩 `docs/l10n_v1.3_待翻譯.csv`（工作檔，刻意不提交）。
- 共用層：DiveKit **v9.3.0**、DiveImportKit **v0.7.8**。🔒 兩 Kit 凍結（僅 bug 修正；本輪改動皆經 PM 核准）。
- 測試：`run_tests.sh logbook` **171／0／1**。版號 1.3（4）。送審複核：`docs/SUBMISSION_CHECK_NEXT.md` 10/10 段——**程式與送審檢查皆完成；10/10 晚已上傳並送審（Waiting for Review）**。

## 10/10 晚：送審截圖與交接（總指揮 → App-lb）

- ✅ **v1.3 送審截圖**（`00ed34c`）：`_ScreenCaptures/iOS_v1.3/`（#2 新增潛水、#3 詳細；中英日；iPhone 18 Pro Max 1320×2868 拍、交付 1260×2736；
  無廣告、狀態列 9:41；詳細頁＝9/20 14:23）＋ `_ScreenCaptures/macOS_v1.3/`（#1 列表＋詳細、#5 新增潛水；中英日；PM ⌘⇧4 原檔在 `Original/`，交付透明 1280×800）。
  PM 確認：Mac 截圖含滑鼠指標可接受。其餘截圖沿用 v1.2。
- ✅ 已 push（PM 10/10 晚同意）：`2c27ecc`、`65cd1f0`、`00ed34c`、`99a3444` 與本次 HANDOFF 更新。
- ✅ PM 10/10 上架設定（`d38a277`）：類別 `public.app-category.sports`（Release 產物讀回驗證）、英文關鍵字只放各國潛水日誌用詞（100 字元／114 bytes）、說明文去 GPS 座標／氣體混合→氣體、品牌加 ATMOS；CLAUDE.md 現況更新（`1db588f`）。
- ✅ **v1.3 已上傳並送審（PM 2026-10-10 晚）**：iOS／macOS 兩平台 Build 4（1.3）皆為 **Waiting for Review**。ASC 內容由 App-lb 以 Chrome 建立 1.3 版本草稿並填入（主類別 Sports；副標英／繁中／日；說明、宣傳文字、What's New、關鍵字三語；選 Build 4），逐項重載後讀回驗證；截圖 12 張由 PM 上傳。
- ✅ **ASC 關鍵字上限以「字元」計**（實測：英文組 100 字元／114 bytes 完整接受、剩餘 0）。
- ⚠️ ASC 說明欄為純文字，不可帶 Markdown `**`；填表單時 `form_input` 對非主要語系的說明欄不可靠（四組曾沒寫進去），一律重載後讀回驗證。
- ⏳ **等 Apple 審核結果**；通過後：手動／自動上架依 ASC 設定，再做舊文件整理與 v1.4 待辦。
- 環境狀態（之後可還原）：iPhone 18 Pro Max 模擬器（`EFF901CA`）已匯入 70 支範例、`DEBUG_forceHideAds`=YES、狀態列覆寫 9:41（`xcrun simctl status_bar EFF901CA… clear` 還原）；
  Mac 版 App 以 Debug 產物 `-jd2logbook.appLanguage` 參數重開過（資料未動，70 支範例），`defaults` 也寫了 `DEBUG_forceHideAds`=YES。
- 送審後工作交 App-lb：舊文件整理（下一版待辦）、v1.4 待辦。

## v1.3 已完成

P0／P1、D7、D9、翻譯 18 語、送審收尾複核、隱私權政策定位段、What's New（三語，含時區修正句）、ⓘ 接在句尾（截圖 24）、
匯入修正（時區、舊資料氣體記號 `jd2GasVerified`、剖面 CSV 不進殘氮鏈、自由潛水模式、Suunto FIT 顯示名）。
細節：`docs/V1_3_WORK_PLAN.md` §七～§九、`_JD2-family/decisions/2026-10-06_匯入格式全面稽核與DIK-v0.7.3修正計畫.md`。

## 下一步（依序）

1. ✅ **SDE 舊紀錄 0 °C → 未記錄**（`065403d`）：`DiveLogDatabase.migrateLegacySDEZeroWaterTemperature`，旗標 `jd2.migration.v13.sdeZeroWaterTemp`；
   測試 +2；**模擬器 LB-Upgrade 實測**：唯一一筆 SDE 紀錄水溫 0 → NULL（sqlite 查證；此為預期遷移，不還原）。
2. ✅ Kit 側 **UDDF／剖面 CSV 逐樣本水溫，不補值**（DIK v0.7.5，395/0/0，注入 4 項 RED；匯出也寫逐點水溫）；App 映射已接（`DiveImportKitAdapter.swift:85`）。
   ✅ App 拖曳剖面 Temp 顯示：PM 10/10 確認 ATMOS（UDDF）正常。舊匯入的 UDDF 不會自動補，屬預期。
3. ⏳ 送審：「送審前還要做」全部完成（10/10）；剩 PM 上傳 ASC。

## 🔴 送審前還要做（PM 10/07 已裁示「全採納」）——10/10 進度

依據：`_JD2-family/decisions/2026-10-06_匯入格式全面稽核與DIK-v0.7.3修正計畫.md` §十九、§二十二。commit `baa7c6a`、`0f7255b`（已 push）。

| # | 項目 | 狀態 | 驗證 |
|---|---|---|---|
| 1 | 編輯頁氣體：不可信不預選；沒動就原值保留（32.5% 不再變 33%）；百分比不取整（PM 10/10 裁示 A） | ✅ | 模擬器：EAN32.5 未動存檔，DB 仍 `0.325`、extras 不變；Lake Coleridge 不可信 Trimix 未動存檔仍原值＋unknown |
| 2 | 不可信 Trimix 開放選擇；可信 Trimix 鎖住 | ✅ | 模擬器截圖兩種情境（Lake Coleridge 可選、Garmin Tx18/20 鎖住＋提示） |
| 3 | 自由潛水時間軸改秒 | ✅（App-lb） | 模擬器：70 s Suunto 改自由潛水 ⇒ 0s/12s/…/60s。DiveKit v9.3.0 待 DK 全測試＋App-u/App-i 重跑 |
| 4 | App 內語言殘留 | ✅（主要畫面） | 約 110 處改走 `languageManager.localized`；克羅埃西亞文（系統繁中）截圖：列表、新增、編輯、詳細、匯入、選單、callout 無中文殘留。xcstrings 格式符號 0 不符 |
| 5 | ATMOS FIT | ✅ | DIK v0.7.7（402/0/0）；模擬器匯入成功、顯示 ATMOS FIT。⏳ 送審樣本資料夾**未放**：FIT 內部日期依規則不改＝6 月，PM 要的是 7 月 ⇒ 待 PM 決定 |
| 6 | 新增潛水不選模式 | ✅ | 模擬器截圖：新增頁無「潛水模式」，編輯頁有 |
| 7 | 收尾 | ✅ | Ceiling 膠囊、Mac ⓘ：PM 10/10 確認；`SUBMISSION_CHECK_NEXT.md` 10/10 複核；已 push。剩 PM 上傳 ASC |

**10/10 下午 PM 追加（皆已完成，`fc9aabc`、`fc6a3de`，171/0/1，模擬器克羅埃西亞文驗證）**：
- 剖面時間軸：自由潛水**或短於 4 分鐘**用秒。
- 編輯頁：未知氣體的水肺紀錄潛水模式先**空白**；重選水肺後「沒寫氣體」才可補選；**多氣體／循環呼吸器鎖住**（DIK v0.7.8 原因標記）。
- 自由潛水／浮潛：列表、詳細、地圖、編輯都不顯示氣體。
- Zenobia、Shag Rock 等多氣體潛水：v1.3 維持未知氣體（PM 裁示 A）；**換氣重放排 v1.4（B）**。
- PM 10/10：無原因的舊資料（例：v0.7.2 前匯入的 Garmin FIT 技術潛水）**維持現狀**——重選水肺後可補選單一氣體。已 push 至 `32cab28`。

**10/10 驗證中另抓到並已修**：
- 🔴 自己引入的閃退：無障礙鍵改 `%@` 卻仍傳 Int ⇒ 開高氧潛水編輯頁 EXC_BAD_ACCESS（`0f7255b` 修）。
- 既有 bug：編輯頁存檔把潛水時間截成整分鐘（4674 → 4620 s，出水時間與水面間隔跟著變）⇒ 分鐘沒改就保留原秒數。
  ⚠️ App-u 的 `JD2UltraPhone/UI/Logbook/DiveLogEditSheet.swift` 結構相同，**未查**是否同病（家族待辦）。
- 已知未翻譯（使用者看不到）：DEBUG 開發者工具 4 鍵；上升速率警示 2 鍵（`showWarningEvents=false`）。

✅ 10/07 已完成：#3 Mac ⓘ 視窗空白（補 macOS 尺寸）、#4 Ceiling 膠囊 A 案（#1F66E0＋白字）——**macOS build 通過、165/0/1，未截圖目視**。
已答覆不改：#5 Suunto FIT 自由潛水判為水肺（模式欄讀不到，已是未知氣體；PM 接受）、#7 去重＝先匯入者留下、無格式優先、
#8 6/4 不顯示組織負荷＝96 h 內有 DAN DL7 範例檔（6/1、6/2，氣體不可信），非 6/3 DM5。

## 下一版待辦（PM 10/07）

- **匯入頁支援格式清單補 ATMOS FIT（PM 10/10 排 v1.4）**：`ImportWizardView.swift:281-306` `supportedFormatGroups` 無 ATMOS（`grep -ci atmos` 0），
  但 What's New 與三語 Description 已寫支援。補上後重拍 macOS 匯入頁截圖（兩欄會完整顯示清單）。
- **詳細頁「來源格式」手動新增顯示英文 "Manual Entry"（PM 10/10 排 v1.4；既有問題）**：`DiveLogDetailView.swift:496` 回傳字面字串，
  未走 `languageManager.localized`（catalog 已有 `Manual Entry` 鍵）。

- **文件整理（PM 10/10：送審後做，交給 App-lb）**：`V1_2_BACKLOG.md`（停在 9/13）、`docs/KNOWN_ISSUES.md`（停在 8/17）跟上 v1.3 結果
  （R-06 定位權限在地化、D7 ATS、P1-3 效能門檻 500 ms、181e441 SIGABRT 已修、D6 GDPR 延下一版）；文件登錄表補登 `V1_3_WORK_PLAN`／`SUBMISSION_CHECK_NEXT`／`KEYWORDS_NEXT_DRAFT`。

- **文字自動縮小 4 處（PM 10/10 排 v1.4）**：`DiveLogListView.swift:307,313`（統計列）、`DiveRowView.swift:114`（日期區塊）、`ImportWizardView.swift:694`（副檔名）。
  Xcode 27 建置下 `.minimumScaleFactor` 放得下也縮小（10/05 剖面讀數已改 `ViewThatFits`）；逐處改法相同，改完與 v1.2 截圖對照。App-u 22 處、App-i 38 處同型待查。

- **列表篩選（PM 10/07 同意記入）**：氣體（空氣／高氧／未知氣體）、潛水類型（水肺／自由潛水）、組織負荷（可顯示／不可顯示）。
  目的：找出「未知氣體」逐筆補正、分開自由潛水、找出拖累殘氮鏈的紀錄。待定：地圖與頂部統計是否跟著篩選。需 18 語字串＋ui-verify。
- **搜尋範圍擴充（PM 10/07 採納，與篩選同批）**：目前「搜尋地點…」只比對地點與備註（`DiveLogListView.swift:43-44`）⇒ 加潛伴、標籤、潛點名稱；
  有固定選項的（氣體、類型、組織負荷）交給篩選。提示文字一併改（不再只寫「地點」）。
- **環境：原始檔沒有就顯示「未記錄」（PM 10/07 採納）**：目前沒有任何解析器填 `environmentType`（全 Parsers 0 處；`DiveLog.swift:108` 預設 `seawater`）。
  🔴 **先查再改**：重放讀的是 `surfacePressureBar`／`metersPerBar`（`DiveReplayInput.swift:25-30`），不是環境字串——
  匯入時 `metersPerBar` 是否依淡水調整**未查證**；湖泊潛水（例 Lake Coleridge）可能以海水密度計算。改「未記錄」時要決定重放的預設密度。

- 「原始匯入資料」6 個來源鍵名（`cns`／`minPPO2`／`maxPPO2`／`altitudeRange`／`decoRequired`／`gasSwitches`）補在地化名稱（18 語）；`gasSwitches` 值是 JSON，需整理成可讀格式。

## 待 PM（未裁示，不阻擋送審）

- ~~App-lb 另有 4 處 `minimumScaleFactor`~~ → **PM 10/10：排 v1.4**（見「下一版待辦」）。
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

先讀本檔與 `docs/V1_3_WORK_PLAN.md` §八。驗證：`bash /Users/kevin/Documents/AppProject/_JD2-family/scripts/run_tests.sh logbook`（預期 171/0/1）。
