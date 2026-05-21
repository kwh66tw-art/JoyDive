# HANDOFF: Week 12 → Week 13（App Store 送審）

**最後 Commit:** Week 12 final（i18n + macOS crash fix）
**Branch:** `main`
**日期:** 2026-05-21
**狀態:** ✅ Build Succeeded — iOS + macOS 雙平台全過

---

## Week 12 完成項目

### 18 語系翻譯全面匯入 ✅（最終批次）

**來源：** `JD2-Logbook_i18n_review_V3.csv`（130 Keys × 18 語言，專家稽核清洗版）

**語系：** en, zh-Hans, zh-Hant, ja, ko, fr, es, it, pt-PT, nl, de, en-GB, el, th, vi, ms, id, hr

**物理單位符號化：**
- `degrees Celsius` → `°C`
- `metres`/`meter` → `m`（含 `m` key 本身，zh-Hans/zh-Hant `公尺`/`米` → `m`）
- `minutes`/`minuten` 等 → `min`
- `percent`/`pour cent` 等 → `%%`（format string literal）
- `O2` → `O₂`（下標，en/en-GB）

**複數結構（`%d dives`、`Export all %d dives`）：**
- 歐洲語系（fr, es, it, de, nl, pt-PT, el）：`one` + `other`
- 克羅埃西亞語（hr）：`one` + `few` + `other`
- 英語（en, en-GB）：`one` + `other`
- 亞洲語系（zh-Hans, zh-Hant, ja, ko, th, vi, ms, id）：`other` only

**Settings 頁英文 bug 修復：**
- `One-time purchase. No subscription.\nUnlock Premium...`（真換行 key）補齊 18 語系翻譯
- 刪除孤兒 `\\n` escaped 舊 key

**xcstrings 最終狀態：** 133 keys，18 語系翻譯完整

### macOS 文件選擇器 Crash 修復 ✅

**根因：** `ENABLE_APP_SANDBOX = YES` 但無 `.entitlements` 檔案，document picker 觸發 EXC_BREAKPOINT（"Selected File Read app sandbox entitlement"）

**修復：**
- 新增 `JD2-Logbook/JD2-Logbook/JD2-Logbook.entitlements`（App Sandbox + Access User Selected Files Read/Write）
- `project.pbxproj` Debug + Release 兩個 build config 加入 `CODE_SIGN_ENTITLEMENTS = "JD2-Logbook/JD2-Logbook.entitlements"`

**驗證：** My Mac build → Import → document picker 正常，無 crash ✅

---

### 新增檔案

| 檔案 | 說明 |
|------|------|
| `Services/DiveExporter.swift` | UDDF 3.2.2 + CSV (RFC 4180) Export 邏輯；`ExportFormat` enum；temp file pre-sweep |
| `Views/Shared/ActivityView.swift` | `UIActivityViewController` wrapper（iOS）+ `ShareLink`（macOS）；iPad popover crash fix |
| `Views/Shared/Color+Platform.swift` | 跨平台語意色彩擴充：`platformSecondaryGroupedBackground`、`platformGroupedBackground`、`platformTertiaryFill` |

### 修改檔案（功能）

| 檔案 | 變更 |
|------|------|
| `Views/Logbook/DiveLogDetailView.swift` | Toolbar Export 按鈕（Premium gate：鎖頭半透明）+ confirmationDialog 選 UDDF/CSV |
| `Views/Settings/SettingsView.swift` | Premium 區塊：已購買顯示「Export All Dives (N dives)」；未購買顯示 disabled 列 + 鎖頭說明 |

### 修改檔案（macOS 跨平台修復）

本週外部 AI 修改程式碼後導致 macOS build 失敗，已全面稽核並修復：

