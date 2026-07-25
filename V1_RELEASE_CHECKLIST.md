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
- [ ] 日誌列表正常顯示、可滑動
- [ ] 日誌詳情頁所有欄位顯示正確
- [ ] 新增潛水（手動輸入）可儲存
- [ ] 編輯潛水可儲存
- [ ] 刪除潛水有確認 dialog

### 廣告 & IAP（僅 iOS；macOS 無廣告、無 IAP，2026-07-14 起為純免費版）
- [x] AdMob 廣告在真機上正常載入顯示（Logbook / Import / Settings）— 2026-07-25 真機驗證通過
- [x] 廣告載入失敗時不留空白塊（自動收合）— 程式碼邏輯確認（`AdBannerView` 載入失敗自動收合高度）
- [x] Premium 用戶廣告自動隱藏 — 2026-07-25 真機驗證通過
- [x] IAP「Remove Ads $1.99」購買流程完整 — 2026-07-25 Sandbox 真機驗證 PASS
- [x] Restore Purchase 可恢復購買記錄 — 2026-07-25 正向／反向情境（含 Clear Purchase History 後測試）皆 PASS

### 本地化
- [ ] 繁體中文顯示正確（主要目標語言）
- [ ] 英文（en）顯示正確
- [ ] 簡體中文（zh-Hans）顯示正確
- [ ] 日文（ja）抽樣驗證
- [ ] 韓文（ko）抽樣驗證
- [ ] 主要歐洲語言（fr / de / es / it）抽樣驗證
- [ ] 東南亞語言（id / ms / vi / th）抽樣驗證
- [ ] 日期 / 時間格式隨語言本地化
- [ ] 數字單位（深度 m/ft、溫度 °C/°F）顯示正確

---

## 🟡 建議完成（強烈建議，影響審核通過率）

### GPS & 地圖
- [ ] 新增潛水可記錄 GPS 座標
- [ ] 地圖正確顯示潛點 pin
- [ ] 地圖空狀態顯示正常

### 可達性 WCAG 2.1 AA
- [ ] 色彩對比 ≥ 4.5:1（主要文字）
- [ ] 所有互動元素 VoiceOver label 正確
- [ ] 觸控目標 ≥ 44×44pt
- [ ] Dynamic Type 放大不破版
- [ ] 詳見 `WCAG_2.1_AA_AUDIT_CHECKLIST.md`

### 性能
- [ ] 日誌列表滑動流暢（60fps）
- [ ] 地圖載入 100+ 潛點 < 200ms
- [ ] 冷啟動時間合理（< 3 秒）

### 穩定性
- [ ] 模擬器連續操作 30 分鐘無閃退
- [ ] 真機測試無閃退
- [ ] 記憶體無明顯洩漏

---

## 🟢 App Store 提審準備

### 帳號 & 簽署
- [ ] Bundle ID 確認（App Store Connect 已建立）
- [ ] Signing Certificate & Provisioning Profile 正常
- [x] Version 1.2 (3) 確認 — 2026-07-25 `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` 已更新，iOS + macOS build 通過
- [ ] Archive 成功 — 尚未實際跑 Product → Archive

### App Store Connect
- [ ] App 名稱、副標題填寫
- [ ] 描述（繁中 + 英文）
- [ ] 關鍵字填寫
- [ ] 截圖（iPhone 6.7"、iPad 可選）上傳
- [ ] App 圖示 1024×1024 上傳
- [ ] 隱私政策 URL 填寫
- [x] 年齡分級填寫 — 2026-07-25 重新填寫（Advertising=Yes，其餘功能性問題如實回答 No），非原本的 4+ 單一勾選，實際等級由問卷結果決定
- [x] 廣告聲明勾選（含廣告）— 2026-07-25 Age Rating 問卷 Advertising 已改 Yes
- [x] App Privacy 問卷：Location／Device ID／Usage Data 的「used to track」改為 No — 2026-07-25 完成（原本誤標為 Yes 是這次送審駁回原因之一，見 `V1_2_BACKLOG.md` #1）
- [ ] IAP 項目在 App Store Connect 建立並審核通過

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
