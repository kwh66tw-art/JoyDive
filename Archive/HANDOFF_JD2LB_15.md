# HANDOFF — JoyDive² 交接文件

> 新對話串接手前必讀。本文件記錄截至 2026-06-07 的專案狀態、已完成工作、v1.0 待辦與 v1.1 規劃。

---

## 專案快覽

- **App 名稱**：JoyDive²（² = Unicode U+00B2，不是上標 HTML，直接字元）
- **平台**：iOS 17.0+ / macOS 14.0+，Swift 6，SwiftData
- **目標上線**：2026 年 8 月 18 日
- **Xcode 專案**：`JD2-Logbook/JD2-Logbook/JD2-Logbook.xcodeproj`
- **最新 commit**：`ad894c7` — feat: set Display Name to JoyDive², add debug premium toggle for screenshots

---

## 本輪已完成（2026-06-07）

### Code

| 項目 | 說明 |
|------|------|
| 匯入器設計原則 header | `DiveLogImporter.swift` 頂部加入「只做單位換算，不做值的正確性判斷」說明 |
| 平均深度 → Notes | UDDF / Subsurface XML+CSV / Garmin FIT 均已解析 `avgdepth`，附加在 Notes「— Import data —」區塊 |
| 裝置序號/韌體 → Notes | UDDF / Subsurface XML 解析 deviceModel、S/N、FW；Garmin 暫缺（FitFileParser string field API 不確定，v1.1 補） |
| 移除 AdMob test device ID | `JD2_LogbookApp.swift` 已清除 `testDeviceIdentifiers` 整個 block |
| Display Name | `project.pbxproj` + `Info.plist` 均已設定 `CFBundleDisplayName = JoyDive²`，iOS 模擬器已確認正確 |
| Debug Premium toggle | `Settings → Developer Tools → Simulate Premium (No Ads)`：開啟後隱藏廣告供截圖用，重啟維持（UserDefaults `DEBUG_isPremiumOverride`），僅 DEBUG build 可見 |

### 文件 / 行政

| 項目 | 說明 |
|------|------|
| 聯絡信箱 | 所有文件改為 `joydive.app@gmail.com` |
| 文件格式 | 全部英文完整版在上、中文完整版在下，不混排 |
| App 名稱統一 | 所有文件「JD2 Dive Logbook」→「JoyDive²」 |
| GitHub Pages | repo `kwh66tw-art/JoyDive`，main branch，已啟用 |
| 隱私政策 URL | `https://kwh66tw-art.github.io/JoyDive/logbook/privacy` |
| `Docs/APPSTORE_COPY.md` | Privacy Policy URL 已填入正式網址 |

---

## v1.0 剩餘待辦（上線前必須完成）

詳見 `V1_RELEASE_CHECKLIST.md`，以下為關鍵項目：

### 需付費解鎖
- [ ] **Apple Developer Program 年費 $99**（沒繳就無法提審、無法測 IAP）

### 需真機驗證
- [ ] AdMob 廣告真機顯示正常（移除 test ID 後需確認）
- [ ] IAP「移除廣告」購買流程（需先在 App Store Connect 建立 IAP 產品）

### App Store Connect 提審
- [ ] Xcode Target → General → **Display Name 改為 `JoyDive²`**
- [ ] 準備截圖（iPhone 6.7" 必選，iPad 可選）：見 `Docs/APPSTORE_COPY.md` 截圖建議
- [ ] 填入 App Store Connect 所有欄位（描述、關鍵字、截圖、Privacy Policy URL）
- [ ] Privacy Policy URL：`https://kwh66tw-art.github.io/JoyDive/logbook/privacy`（已可用，確認頁面渲染正常）

---

## v1.1 規劃（⚠️ 新對話串重要提醒）

以下功能已確認列入 v1.1，接手時請確保不要誤以為是 v1.0 範疇：

### 1. 互動式潛水剖面圖

- 目前 `profileSamplesJSON` 格式：`[{t, d}]`
- v1.1 需擴充為：`[{t, d, temp}]`（加入每個採樣點的水溫）
- 實作時需處理 schema migration（SwiftData）
- 所有匯入器需同步更新 temp 欄位解析

### 2. 組織艙飽和度視覺化（類 Suunto DM5 風格）

- **不需要匯入任何新欄位**（CNS/OTU/NDT/TTS/Ceiling 都是計算結果，非原始資料）
- 資料來源：現有 `profileSamplesJSON`（深度時間序列）+ `gasMixJSON`（氣體混合）
- 演算法：Bühlmann ZHL-16C，需新增獨立模組
- 互動剖面圖中，特定時間點可顯示當下各組織艙的氮飽和度

### 3. 裝置序號/韌體專屬欄位

- v1.0 目前是 workaround：附加在 Notes「— Import data —」區塊
- v1.1 規劃：SwiftData model 新增 `importExtrasJSON` 欄位，結構化儲存
- 需處理 migration

### 4. 平均深度專屬欄位

- 同上，v1.0 存在 Notes，v1.1 遷移至 `avgDepth: Double?` 專屬欄位
- 需處理 migration

### 5. Garmin FIT 裝置資訊

- v1.0 跳過（FitFileParser string field API 不確定）
- v1.1 補上裝置型號、序號解析

---

## 關鍵設計原則（匯入器）

> **只負責單位換算，不做值的正確性判斷。**

原始資料照單全收，換算為 SI 單位後存入 model。不合理的值（如深度 0.1m、時間 2 秒）由 UI 層標記或過濾，不在匯入器處理。

---

## 重要慣例

- 勿手動腳本編輯 `project.pbxproj`
- `fileSystemSynchronizedGroups`：新增/刪除 `.swift` 自動進出 build
- `buddy` 欄位已移除，模擬器舊資料需 Erase All Content
- 改 code 後先停，等 PM build 確認再 commit
- `git index.lock` 殘留：`rm -f .git/index.lock .git/HEAD.lock`（Mac 端執行）

---

## 關鍵文件索引

| 文件 | 用途 |
|------|------|
| `CLAUDE.md` | Agent 接手必讀，專案總覽 |
| `ARCHITECTURE.md` | 模組設計、SwiftData schema |
| `CHANGELOG.md` | 版本異動紀錄 |
| `V1_RELEASE_CHECKLIST.md` | 上線前驗證清單 |
| `PRIVACY_POLICY.md` | App Store 隱私政策正文（英/中） |
| `Docs/APPSTORE_COPY.md` | App Store 描述文案、截圖規劃 |
| `Docs/KNOWN_ISSUES.md` | 已知問題、v1.1 規劃細節 |
| `Docs/ADMOB_IAP_SETUP.md` | AdMob App ID / Ad Unit ID / IAP 設定 |
| `Docs/GitHubPages/logbook/privacy.md` | GitHub Pages 隱私政策原始檔 |
