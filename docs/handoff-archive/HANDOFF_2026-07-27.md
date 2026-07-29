# HANDOFF — JD2-Logbook

> 交接文件（固定檔名滾動式；前一版在 docs/handoff-archive/HANDOFF_2026-07-26.md）。

## 交接時間

2026-07-27（產生方式：/handoff skill）

## 目前狀態

- 所在里程碑：v1.2 (Build 3) 送審準備收尾階段。這輪工作重點是「真機 VoiceOver
  完整走查」——先前一輪的 WCAG 審核多半是程式碼複查／模擬器測試，這次 PM 實際
  用真機 VoiceOver 把 4 個工作流走過一遍，抓到程式碼審查看不出來的真回歸，逐一
  修復；接著又追加模擬器 Dark Mode 像素級對比測試、NDL/Ceiling 母語術語修正。
- **工作樹乾淨，已 commit**（HEAD: `cd95e5e fix: real-device VoiceOver/Dynamic
  Type/locale bugs found in WCAG hardening pass`）。分支 `main` 領先
  `origin/main` 21 個 commit，尚未 push（未收到 push 指示）。
- 刻意保留為未追蹤的工作檔案（非原始碼，之前就已決定不進版控）：`Archive/` 內
  多個 CSV/xlsx/已處理完的稽核報告，皆已查證完畢歸檔，不需要處理。
- 共用層版本（家族專案）：DiveKit `v1.4.0`（工作樹領先 2 個未 tag 的 commit）、
  DiveImportKit `v0.4.1`（領先 1 個未 tag 的 commit），`check_family_drift.sh`
  全數通過（`═══ 通過：家族合流狀態健康 ═══`），無 drift。**本輪所有修復皆為
  App 層**，未觸碰任何共用 Kit 程式碼。

## 本輪完成的工作（cd95e5e 這個 commit 裡）

1. **真機 VoiceOver 走查抓到並修復 4 個回歸**：
   - `DiveLogDetailView.DetailRow` 的 accessibility label 直接內插未本地化的
     英文 key（畫面顯示正確中文，VoiceOver 卻唸英文），改用
     `languageManager.localized(label)`。
   - Entry Time 的 `DatePicker` VoiceOver 朗讀值不吃 `\.environment(\.locale)`
     （Apple 元件內部行為），用 `.accessibilityValue()` 蓋掉系統算出來的值。
   - 新增潛水「無法儲存」——實際是 `maxDepth == 0` 時 Save 鈕正確停用但零視覺/
     VoiceOver 提示。改用紅色星號（通用慣例，不用翻譯）+ 新增已 18 語言翻譯的
     「Required」key（PM 明確要求不要再用英文長句）。
   - 「潛水剖面圖」被 2026-07-26 一次翻譯縮短 commit 誤改成語意不同的「潛水
     曲線」，已改回。
2. **Locale／DateFormatter 連動修復**：泰文 `Locale` 預設佛曆曆法（年份顯示
   2569 非 2026，18 語言逐一測過只有泰文受影響）已強制 Gregorian 曆法；越南文
   `.medium` 日期格式全語系最長且含語意月份字詞，改用
   `numericDateTimeFormatter()`（純數字＋4 位數西元年＋各語系自然 12/24 小時制）。
3. **Dynamic Type AX5 崩版**：`DiveKitUI.DiveStatCell` 3 欄橫排卡片（列表統計列/
   詳情頁主要數據/地圖潛點卡片）在 AX5 極限字級視覺重疊，`DiveStatCell` 是
   DiveKit 共用元件不在本 App 動，改為 App 層 3 處呼叫端判斷
   `dynamicTypeSize.isAccessibilitySize` 切換直式排列。
4. **觸控目標／VoiceOver label**：月曆年份 chevron 32×32pt 改 44×44pt；macOS
   3 處工具列按鈕補上 `.accessibilityLabel()`（原本只有 `.help()`）。
5. **Dark Mode 對比**：用模擬器截圖＋Python/PIL 算 WCAG 對比公式（不是目測），
   抓到 `DiveRowView.dateBlock` 月/年標籤 3.91:1 不合格（系統 `.secondary`），
   改用 `Color.accessibleSecondary`，複測 9.25:1。
6. **母語術語修正**：克羅埃西亞文/希臘文「No Deco」改成國際通用縮寫「NDL」；
   繁中/簡中「Ceiling」改成「上限深度」/「减压顶」。

詳細技術細節見 `WCAG_2.1_AA_AUDIT_CHECKLIST.md` 附錄 4/5/6、
`docs/KNOWN_ISSUES.md`「已解決」表格。

## 進行中的決策（尚未定案）

1. **地圖 VoiceOver 下無法縮放/平移/展開聚合/選其他 pin**——查過程式碼沒發現
   退化或誤設定，判斷為 MapKit 在 VoiceOver 下的固有限制。PM 已決定「以後再
   做」，本輪不處理，記錄在 `docs/KNOWN_ISSUES.md`／`WCAG_2.1_AA_AUDIT_CHECKLIST.md`
   附錄 5，排入下一版 backlog。
