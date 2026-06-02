# HANDOFF: Week 11 → Week 12

**Commit:** `5ed231d`
**Branch:** `main`
**Date:** 2026-05-20
**Status:** ✅ Build Succeeded — ready for Week 12

---

## Week 11 完成項目

### 新增檔案

| 檔案 | 說明 |
|------|------|
| `Services/PurchaseManager.swift` | StoreKit 2 `@Observable` IAP，`com.jd2logbook.premium`，$1.99 買斷 |
| `Views/Logbook/DiveLogEditSheet.swift` | 新增 & 編輯潛水共用 Sheet，SwiftUI Form，支援 Air / Nitrox |
| `Views/Settings/SettingsView.swift` | 設定頁：語言引導 iOS 設定、Premium 入口、關於 / 授權頁 |
| `Views/Shared/AdBannerView.swift` | AdMob 條件編譯 wrapper + `PremiumAwareAdBanner` |

### 修改檔案

| 檔案 | 變更 |
|------|------|
| `Views/MainTabView.swift` | `selectedTab` 狀態 + 匯入後自動切換至 Logbook Tab |
| `Views/Import/ImportWizardView.swift` | `onImportSuccess` callback + 底部 Banner 廣告 |
| `Views/Logbook/LogbookContainerView.swift` | 右上角「+」新增潛水按鈕（決策 #7） |
| `Views/Logbook/DiveLogListView.swift` | `highlightedDiveID` 參數 + highlight 閃爍動畫 |
| `Views/Logbook/DiveLogDetailView.swift` | 右上角「Edit」按鈕，呼叫 `DiveLogEditSheet` |
| `Views/Map/MapView.swift` | 空狀態加入 `PremiumAwareAdBanner`（決策 #5） |
| `Views/Map/DiveMapRepresentable.swift` | 移除未使用的 `existingIDs`（消除警告） |
| `Localizable.xcstrings` | 補完 48 個 zh-Hant 翻譯（Week 11 新增 UI 文字） |

---

## 稽核修正紀錄（Week 11 外部稽核）

本週經外部深度稽核，以下 5 項問題已全部修正並納入同一 commit：

| # | 問題 | 修正方式 |
|---|------|---------|
| 1 | StoreKit 2 漏單：`listenForTransactions()` 只對已知 productID 呼叫 `finish()` | 改為對所有交易無條件呼叫 `finish()`，unverified 交易也處理 |
| 2 | `isKeyWindow` 廢棄（iOS 15+）| 改用 `UIWindowScene.keyWindow` + `activationState == .foregroundActive` |
| 3 | 冷啟動 `isPremium` 閃爍 | `UserDefaults` 快取初始值，`setIsPremium()` 同步寫入 |
| 4 | 廣告 no-fill 空洞 | 實作 `GADBannerViewDelegate`：失敗時高度歸零 + `isHidden = true` |
| 5 | Swift 6 `Coordinator` 跨 actor 存取 `UIApplication.shared` | `Coordinator` 標註 `@MainActor` |

額外修正：`ObservableObject` + `import Combine` → `@Observable` macro（iOS 17+ 現代做法，消除 Swift 6 actor 隔離衝突）

---

## PurchaseManager 架構說明

```
PurchaseManager（@Observable singleton）
│
├── isPremium: Bool          ← UserDefaults 快取初始值，防冷啟動閃爍
├── isLoading: Bool
├── premiumProduct: Product?
│
├── init()                   ← 立即啟動 Transaction Listener Task
├── loadProducts()           ← 從 App Store 載入商品資訊
├── purchase()               ← 觸發購買流程
├── refreshPurchaseStatus()  ← 檢查 currentEntitlements（App 啟動時呼叫）
└── listenForTransactions()  ← 監聽 Transaction.updates，對所有交易 finish()
```

View 側使用方式：
```swift
@State private var pm = PurchaseManager.shared
// 直接讀取 pm.isPremium / pm.isLoading / pm.premiumPriceString
```

---

## AdMob 啟用步驟（上線前必做）

1. Xcode → File → Add Package Dependencies →
   `https://github.com/googleads/swift-package-manager-google-mobile-ads`
2. `Info.plist` 加入 `GADApplicationIdentifier`（AdMob console App ID）
3. `AdBannerView.swift` 中 `AdUnitID` 常數換成正式 Ad Unit ID：
   - `importBanner`：Import 頁 banner
   - `mapEmptyState`：地圖空狀態 inline ad
4. 條件編譯 `#if canImport(GoogleMobileAds)` 會自動啟用真實 SDK

---

## 確認的 UI/UX 決策（Week 11 新增）

| # | 項目 | 決策 |
|---|------|------|
| 已確認 | Premium 定價 | $1.99 買斷，Product ID: `com.jd2logbook.premium` |
| 已確認 | 廣告位置 | Import 頁底部 banner + 地圖空狀態 inline；絕對避開日誌列表 |
| 已確認 | 語言切換 | 引導至 iOS App-Specific Language Settings（非 App 內切換） |
| 已確認 | 匯入後行為 | 自動切換至 Logbook Tab + highlight 最新項目 1.5 秒 |
| 已確認 | 手動新增入口 | Logbook 右上角「+」按鈕 → `DiveLogEditSheet(mode: .new)` |

---

## Week 12 待辦事項

### 必做（上線前）

1. **Export 功能實作**（Premium gate）
   - 格式：UDDF 或 CSV（Week 12 決定）
   - `DiveLogDetailView` 或 `SettingsView` 的 Export 按鈕需接回 `PurchaseManager.isPremium`

2. **整合測試 + 端到端流程驗證**
   - 完整流程：匯入 → 日誌列表 → 詳情 → 編輯 → 地圖
   - 手動新增潛水完整流程

3. **性能測試**
   - 地圖 100+ 潛點滑動流暢度
   - 記憶體用量檢查

4. **Beta 測試（TestFlight）**
   - 招募 50–100 位測試者
   - 重點：IAP 流程、多語系顯示、廣告呈現

5. **WCAG 2.1 AA 合規審核**
   - 色彩對比 ≥ 4.5:1
   - VoiceOver 全流程可用
   - 觸控目標 ≥ 44×44pt

6. **App Store 提審準備**
   - 截圖（每種語言）
   - 隱私政策 URL
   - App 功能描述（繁中 / 簡中 / 英文）

### 建議同步處理

7. **IAP 沙盒測試**
   - 在 Xcode Simulator 或實機以 Sandbox Tester 帳號完整走一遍購買 → 回復流程
   - 驗證 `UserDefaults` 快取行為是否正確

8. **AdMob 正式 SDK 接入**
   - 加入 SPM + 填入正式 Ad Unit ID（見上方步驟）
   - 測試 no-fill 時廣告位收合行為

9. **String Catalog 最終確認**
   - 確認 18 種語言中，標記 `needs_translation` 的字串是否已補完或可接受機器翻譯

---

## 注意事項

- `SettingsPlaceholderView.swift` 仍存在（未刪除），可安全刪除，`MainTabView` 已改用 `SettingsView`
- `HANDOFF_WEEK9_TO_WEEK10.md` 有本地修改未 stage，內容為舊 handoff，不影響開發
- AdMob SDK 未安裝時，`#else` stub 在 Debug 顯示佔位框、Release 顯示 `EmptyView()`，不影響 build
- IAP 在模擬器需開啟 StoreKit Configuration 檔（`File > New > StoreKit Configuration File`）才能測試

---

## 開發規則（繼續遵守）

1. **沒有 PM 同意前，不得開始 coding**
2. **Coding 完先停下來，等 build 確認沒問題再 git commit**
