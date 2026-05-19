# Handoff: Week 9 → Week 10

**日期**：2026-05-19
**狀態**：✅ Week 9 全部完成
**Git commit**：`716c69f` feat(Week9): UI phase — TabBar navigation, Logbook/Calendar/Detail/Import views

---

## Week 9 完成項目

### 目標
UI Phase 啟動：建立 Bottom TabBar 導航架構、潛水日誌列表、日曆視圖、詳情頁、匯入嚮導，並實作 String Catalog 多語系（en / zh-Hant / zh-Hans）。

### 完成清單

| # | 任務 | 狀態 |
|---|------|------|
| 1 | String Catalog (`Localizable.xcstrings`) — 37 個 key，含 zh-Hant / zh-Hans | ✅ |
| 2 | `JD2_LogbookApp.swift` — 入口改為 `MainTabView` | ✅ |
| 3 | `MainTabView.swift` — 4-tab Bottom TabBar | ✅ |
| 4 | `LogbookContainerView.swift` — List ↔ Calendar 切換 + NavigationStack | ✅ |
| 5 | `DiveLogListView.swift` — SwiftData Query + StatsHeader + Search + 空狀態 | ✅ |
| 6 | `DiveRowView.swift` — 卡片列（日期 / 深度 / 時間 / 氣體）+ Accessibility | ✅ |
| 7 | `DiveCalendarView.swift` — 月曆格子 + 小圓點標記 + 選日顯示潛水 | ✅ |
| 8 | `DiveLogDetailView.swift` — 詳情頁（唯讀）Hero + KeyStats + Sections | ✅ |
| 9 | `ImportWizardView.swift` — 3 步驟匯入嚮導（Select / Import / Result） | ✅ |
| 10 | `MapPlaceholderView.swift` — 地圖 Tab 佔位視圖 | ✅ |
| 11 | `SettingsPlaceholderView.swift` — 設定 Tab 佔位視圖 | ✅ |
| 12 | Xcode 驗證（build + 模擬器截圖）| ✅ Build Succeeded，0 errors，0 warnings |

---

## 新增 / 修改檔案清單

```
JD2-Logbook/
├── JD2_LogbookApp.swift                          ← MODIFIED（入口換成 MainTabView）
├── Localizable.xcstrings                         ← NEW
└── Views/
    ├── MainTabView.swift                          ← NEW
    ├── Logbook/
    │   ├── LogbookContainerView.swift             ← NEW
    │   ├── DiveLogListView.swift                  ← NEW
    │   ├── DiveRowView.swift                      ← NEW
    │   ├── DiveCalendarView.swift                 ← NEW
    │   └── DiveLogDetailView.swift                ← NEW
    ├── Import/
    │   └── ImportWizardView.swift                 ← NEW
    ├── Map/
    │   └── MapPlaceholderView.swift               ← NEW
    └── Settings/
        └── SettingsPlaceholderView.swift          ← NEW
```

---

## Xcode 整合步驟（PM 執行）

> 所有檔案已存在磁碟，但需要手動加入 Xcode project。

### 步驟一：加入新 Swift 檔案

1. 在 Xcode Project Navigator，右鍵點擊 `Views` 群組 → **Add Files to "JD2-Logbook"…**
2. 選取以下群組（注意：連同子資料夾整個加入）：
   - `Views/MainTabView.swift`
   - `Views/Logbook/`（5 個檔案）
   - `Views/Import/`（1 個檔案）
   - `Views/Map/`（1 個檔案）
   - `Views/Settings/`（1 個檔案）
3. 確認 **Target** 勾選 `JD2-Logbook`，點擊 Add。

### 步驟二：加入 String Catalog

1. 將 `Localizable.xcstrings` 拖入 Project Navigator（`JD2-Logbook` 群組根目錄）。
2. Target Membership 確認勾選 `JD2-Logbook`。
3. Xcode 15+ 會自動辨識為 String Catalog，無需額外設定。

### 步驟三：啟用多語系

