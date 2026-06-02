# HANDOFF: Week 10 → Week 11

**Commit:** `e21c597`
**Branch:** `main`
**Date:** 2026-05-20
**Status:** ✅ Build Succeeded — ready for Week 11

---

## Week 10 完成項目

### 新增檔案

| 檔案 | 說明 |
|------|------|
| `Views/Map/DiveSiteAnnotation.swift` | MKAnnotation 三件套：`DiveSiteAnnotation`、`DiveSiteAnnotationView`、`DiveClusterAnnotationView` |
| `Views/Map/DiveMapRepresentable.swift` | `UIViewRepresentable` 封裝 `MKMapView`，含 annotation diff + zoom-to-fit |
| `Views/Map/DiveSiteSheetView.swift` | Medium Detent Sheet：peek section (3-col stats) + full details |
| `Views/Map/MapView.swift` | 主地圖 View，含圖層切換按鈕、sheet 狀態管理、觸覺回饋 |
| `UI_UX_SPEC.md` | 全 App UI/UX 規格文件 v1.0（10 項決策已確認） |

### 修改檔案

| 檔案 | 變更 |
|------|------|
| `Views/MainTabView.swift` | `MapPlaceholderView()` → `MapView()` |
| `Localizable.xcstrings` | 新增 5 個 i18n key，含 zh-Hant 翻譯 |

---

## 地圖架構重點

### Annotation 系統
- `DiveSiteAnnotation`：持有 `DiveLog`，`@objc dynamic var coordinate`，`clusteringIdentifier = "diveCluster"`
- `DiveSiteAnnotationView`：`MKMarkerAnnotationView`，glyph = `figure.open.water.swim`，`canShowCallout = false`
- `DiveClusterAnnotationView`：44×44 圓形，systemBlue 底，白色 2.5pt 邊框，badge 顯示數量（"N" 或 "99+"）

### Annotation Diff 策略
- 用 `PersistentIdentifier` Set 計算新增／移除，不做 full reload
- 需要 `import SwiftData`（踩坑紀錄：少此 import 會出現 5 個 `Property 'persistentModelID' is not available` 錯誤）

### Sheet 狀態管理
- **`isPresented` (Bool) + 獨立 `selectedDive`** —— 不使用 `item:` 版本
- 目的：換 pin 時 sheet 保持開啟、只更新內容，不 dismiss/re-present
- `onDismiss: { selectedDive = nil }` 負責清除選取狀態

### Zoom-to-fit
- `Coordinator.hasZoomedToFit` flag，只在首次資料載入時觸發
- 單一 pin：span 0.05°；多 pin：`showAnnotations(_:animated:)`
- Cluster 點擊：zoom in 至 member pins（決策 #9：方案 A）

### Haptic
- `.sensoryFeedback(.impact(flexibility: .solid, intensity: 0.7), trigger: selectedDive?.persistentModelID)`
- iOS 17+ API，與 SwiftData 最低部署目標一致

---

## 已確認 UI/UX 決策（10 項）

| # | 項目 | 決策 |
|---|------|------|
| 1 | 地圖 Pin 點擊 | Medium Detent Sheet，`.fraction(0.35)` peek + `.large` 全展開 |
| 2 | 匯入成功後行為 | 方案 B：自動切換至 Logbook Tab + highlight 動畫 + 觸覺回饋 |
| 3 | App 內語言切換 | 引導至 iOS 設定（App-Specific Language Settings） |
| 4 | Premium 定價 | $1.99 買斷：移除廣告 + 解鎖 Export |
| 5 | 廣告位置 | Import 頁 + 地圖空狀態；絕對避開日誌列表 |
| 6 | （規格文件保留） | — |
| 7 | 手動新增潛水入口 | Logbook 右上角「+」按鈕 |
| 8 | 採用目前規劃 | — |
| 9 | Cluster 點擊行為 | 方案 A：Zoom In 解散 |
| 10 | 多語系支援 | 18 種語言（暫定清單，待 PM 最終確認） |

---

## 新增的 i18n Keys（Week 10）

```
"Manual Entry"                                    → 手動建立
"No GPS Dive Sites"                               → 無 GPS 潛點
"Dives with GPS coordinates will appear on this map." → 含 GPS 座標的潛水記錄將顯示在地圖上。
"Switch to Hybrid Map"                            → 切換至衛星混合地圖
"Switch to Standard Map"                          → 切換至標準地圖
```

---

## Week 11 待辦事項

### 必做（核心功能補齊）

1. **`SettingsView`**（取代 `SettingsPlaceholderView`）
   - App 語言：引導至 iOS 設定
   - 關於頁面：版本號、授權資訊
   - Premium 入口（StoreKit 2 IAP）

2. **手動新增潛水（決策 #7）**
   - Logbook 右上角「+」按鈕
   - `NewDiveEntryView`（Sheet 或 NavigationLink）
   - `DiveLogEditSheet`（共用於新增 & 編輯）

3. **匯入後自動切換（決策 #2）**
   - Import 成功 → 切換 Logbook Tab + highlight 最新項目
   - `TabView` selectedTab Binding 需拉到 `MainTabView` 層

4. **AdMob 整合（決策 #5）**
   - Import 頁 banner
   - 地圖空狀態 inline ad
   - 需加入 `GoogleMobileAds` SPM

5. **StoreKit 2 IAP（決策 #4）**
   - Product ID：`com.jd2logbook.premium`（$1.99 買斷）
   - `PurchaseManager` actor
   - Premium 解鎖：隱藏廣告 + 啟用 Export 按鈕

### 建議同步處理

6. **`DiveLogDetailView` 編輯功能**（目前只有 read-only）
7. **Export 功能骨架**（Premium gate，具體格式 Week 12 實作）
8. **String Catalog 補完**：補齊所有 18 種語言的翻譯（或先用空值佔位，標記 `needs_translation`）

---

## 注意事項

- `HANDOFF_WEEK9_TO_WEEK10.md` 有本地修改（未 stage），內容為舊 handoff 文件，Week 11 開始前不需動它
- `MapPlaceholderView` 已可安全刪除（已被 `MapView` 取代），但刪除前確認無其他 reference
- `UI_UX_SPEC.md` 的 18 語言清單需 PM 最終確認後更新 String Catalog

---

## 開發規則（繼續遵守）

1. **沒有 PM 同意前，不得開始 coding**
2. **Coding 完先停下來，等 build 確認沒問題再 git commit**
