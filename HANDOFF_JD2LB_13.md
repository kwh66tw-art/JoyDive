# JD2-Logbook 交接手冊 #13（2026-06-02）

接續 HANDOFF_JD2LB_12。本輪完成死碼清理、部署目標統一、UI 修正、資料夾整理。

---

## 一、專案現況

- iOS + macOS（SwiftUI / SwiftData）潛水日誌 App，雙平台共用大部分 View。
- **可編譯、可執行**。
- 部署目標：所有 target 統一 **iOS 17.0 / macOS 14.0**（本輪已修正）。
- 專案用 **fileSystemSynchronizedGroups**：新增/刪除 .swift 檔自動進出 build，不需手動改 pbxproj。

---

## 二、本輪已完成並 commit（重點）

### commit 56dc1a3 — 死碼清理 + .gitignore + UI 修正
- **刪除死碼**：
  - `ContentView.swift`（Xcode 樣板殘留）
  - `SettingsPlaceholderView.swift`、`MapPlaceholderView.swift`（placeholder）
  - `JD2Core/Models/DiveLogTests.swift`（被編進 app target 的非正式測試）
  - `JD2-LogbookTests/DiveExporterTests.swift`、`DiveExporterEdgeCaseTests.swift`（DiveExporter 已移除，這兩個檔引用它導致編譯失敗）
- **DiveLog.buddy 欄位移除**：UI 早已移除，SwiftData schema 一併清乾淨。
  - ⚠️ schema 變更：首次執行若模擬器有舊資料需 Erase All Content。
  - 連帶清除：`MockDataSeeder` 的 `mockBuddies` 陣列與 buddy 賦值行。
  - `Localizable.xcstrings` 移除 `Buddy` / `Buddy Name (optional)` / `No buddy recorded.` 三個 key。
- **MainTabView**：移除過時「Edit/Export 100% 渲染穩定」註解（Export 已移除）。
- **DiveLogEditSheet**：
  - Slider label 改 `EmptyView()`（修 macOS 高氧頁面 `O₂ O₂ %` 重複顯示 bug）。
  - `O₂` label 顏色從 `.secondary` 改 `.primary`（與 Max Depth / Water Temp 等欄位一致）。
- **新增 `.gitignore`**：排除 `*.lock`、`*.backup`、`build_*.log`、`.DS_Store` 等。

### commit deda6ca — 統一部署目標
- `IPHONEOS_DEPLOYMENT_TARGET`：26.5 / 17.6 → **17.0**（全 target）
- `MACOSX_DEPLOYMENT_TARGET`：14.6 → **14.0**（全 target）

### 資料夾清理（未 commit，純檔案整理）
- 根目錄 .py 腳本、build log、舊 audit report 全部刪除。
- 舊 HANDOFF（WEEK2～JD2LB_10）及舊規劃文件移入 `Archive/`。
- 根目錄保留：`CLAUDE.md`、`HANDOFF_JD2LB_12.md`、`JD2_12WEEK_FINAL_PLAN.md`、`UI_UX_SPEC.md`、`WCAG_2.1_AA_AUDIT_CHECKLIST.md`。

---

## 三、v1.0 待辦（尚未做）

### 🔴 上線前必須處理

- **AdMob 正式接入**（PM 正在申請帳號）：
  - 目前 SDK 未加入、無 `GADMobileAds.start()`、無 `GADApplicationIdentifier`。
  - ⚠️ **release 風險**：未接 SDK 時，`PremiumAwareAdBanner` 佔位框（「Ad Banner · …」）在正式版也會顯示。
  - 啟用步驟見 `AdBannerView.swift` 開頭註解。
  - **建議**：PM 拿到 AdMob App ID 後，依 `AdBannerView.swift` 說明接入 SDK。

### 🟡 建議在上線前完成

- **v1.0 上線前完整檢查清單**（尚未建立，可參考 `JD2_12WEEK_FINAL_PLAN.md` Week 12 的里程碑清單）。

### 🟢 已確認列 v1.1

- iOS 18 widgets（Control Center 擴展、Lock Screen Widget）。
- 地圖「回到我的位置」recenter 按鈕。
- 測試覆蓋率驗證（解析器 > 85%）。

---

## 四、重要慣例／雷區

- **勿手動腳本編輯 pbxproj**（曾破壞檔案）。同步資料夾下純刪/增 .swift 檔安全。
- **git index.lock 殘留**：`rm -f .git/index.lock .git/HEAD.lock`（需在 Mac 端，沙箱無權限）。
- **xcstrings 空 `""` key**：來源已改 `Text(verbatim:"")` 根治，若再出現找新的空字面量。
- **SwiftData schema 變更**：本輪移除 `buddy` 欄位，模擬器舊資料需重置。
- **回報慣例**：雙平台改動需明確標註；改 code 後先停、等 PM build 確認再 commit。

---

## 五、最近 git 提交（節錄）

```
deda6ca chore: 統一部署目標 iOS 17.0 / macOS 14.0
56dc1a3 chore: 死碼清理 + .gitignore + UI修正
49abcc9 fix(i18n): navigationTitle("") 改 verbatim 根治空字串 key
84b7b47 i18n: 匯入 V7.2 校訂
682087c i18n: 匯入 V6.8 校訂 + 中文用詞統一
5c0a8dd a11y/feat: WCAG 修正 + 廣告版位 + 裝備Optional
```

**交接時間**：2026-06-02　**狀態**：可編譯可執行；死碼清理、部署目標統一、資料夾整理完畢。  
**下一步**：等 PM 拿到 AdMob App ID 後接入 SDK。