2. **App Store Connect 提審資料**——`docs/APPSTORE_COPY.md` 已有 v1.0 時期的
   完整草稿（App 名稱/副標題/繁中英文日文描述/關鍵字/隱私政策 URL），內容主體
   應仍適用，但：
   - 「What's New」段落還是 v1.0 內容，需要換成 v1.2 內容
   - 關鍵字沒反映 v1.1/v1.2 新增的匯入格式（Shearwater/DAN DL7/Garmin Connect
     JSON 等）
   - **螢幕截圖是真正的缺口**：`_ScreenCaptures/` 裡的是 2026-06（v1.0）舊圖，
     這輪 UI 有變動（必填星號、Trimix footer 等），需要重拍；完全沒有 iPad 截圖
   - IAP 項目在 ASC 的審核狀態沒有文件紀錄，需要 PM 直接看 ASC 後台
   - Bundle ID／Signing Certificate／Archive 已用「v1.0 已用同一 ID 審核通過」
     +「這輪 Archive 成功安裝到 PM 的 iPhone 16」確認過，不用再做
3. **希臘文／克羅埃西亞文的其他翻譯**（非 No Deco/Ceiling 這兩個這次已修的）
   仍偏長，暫用 `.minimumScaleFactor` 保底，未經母語審核不敢進一步縮短。

## 下一步（按順序，具體到可直接執行）

1. **`docs/APPSTORE_COPY.md` 的 What's New 段落改寫成 v1.2 內容**——名稱/副標題/
   主體描述不用動，只有這段跟關鍵字需要更新。
2. **重拍 App Store 截圖**（iPhone 6.7" 必須、iPad 可選）——這輪 UI 有變動，
   舊的 `_ScreenCaptures/` 素材不能直接用。
3. **去 App Store Connect 後台**：確認 IAP 項目審核狀態、把更新後的 ASC 資料
   （名稱/副標題/描述/關鍵字/截圖/隱私政策 URL）貼上去。
4. 排一次真機 VoiceOver 覆測（比照 `WCAG_2.1_AA_AUDIT_CHECKLIST.md` 附錄 3
   的腳本），確認這輪 4 項修復＋Dark Mode 對比修復在實機上真的有改善（這輪
   驗證只到模擬器截圖／PM 口頭確認「測試OK」的程度）。
5. 確認 `main` 是否要 push 到 `origin`（目前領先 21 個 commit，尚未 push，
   之前的交接都沒收到 push 指示，這次也還沒問過）。
6. `_JD2-family/reports/R-2026-07-26-App內語言切換未涵蓋DateFormatter與Calendar.md`
   裡提到 JD2-ultra 有同款 DateFormatter/Calendar 破口尚未查證修復——這是家族
   層工作，不是 Logbook 這邊的下一步，但交接時提醒一下，總指揮 session 可能
   會排進去。

## 陷阱提醒

- **這輪最大的教訓：程式碼審查/模擬器測試 ≠ 真的聽了 VoiceOver 唸什麼**。
  `DetailRow`／`DatePicker` 這兩個回歸在純程式碼審查階段完全看不出來（程式碼
  邏輯看起來沒問題），只有真機開 VoiceOver 實際聽了才抓到。以後任何「VoiceOver
  label 正確」的驗收，沒有真機朗讀過就不要打勾。
- **同理，Dark Mode 對比也不能只靠模擬器截圖用眼睛看**——這次用 Python/PIL
  寫腳本直接套 WCAG 相對亮度公式算出真實對比值，才抓到 `DiveRowView.dateBlock`
  的 3.91:1（用眼睛看这個灰階差異很難分辨是不是不合格）。以後任何色彩對比
  複查，能寫腳本算真數值就不要用眼睛判斷。
- **翻譯縮短 ≠ 翻譯正確**——2026-07-26 那次「縮短過長翻譯」的 commit
  （`9eb43e3`）在日文/越南文做得是忠實縮短（拿掉贅字保留原意），但中文那批
  把「剖面圖」直接換成語意不同的「曲線」，是誤譯不是縮短。以後任何「跨語言
  批次縮短」都要個別檢查語意有沒有跑掉，不能只看長度有沒有變短。
- **新增使用者可見的必填/提示文字，不要用英文長句當 stopgap**——這次一開始
  用「Max Depth is required to save this dive.」的英文 key 想之後再翻譯，
  PM 直接說這樣不隨語系切換觀感很差，改用「紅色星號 + 已翻好 18 語言的
  'Required' 單字」。以後遇到類似情境（常見、通用的 UI 詞彙如
  必填/必選/選填等），直接花時間翻好 18 語言，不要留英文 stopgap。
- **模擬器文字輸入可能被 Mac 主機的鍵盤輸入法攔截**——這次 Mac 主機當下輸入法
  是中文注音，透過模擬器硬體鍵盤透傳打數字時被組字攔截，打不出純數字。這是
  環境問題不是 App bug，遇到時不要一直重試，改請 PM 真機確認即可。
- **ASC 送審資料不是從零開始**——這次一開始以為「App 名稱/描述/關鍵字/截圖/
  隱私政策 URL 一項都沒填」，實際查文件發現 `docs/APPSTORE_COPY.md` 早就有
  v1.0 時期的完整草稿，只是沒人再看過。以後遇到「這個是不是都要重做」的疑問，
  先搜一次 repo 裡的文件，不要假設沒做。

## 開場指令建議（給下一個 session）

先讀本檔＋`WCAG_2.1_AA_AUDIT_CHECKLIST.md` 附錄 4/5/6（這輪真機 VoiceOver 回報
與修復的完整記錄）；不需要重新驗證 build 狀態或家族層同步（本次交接已用實際
指令確認皆無異常）。開場第一件事應該是跟 PM 確認「下一步」列出的 5 項裡，
最想先處理哪一個——如果 PM 手上還有真機，第 4 項（VoiceOver 覆測）最適合趁勢
繼續；如果沒有，第 1/2/3 項（ASC 送審資料整理）不需要真機也能推進。