| 檔案 | 修復內容 |
|------|---------|
| `Views/Map/DiveMapRepresentable.swift` | 完整重寫：共用 `DiveMapCoordinator: NSObject, MKMapViewDelegate`；`#if os(iOS)` `UIViewRepresentable` / `#else` `NSViewRepresentable`；共用邏輯抽取至 `private extension` |
| `Views/Map/DiveSiteAnnotation.swift` | `DiveSiteAnnotationView`：iOS `UIImage(systemName:)` / macOS `NSImage(systemSymbolName:accessibilityDescription:)`；`DiveClusterAnnotationView`：iOS `UILabel` / macOS `NSTextField`；iOS `layer` 直接存取 / macOS `wantsLayer = true; layer?.xxx`；iOS `accessibilityLabel = "..."` / macOS `setAccessibilityLabel("...")` |
| `Views/Map/DiveSiteSheetView.swift` | `Color(.secondarySystemGroupedBackground)` → `Color.platformSecondaryGroupedBackground` |
| `Views/Map/MapPlaceholderView.swift` | `.navigationBarTitleDisplayMode(.large)` 加 `#if os(iOS)` guard |
| `Views/Map/MapView.swift` | `.navigationBarTitleDisplayMode(.inline)` 加 `#if os(iOS)` guard |
| `Views/Logbook/DiveLogDetailView.swift` | `.listStyle(.insetGrouped)` → `#if os(iOS)` / `#else .listStyle(.inset)`；`.topBarTrailing` → `.automatic` / `.primaryAction` |
| `Views/Logbook/DiveLogListView.swift` | `.searchable(placement: .navigationBarDrawer(displayMode: .always))` → `#if os(iOS)` / `#else .searchable(placement: .toolbar)` |
| `Views/Logbook/DiveLogEditSheet.swift` | `.navigationBarTitleDisplayMode(.inline)` 加 guard；兩處 `.keyboardType(.decimalPad)` 加 `#if os(iOS)` guard |
| `Views/Logbook/DiveRowView.swift` | `Color(.secondarySystemGroupedBackground)` → `Color.platformSecondaryGroupedBackground` |
| `Views/Logbook/LogbookContainerView.swift` | `.navigationBarTitleDisplayMode(.large)` 加 guard；`.topBarTrailing` → `.automatic` / `.primaryAction` |
| `Views/Settings/SettingsView.swift` | 三處 `.navigationBarTitleDisplayMode()` 加 guard；`openAppLanguageSettings()` iOS 用 `UIApplication.shared.open` / macOS 用 `NSWorkspace.shared.open` + `x-apple.systempreferences:` URL |
| `Views/Settings/SettingsPlaceholderView.swift` | `.navigationBarTitleDisplayMode(.large)` 加 guard |
| `Views/Import/ImportWizardView.swift` | `.navigationBarTitleDisplayMode(.large)` 加 guard；三個 `Color(. systemXxx)` → `Color.platformXxx` |
| `Views/Shared/AdBannerView.swift` | `Color(.tertiarySystemFill)` → `Color.platformTertiaryFill` |

---

## 架構說明

### Export 流程
```
DiveLogDetailView / SettingsView
  └── purchaseManager.isPremium?
       ├── false → PremiumUpgradeSheet
       └── true  → confirmationDialog → DiveExporter.exportToTempFile([dive], as: .uddf/.csv)
                   → ActivityView(url:)（iOS: UIActivityViewController / macOS: ShareLink）
```

### Color 跨平台規則
所有 View 統一用 `Color.platformXxx`（定義在 `Color+Platform.swift`），不直接呼叫 `Color(.uiColorName)`：
- `platformSecondaryGroupedBackground` ← `secondarySystemGroupedBackground` / `NSColor.controlBackgroundColor`
- `platformGroupedBackground` ← `systemGroupedBackground` / `NSColor.windowBackgroundColor`
- `platformTertiaryFill` ← `tertiarySystemFill` / `NSColor.quaternaryLabelColor.opacity(0.25)`

### PBXFileSystemSynchronizedRootGroup
本專案 `project.pbxproj` 使用 `PBXFileSystemSynchronizedRootGroup`，目錄下所有 Swift 檔案自動被 include，不需手動加入 pbxproj。新增 `Color+Platform.swift` 到磁碟即可，無需額外設定。

---

## 已完成的 Week 12 原始待辦事項

| 項目 | 狀態 |
|------|------|
| Export 功能（UDDF + CSV，Premium gate） | ✅ 完成 |
| 整合測試 + 端到端流程驗證 | ⚠️ 需人工執行（Simulator / 實機） |
| 性能測試（100+ 潛點） | ⚠️ 需人工執行 |
| Beta 測試（TestFlight） | ⚠️ 需人工操作 |
| WCAG 2.1 AA 合規審核 | ⚠️ 需人工審核（VoiceOver） |
| App Store 提審準備 | ⚠️ 需人工準備（截圖、文案） |
| IAP 沙盒測試 | ⚠️ 需人工測試（Sandbox Tester 帳號） |
| AdMob 正式 SDK 接入 | ⚠️ 需人工操作（SPM + Ad Unit ID） |
| String Catalog 最終確認 | ⚠️ 需人工審核 |

