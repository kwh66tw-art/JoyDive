# JD2-Logbook 上線前檢查清單

> 本檔案名稱沿用自 v1.0 首次提審，v1.1/v1.2 各輪持續沿用同一份清單追蹤，不另開新檔。
> **最後更新請見 `git log -- V1_RELEASE_CHECKLIST.md`**（不手動維護日期戳，這份清單常是逐項
> 勾選/補註記，容易改了內容卻忘記同步頂部日期，比照 `CLAUDE.md`「最新 commit」慣例改指 git log）。

**目標上線日**：2026 年 8 月 18 日  
**目前送審版本**：1.2 (Build 3)

---

## ✅ 已解決（原「待決策」，見 `docs/KNOWN_ISSUES.md`）

- [x] macOS/iOS `Info.plist` 的 `LSApplicationCategoryType`：已改為 `public.app-category.healthcare-fitness`，ASC Category 欄位同步更新，真機驗證修復生效（2026-07-25）

---

## 🔴 必須完成（Block release）

### 編譯 & 測試
- [x] 所有 target 編譯無誤（iOS + macOS）— 2026-07-17 驗證
- [x] 解析器單元測試全部通過（`xcodebuild test`）— 2026-07-17 驗證
- [x] 解析器測試覆蓋率 > 85% — `DiveLogImporter.swift` 89.1%（2026-07-17）

### 匯入功能
- [x] UDDF 匯入成功（測試 3+ 檔案）— 2026-07-25 `00_Import_test_scenes/ITS_01/05`
- [x] Subsurface XML / .ssrf 匯入成功 — 2026-07-25 ITS_01/02（含單檔多潛水情境）
- [x] Subsurface CSV 匯入成功（含多行 notes、引號轉義）— 2026-07-25 ITS_01/03
- [x] Suunto JSON 匯入成功 — 2026-07-25 ITS_01
- [x] 批量匯入 20+ 檔案，成功率 > 95% — 2026-07-25 ITS_02/03（8～29 個檔案的批次皆正常）
- [x] 匯入失敗時顯示正確錯誤訊息 — 2026-07-25 ITS_04（去重＋3 種壞檔皆正確處理不中斷整批）；⚠️ 過程中發現 `DiveImportKit` 的錯誤訊息內容部分仍為中文技術性描述，非本次範圍，見 `_JD2-family/reports/R-2026-07-25-DiveImportKit錯誤訊息未本地化.md`

### UI 核心功能
- [x] 日誌列表正常顯示、可滑動 — 2026-07-27 模擬器驗證（iPhone 17 Simulator，105 筆假資料，swipe 捲動正常）
- [x] 日誌詳情頁所有欄位顯示正確 — 2026-07-26 真機截圖確認（繁中，含能見度/入出水時間/配重/備註/原始匯入資料等欄位），修復過程中順便發現並修掉配重/氣瓶壓力英制單位未換算的獨立 bug
- [x] 新增潛水（手動輸入）可儲存 — 2026-07-27 PM 真機測試 OK（模擬器端到端測試卡在 Mac 主機鍵盤輸入法問題，已改由真機確認）
- [x] 編輯潛水可儲存 — 2026-07-26 發現並修復一個嚴重 bug：trimix 潛水按 Edit 再 Save（即使只改備註）氣體資料會靜默降級成 Air 且不可逆，已修復；一般編輯可儲存流程 2026-07-27 PM 真機測試 OK
- [x] 刪除潛水有確認 dialog — 2026-07-27 模擬器驗證：「刪除這筆潛水紀錄？此操作無法復原。」對話框正常彈出，紅色刪除鈕正確標示（測試時取消未實際刪除）

### 廣告 & IAP（僅 iOS；macOS 無廣告、無 IAP，2026-07-14 起為純免費版）
- [x] AdMob 廣告在真機上正常載入顯示（Logbook / Import / Settings）— 2026-07-25 真機驗證通過
- [x] 廣告載入失敗時不留空白塊（自動收合）— 程式碼邏輯確認（`AdBannerView` 載入失敗自動收合高度）
- [x] Premium 用戶廣告自動隱藏 — 2026-07-25 真機驗證通過
- [x] IAP「Remove Ads $1.99」購買流程完整 — 2026-07-25 Sandbox 真機驗證 PASS
- [x] Restore Purchase 可恢復購買記錄 — 2026-07-25 正向／反向情境（含 Clear Purchase History 後測試）皆 PASS