1. 點擊 Project 節點 → **Info** → **Localizations**
2. 點擊 `+`，加入：
   - `Chinese, Traditional (zh-Hant)`
   - `Chinese, Simplified (zh-Hans)`
3. 對話框出現時，選擇 **Finish**（String Catalog 會自動涵蓋所有語言）。

### 步驟四：驗證

```
Product → Build (⌘B)
```

預期結果：**Build Succeeded**，零 Error。

---

## 遺留問題 / 注意事項

### 1. `ContentView.swift` 已廢棄
- Week 1 預設的 `ContentView.swift` 目前仍在 target，但 App 入口已改為 `MainTabView`。
- 建議：可直接從 Project Navigator 刪除（Delete → Move to Trash），避免混淆。

### 2. `DiveLog.skipped` 計數
- `ImportWizardView` 的 `success(count:skipped:)` 中，`skipped` 固定傳 `0`。
- `ImportCoordinator.importFile(_:)` 回傳 `[DiveLog]`，目前無法取得被 dedup 的數量。
- **建議 Week 11 改善**：讓 `ImportCoordinator` 回傳 `(imported: [DiveLog], skipped: Int)` tuple。

### 3. 詳情頁為唯讀
- `DiveLogDetailView` 目前無編輯功能。
- **Week 11** 計劃實作 Edit Sheet。

### 4. GasMix JSON 格式依賴
- `DiveRowView` 與 `DiveLogDetailView` 都使用 `JSONDecoder().decode(GasMix.self, from: data)` 解碼 `gasMixJSON` 欄位。
- 若 `DiveLog.gasMixJSON` 格式有異動，需同步更新這兩個 View 的 `gasMixText` 計算屬性。

### 5. Calendar 選取日重置
- 切換月份時 `selectedDate` 被重置（`.nil`），屬設計決策，符合預期行為。

---

## Week 10 任務預告

**主題：地圖視圖（MapKit + 潛點聚類）**

| 任務 | 說明 |
|------|------|
| 實作 `MapView.swift` | 取代 `MapPlaceholderView`，嵌入 `MKMapView` / SwiftUI `Map` |
| 潛點聚類（Clustering） | 同座標或近距離潛點合併為 cluster annotation |
| 潛點標記（Annotation） | 單點 annotation：顯示地點名稱 + 最大深度 |
| 點擊 Annotation → 詳情 | `NavigationLink` 或 sheet 顯示該潛點所有潛水紀錄 |
| 權限處理 | `CLLocationManager` requestWhenInUseAuthorization — 若需要顯示使用者位置 |
| 地圖資料來源 | `@Query` 撈取有 `latitude / longitude` 的 `DiveLog`（約 70% 有座標） |

**技術選型建議（待 PM 確認）：**
- SwiftUI `Map` API（iOS 17+） vs `MKMapView` UIViewRepresentable
- 聚類：`MKClusterAnnotation`（UIKit）或自訂 SwiftUI overlay
- 地圖樣式：Standard / Hybrid / Satellite（可在 Settings Week 11 加入選項）

---

## 測試狀態

- **Week 8 遺留**：215 tests ✅ green（build + run 由 PM 於 Week 8 末確認）
- **Week 9 新增 UI**：純 SwiftUI View，無商業邏輯，暫不加 Unit Test
- **建議 Week 10** 加入 `XCTestCase` snapshot tests for `DiveRowView` 與 `DiveCalendarView`（可選）

---

## 架構設計決策摘要

| 決策 | 選擇 | 理由 |
|------|------|------|
| 導航架構 | Bottom TabBar (`TabView`) | iOS 標準，DIVEROUT 風格 |
| 主題 | 跟隨系統（Light + Dark） | Apple HIG 2026 建議 |
| 多語系框架 | String Catalog (.xcstrings) | Xcode 15 原生，支援 AI 翻譯 |
| 日曆標記 | 小圓點（5pt） | 簡潔，DIVEROUT 風格 |
| 詳情頁進入 | Tap row → Push detail | 標準 iOS NavigationStack |
| 日曆視圖位置 | Logbook tab 內切換（非獨立 tab） | 省一個 tab，架構更乾淨 |