---

## Week 13 — 雙軌任務

### 軌道 A：macOS UI 重構（PM 核可優先）

目前 macOS 版為 Native SwiftUI macOS（`SUPPORTS_MACCATALYST = NO`），但 UI 直接複用 iOS 佈局，不符 Mac HIG。

**P0 — 主導航重構**
- 現況：`TabView` 在 macOS 顯示為底部 Tab Bar（iOS 反模式）
- 目標：`NavigationSplitView`，sidebar 列出 Logbook / Map / Import / Settings
- 檔案：`MainTabView.swift`（iOS 繼續 `TabView`，`#if os(iOS)` 區隔）

**P1 — Import 改用 NSOpenPanel**
- 現況：`ImportWizardView.swift` 使用 `UIDocumentPickerViewController`
- 目標：macOS branch 改 `NSOpenPanel`（entitlements 已有 read-write）

**P2 — Settings 改 macOS Form 風格**
- 現況：iOS List/NavigationLink 風格
- 目標：`Form` + `GroupBox` + `.formStyle(.grouped)`

**P3 — 地圖 pinch-to-zoom 驗證**
- Simulator 雙指縮放無效（可能只是 Simulator 限制），需 real Mac 確認

**P4 — 整體捲動問題排查**
- Simulator 某些畫面無法捲動，確認各 View 的 `ScrollView` macOS 相容性

### 軌道 B：App Store 送審 checklist

### 必做（人工操作）

**1. IAP 沙盒測試**
- Xcode → Product → Scheme → Edit Scheme → StoreKit Configuration 選 `.storekit` 檔
- 以 Sandbox Tester 帳號在實機完整走：購買 → 恢復購買 → `isPremium` 正確切換
- 驗證 `UserDefaults` 快取在冷啟動時不閃爍

**2. AdMob 正式接入**
- File → Add Package Dependencies → `https://github.com/googleads/swift-package-manager-google-mobile-ads`
- `Info.plist` 加 `GADApplicationIdentifier`（從 AdMob console 取得）
- `AdBannerView.swift` 中 `AdUnitID` 常數換成正式 ID（`importBanner`、`mapEmptyState`）
- 條件編譯 `#if canImport(GoogleMobileAds)` 會自動啟用真實 SDK

**3. App Store Connect 準備**
- 截圖：iPhone 6.9"、6.5"、iPad 13"（英文 + 繁中）
- App 描述：繁中（主要）、簡中、英文
- 隱私政策 URL（必填）
- 支援 URL
- 年齡分級問卷

**4. TestFlight Internal Testing**
- Build Upload → Xcode → Product → Archive → Distribute App
- App Store Connect → TestFlight → 加入 Internal Testers
- 至少測試：匯入流程、IAP、Export、地圖

**5. WCAG 2.1 AA 審核**
- 所有 `accessibilityLabel` 已設定（本週已加入 Map annotations、Key Stats、Edit/Export 按鈕）
- VoiceOver 走完主要流程
- 色彩對比以 Xcode Accessibility Inspector 確認

**6. String Catalog 最終確認**
- `Localizable.xcstrings` 中標記 `needs_translation` 的字串確認是否可接受
- 至少確保 zh-Hant、zh-Hans、en 三語完整

### 技術 Debt（建議但非必要）

- 刪除 `Views/Settings/SettingsPlaceholderView.swift`（`MainTabView` 已不使用）
- 確認 `HANDOFF_WEEK9_TO_WEEK10.md` 最終狀態（有未 stage 的修改，內容為舊 handoff）
- 考慮把 `DiveExporter.swift` 的 UDDF 版本號從 `3.2.2` 升至 `3.2.4`（最新規範）

---

## 注意事項

- `SettingsPlaceholderView.swift` 仍存在，可安全刪除
- `Color+Platform.swift` 用 `PBXFileSystemSynchronizedRootGroup` 自動 include，無需手動加入 pbxproj
- `JD2-Logbook_backup_xcodeproj/` 為舊備份資料夾，可刪除（不影響 build）
- `W9_AUDIT_REPORT.md`、`week12-partial_test.md` 為文件，可視需求 stage 或忽略

---

## 開發規則（繼續遵守）

1. **沒有 PM 同意前，不得開始 coding**
2. **Coding 完先停下來，等 build 確認沒問題再 git commit**