### 本地化
- [x] 繁體中文顯示正確（主要目標語言） — 2026-07-26 多輪真機截圖確認（Settings/Edit/Detail 頁）
- [x] 英文（en）顯示正確 — 全程作為原文基準，18 語言 xcstrings 全數以此為源
- [ ] 簡體中文（zh-Hans）顯示正確 — 內容已審過（含用詞在地化：设备/条 等），未實機截圖確認畫面
- [ ] 日文（ja）抽樣驗證
- [ ] 韓文（ko）抽樣驗證
- [ ] 主要歐洲語言（fr / de / es / it）抽樣驗證 — 2026-07-26 德文真機截圖發現並修復 2 處截斷（Wassertemp./Deco-Ceiling），法文/西班牙文內容已審但未實機截圖，義大利文未特別檢查
- [ ] 東南亞語言（id / ms / vi / th）抽樣驗證 — 2026-07-26 泰文真機截圖發現並修復截斷（No Deco），印尼文/馬來文內容已多輪審過，越南文內容已審但未實機截圖
- [ ] 日期 / 時間格式隨語言本地化
- [x] 數字單位（深度 m/ft、溫度 °C/°F、配重 kg/lbs、氣瓶壓力 bar/psi）顯示正確 — 2026-07-26 真機截圖確認英制正確換算（能見度/配重/氣瓶壓力），並修復 `DiveLogDetailView`/`DiveLogListView` 兩處先前遺漏的獨立硬編碼 bug；詳見 `V1_2_BACKLOG.md` #18/#20/#23

---

## 🟡 建議完成（強烈建議，影響審核通過率）

### GPS & 地圖
- [x] 新增潛水可記錄 GPS 座標 — 2026-07-26 使用者實機確認
- [x] 地圖正確顯示潛點 pin — 2026-07-26 使用者實機確認
- [x] 地圖空狀態顯示正常 — 2026-07-26 使用者實機確認

### 可達性 WCAG 2.1 AA
- [x] 色彩對比 ≥ 4.5:1（主要文字）— 2026-07-26 程式碼複查：沿用 2026-06-01 已修的 `Color.accessibleSecondary`，本輪新增欄位（配重/氣瓶壓力）走既有 `DetailRow`/系統 Form 背景，未發現新退化
- [x] 所有互動元素 VoiceOver label 正確 — 2026-07-26 程式碼複查：抓到 macOS 3 處只有 `.help()` 沒有 `.accessibilityLabel()` 的工具列按鈕（`MainTabView.swift`），已補齊
- [x] 觸控目標 ≥ 44×44pt — 2026-07-26 程式碼複查：抓到月曆年份切換 chevron 按鈕僅 32×32pt，已改 44×44pt + `.contentShape`；其餘小尺寸 frame 皆為裝飾性非互動元素
- [x] Dynamic Type 放大不破版 — 2026-07-26 **模擬器實測**（iPhone 17 Simulator，`xcrun simctl ui content_size accessibility-extra-extra-extra-large`）：字級本身確實會縮放（延續 2026-06-01 結論），但抓到程式碼複查看不出來的真違規——3 處「圖示＋數值＋單位＋標籤」3 欄橫排卡片（日誌列表統計列、詳情頁主要數據、地圖潛點卡片）在 AX5 極限字級下視覺重疊/裁切，`minimumScaleFactor` 保護不住。已修：3 處皆改成 `dynamicTypeSize.isAccessibilitySize` 時改直式排列，模擬器截圖覆測確認正常
- [x] 詳見 `WCAG_2.1_AA_AUDIT_CHECKLIST.md`（附錄 2 已更新為模擬器實測結果，非純程式碼複查）
- [x] **真機 VoiceOver 完整工作流測試（第 2.6 節／附錄 3）**— 2026-07-27 PM 實機測試：日誌列表、新增/編輯潛水、詳情頁、語言切換等流程皆通過（含本輪修復的 `DetailRow` 英文殘留、Entry Time 唸英文、Save 鍵無提示、「潛水剖面圖」誤譯 4 項回歸驗證）。**地圖流程未通過**——VoiceOver 下無法縮放/平移/展開聚合/選其他 pin，判斷為 MapKit 固有限制，非本輪退化，見附錄 4/5，暫列已知限制，日誌列表可作為視障使用者瀏覽潛點的替代路徑

### 性能
- [x] 日誌列表滑動流暢（60fps）— 2026-07-26 使用者實機確認
- [x] 地圖載入 100+ 潛點 < 200ms — 2026-07-26 使用者實機確認
- [x] 冷啟動時間合理（< 3 秒）— 2026-07-26 使用者實機確認

### 穩定性
- [x] 模擬器連續操作 30 分鐘無閃退 — 2026-07-26 使用者實機確認
- [x] 真機測試無閃退 — 2026-07-26 使用者實機確認
- [x] 記憶體無明顯洩漏 — 2026-07-26 使用者實機確認

---

## 🟢 App Store 提審準備

### 帳號 & 簽署
- [x] Bundle ID 確認（App Store Connect 已建立）— `com.jd2logbook.JD2-Logbook`（`project.pbxproj`），v1.0 已用同一 Bundle ID 送審且 macOS 已通過審核，確認有效註冊
- [x] Signing Certificate & Provisioning Profile 正常 — `DEVELOPMENT_TEAM = 77UHM3NN7J`（HUA SHENG Huang）、`CODE_SIGN_STYLE = Automatic`；2026-07-27 PM 確認 Archive 已成功跑過並安裝到 iPhone 16 實機，簽署鏈正常
- [x] Version 1.2 (3) 確認 — 2026-07-25 `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` 已更新，iOS + macOS build 通過
- [x] Archive 成功 — 2026-07-27 PM 確認已跑過 Product → Archive 並安裝至 iPhone 16

### App Store Connect
- [x] App 名稱、副標題填寫 — 「JoyDive²」／「Log Every Dive, Every Story」沿用不變，確認正確
- [x] 描述（繁中 + 英文 + 日文）— 2026-07-28 依 `docs/APPSTORE_COPY.md` 最終版套用至 iOS + macOS 兩平台三語頁面
- [x] What's New（版本說明）— 2026-07-28 三語套用（iOS 因非升級版本無此欄位；macOS 因 1.0 為已核准版本、算正常升級，故有此欄位）
- [x] 關鍵字填寫 — 2026-07-28 三語套用最終版（`dive log,scuba,logbook,Shearwater,UDDF,Garmin,Suunto,Subsurface,nitrox,dive computer,freediving`，`underwater` 已換成 `Shearwater`），iOS + macOS 兩平台皆已套用
- [x] 截圖（iPhone、Mac）上傳 — 三語（EN/繁中/日文）皆已重拍並確認尺寸正確，iOS + macOS 兩平台皆已上傳
- [x] App 圖示 1024×1024 上傳 — `Assets.xcassets/AppIcon.appiconset` 已有 light/dark/tinted/mac 四組 1024px（2026-06-06 建立，v1.0 已用此圖示送審且通過），`V1_2_BACKLOG.md` #2 PM 已明確決定「icon 全盤 review 延後到下一版，非本輪阻塞項」，此輪維持現狀即可
- [x] 隱私政策 URL 填寫 — `https://kwh66tw-art.github.io/JoyDive/logbook/privacy`，2026-07-28 於 ASC App Privacy 頁面現場確認存在且正確
- [x] 年齡分級填寫 — Advertising=Yes，其餘功能性問題如實回答 No，2026-07-28 於 ASC 現場重新開啟問卷逐項確認仍然正確
- [x] 廣告聲明勾選（含廣告）— Age Rating 問卷 Advertising=Yes，2026-07-28 現場確認
- [x] App Privacy 問卷：Location／Device ID／Usage Data 的追蹤宣告 — **2026-07-25 記錄「已改為 No」但實為誤記**：2026-07-28 送審前逐格重新核對 ASC 現況，發現三格的「Purpose」問卷實際仍勾著「Third-Party Advertising」（與程式碼查核結果不符，App 本身無 ATT/IDFA/追蹤行為），2026-07-25 的操作應是漏改了這一格。2026-07-28 已重新逐格取消「Third-Party Advertising」、改勾「App Functionality」，Linked-to-identity／Tracking 兩問確認皆為 No，Publish 後重新整理頁面截圖驗證三格皆顯示「Used for App Functionality」。詳見 `docs/reports/R-2026-07-28-iOS送審駁回二次核查與修正.md`
- [x] Declare Regulated Medical Device 聲明 — 2026-07-28 新增欄位，回答 No（App 不構成醫療器材）
- [x] Export Compliance — 2026-07-28 iOS + macOS Build 3 皆回答「None of the algorithms mentioned above」
- [ ] IAP 項目在 App Store Connect 建立並審核通過 — 沒找到相關文件紀錄，需要 PM 直接在 ASC 後台確認狀態

### 送審提交
- [x] **iOS App 1.2 (Build 3) 已送出審核** — 2026-07-28，狀態 Waiting for Review（修正 2.3.6／5.1.2(i) 兩項駁回理由後 Resubmit）
- [x] **macOS App 1.2 (Build 3) 已送出審核** — 2026-07-28，狀態 Waiting for Review（macOS 1.0 為已核准狀態，此為正常升級非重審）

---

## ✅ 已完成

- [x] 所有 target 部署目標統一 iOS 17.0 / macOS 14.0
- [x] 死碼清理（ContentView、placeholder views 等）
- [x] DiveLog.buddy 欄位移除
- [x] DiveLogEditSheet macOS O₂ 重複顯示 bug 修正
- [x] AdMob SDK v11 接入（App ID + 4 個 Ad Unit ID）
- [x] i18n 18 種語言實裝（xcstrings）

---

## 🟢 已列 v1.1（本次不需處理）

- iOS 18 Control Center 擴展／Lock Screen Widget — PM 確認不需要，終止規劃（見 `V1_1_BACKLOG.md` #9/#10）
- ~~地圖「回到我的位置」recenter 按鈕~~ — v1.1 已完工
- ~~測試覆蓋率 > 85% 驗證~~ — v1.1 已完工（`DiveLogImporter.swift` 89.1%）

## 🟢 已列 v1.2（本次不需處理，下一版再開放）

- Export/Import Backup 功能 — v1.1 已實作但本輪未完整測試，先隱藏 UI（`showBackupSection = false`），下一版驗證後開放，見 `V1_2_BACKLOG.md` #11
- App 內 icon 全盤 review — 延後到下一版，見 `V1_2_BACKLOG.md` #2
- 剖面圖警示標記／狀態列第二列（上升速度警示） — 已實作但先隱藏（`showWarningEvents = false`），呈現方式待改版再定案，見 `V1_2_BACKLOG.md` #3

## 🟡 下一版重點工作（v1.2 審核通過後排入，2026-07-28 使用者指示）

- **匯入結果動態數量字串的 Vary-by-Plural 修復**（`ImportWizardView.swift`
  `"%lld dive%@ imported"`／`"%lld skipped (duplicates)"`）——**這是現在就
  能看到的顯示 bug**：18 種語言裡 count≠1 時畫面會混進一個字面英文 "s"
  （手動判斷單複數後綴的寫法對非英語式複數規則完全沒有對應機制），不是
  單純的翻譯精緻度問題。已有完整技術方案：`_JD2-family/
  F-09-PLURAL_LOCALIZATION_GUIDE.md` §3「兩個 App 的技術路徑不同」——
  Logbook 因為用自訂 `AppLanguageManager.localized()`＋`String(format:)`
  支援 App 內建語言切換器，繞過 Apple 原生 stringsdict 解析機制，需要
  改用 `String(localized:locale:)`（明確傳 `languageManager.locale`）並在
  模擬器切換至少 en/hr/ja 三種語言實測，確認沒有破壞四段式語言切換機制。
  ultra 端同款字串已修復（commit `a689836`）可參考做法差異。
  **使用者明確指示**：v1.2 審核通過後、下次改版前找時間處理，本輪不動。
