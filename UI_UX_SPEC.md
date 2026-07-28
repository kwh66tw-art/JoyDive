# JD2-Logbook UI/UX 完整規劃書

**版本**：v1.0（Week 10 決策確認版，2026-07-28 標註現況更新）
**原始撰寫**：2026-05-20（Week 10 規劃階段）
**2026-07-28 更新說明**：本文件原為 Week 10–12 開發前的規劃文件，內文大量
「⏳ 待實作」標記皆為當時的未來式。截至本次更新，v1.0/v1.1/v1.2 皆已開發
完成並送審，§3–7 描述的畫面/互動流程（Map Pin Sheet、Import Wizard、
Settings、Edit/New Dive Sheet 等）**均已實作，且與現行程式碼架構一致**，
僅保留原文不逐句改時態；但下列幾處內容與現況有實質落差，已個別修正/標註：
①「功能狀態總覽」表全數更新為完成狀態；②§8.1 的 18 語言清單原本列的語言
（含 pt-BR/sv/nb/da/fi/ru/pl）與實際上線語言不符，已更正；③§9「iOS 18 新
功能」（Control Center／Lock Screen Widget）**已於 v1.1 backlog 確認不需要
並終止規劃**，未實作；④§11「Week 10–12 設計工作清單」已全部完成，整節
標註為歷史record。§8.2 Accessibility 現況以 `WCAG_2.1_AA_AUDIT_CHECKLIST.md`
為準。

---

## 目錄

1. [App 概覽](#1-app-概覽)
2. [設計哲學與系統](#2-設計哲學與系統)
3. [導覽架構](#3-導覽架構)
4. [Tab 1 — Logbook（日誌）](#4-tab-1--logbook日誌)
5. [Tab 2 — Map（地圖）](#5-tab-2--map地圖)
6. [Tab 3 — Import（匯入）](#6-tab-3--import匯入)
7. [Tab 4 — Settings（設定）](#7-tab-4--settings設定)
8. [跨切面設計](#8-跨切面設計)
9. [iOS 18 新功能](#9-ios-18-新功能)
10. [確認決策紀錄](#10-確認決策紀錄)
11. [Week 10–12 設計工作清單](#11-week-1012-設計工作清單)

---

## 1. App 概覽

**App 名稱**：JD2-Logbook  
**定位**：潛水日誌管理 App，支援從多種潛水電腦匯入潛水記錄，提供 GPS 地圖、統計分析、多語系。  
**目標用戶**：有潛水電腦的休閒潛水員（OWD 至 DM 等級），以繁體中文用戶為主。  
**上線版本**：v1.0（2026-08-18）  
**競品參考**：Oceanic+（地圖 UX 標竿）、Below（廣告 & IAP 策略標竿）、Garmin（i18n 規範參考）

### 功能狀態總覽（2026-07-28 現況）

| 功能 | 狀態 | 備註 |
|------|------|------|
| 多格式解析器（15 種，經 F6 遷移至 DiveImportKit） | ✅ 完成 | 家族層 DiveImportKit 297 tests；本 repo 僅留 Adapter |
| 日誌列表 + 搜尋 | ✅ 完成 | |
| 月曆視圖 | ✅ 完成 | |
| 潛水詳情頁 | ✅ 完成（含編輯） | |
| 匯入嚮導（3 步驟） | ✅ 完成（含 tab 自動切換） | |
| GPS 地圖 + Medium Detent Sheet | ✅ 完成 | |
| String Catalog 18 語系 | ✅ 完成 | 實際語言清單見 §8.1（與原規劃清單不同，已更正） |
| 廣告（AdMob Banner） | ✅ 完成 | Logbook / Import / Settings / Map 空狀態 |
| Premium IAP（$1.99 買斷） | ✅ 完成 | 解鎖：移除廣告（iOS only，macOS 無廣告） |
| 設定頁 | ✅ 完成 | |
| 詳情頁編輯 + 手動新增 | ✅ 完成 | |
| iOS 18 擴充（Control Center / Lock Screen Widget） | ❌ 終止規劃 | v1.1 backlog #9/#10，PM 確認不需要，不會排入後續版本 |
| WCAG 2.1 AA 審查 | ✅ 完成 | 見 `WCAG_2.1_AA_AUDIT_CHECKLIST.md` |
| App Store 送審 | ⏳ 進行中 | v1.2 (Build 3) iOS+macOS 皆 Waiting for Review，見 `V1_2_BACKLOG.md` #1 |

---

## 2. 設計哲學與系統

### 2.1 設計原則

- **Apple HIG 優先**：NavigationStack、TabView、.insetGrouped List、系統色彩、SF Symbols
- **跟隨系統主題**：Dark Mode 完全自動適配；語言切換為 App 內建切換器（v1.1 起，見 §7.2）
- **Accessibility First**：WCAG 2.1 AA，所有互動元素 ≥ 44×44 pt，VoiceOver 完整支援
- **觸覺反饋一致性**：所有重要互動搭配 `.sensoryFeedback`（SwiftUI API，iOS 17+）

### 2.2 色彩系統

| 用途 | 規格 | 備註 |
|------|------|------|
| Primary Accent | `.accentColor`（系統藍 `#007AFF`） | 按鈕、連結、選中狀態 |
| Background | `.systemBackground` / `.systemGroupedBackground` | 自動 Dark Mode |
| Card Background | `.secondarySystemGroupedBackground` | DiveRowView 卡片 |
| 日期分隔線 | `Color.accentColor.opacity(0.35)` | DiveRowView 左側 |
| Success | `.green`（系統） | 匯入成功圖示 |
| Error | `.red`（系統） | 匯入失敗圖示 |
| Depth | `.tint` | 深度數值高亮 |
| Water Temp | `.cyan` | 詳情頁水溫 |
| Duration | `.orange` | 詳情頁時間 |
| Map Pin | `UIColor.systemBlue` | MKMarkerAnnotationView |
| Cluster Badge | `UIColor.systemBlue` + white border | 44×44 pt 圓形 |
| **Import 成功高亮** | `Color.accentColor.opacity(0.15 → 0)` | 1 秒淡出動畫（Week 11）|

> ⚠️ **尚無品牌色**：全部使用 iOS 系統色彩。若後續建立品牌色，需建立 Asset Catalog Color Sets 搭配 Dark Mode 變體。

### 2.3 字型系統

| 語意層級 | SwiftUI 規格 | 典型使用 |
|---------|------------|---------|
| 大標題 | `.largeTitle` | NavigationTitle（large）|
| 標題 | `.title2.bold()` | 詳情頁地點名稱、統計數值 |
| Sheet 地點名 | `.title3.bold()` | DiveSiteSheetView peek section |
| 導覽標題 | `.headline` | NavigationTitle（inline）|
| 內文 | `.body` | 預設 |
| 次要資訊 | `.subheadline` | 列表副標、欄位值 |
| 數值 | `.callout.bold()` | 卡片深度/時間數值 |
| 補充 | `.caption` / `.caption2` | 日期標籤、圓點統計 |

### 2.4 間距與圓角

| 元件 | 圓角 | Padding |
|------|------|---------|
| 日誌卡片 | `14 pt` | 12 pt 內距，列表 6/16 pt |
| 格式卡片 | `8 pt` | 10/8 pt |
| 月曆選中圓圈 | Circle 34×34 | — |
| Cluster Badge | Circle 44×44 | — |
| Map 切換按鈕 | RoundedRectangle 8 pt，40×40 | 右 12、頂 8 |
| DiveSiteSheetView 內距 | — | horizontal 20 pt |

### 2.5 觸覺反饋規範

| 場景 | SwiftUI API | 感受 |
|------|------------|------|
| 地圖 Pin 點擊 | `.sensoryFeedback(.impact(flexibility: .solid, intensity: 0.7), trigger: selectedDive?.persistentModelID)` | 實體撞擊感 |
| 匯入成功 Done 按鈕 | `UINotificationFeedbackGenerator().notificationOccurred(.success)` | 成功三連震 |
| 一般按鈕點擊 | 系統預設（無需額外實作）| — |

> 注意：`.sensoryFeedback` 要求 iOS 17+（本 App minimum deployment target 需確認，建議 iOS 17）

---

## 3. 導覽架構

### 3.1 整體結構圖

```
JD2_LogbookApp
└── WindowGroup
    └── MainTabView（TabView — Bottom Tab Bar）
        │   @State selectedTab: Int（用於 Import→Logbook 自動切換）
        │
        ├── Tab 0: LogbookContainerView
        │   └── NavigationStack（path: NavigationPath）
        │       ├── DiveLogListView（預設）
        │       │   ├── @ScrollViewReader（import 成功後 scrollTo 最頂端）
        │       │   └── → DiveLog → DiveLogDetailView（push）
        │       └── DiveCalendarView（切換）
        │           └── → DiveLog → DiveLogDetailView（push）
        │
        ├── Tab 1: MapView（Week 10）
        │   └── NavigationStack
        │       ├── DiveMapRepresentable（MKMapView UIViewRepresentable）
        │       │   └── Pin Tap → @State selectedDive + haptic
        │       ├── [懸浮] MapTypeToggleButton（右上角）
        │       └── .sheet(isPresented: $isSheetPresented)
        │           └── DiveSiteSheetView（Medium Detent：0.35 / .large）
        │               └── .large 時內容等同 DiveLogDetailView
        │
        ├── Tab 2: ImportWizardView
        │   └── NavigationStack
        │       ├── Step 1: 格式說明 + 選擇檔案
        │       ├── Step 2: 解析中
        │       └── Step 3: 成功（Done → selectedTab=0 + haptic）/ 失敗
        │
        └── Tab 3: SettingsView（Week 11）
            └── NavigationStack
                ├── 語言（App 內建切換器，即時生效，見 §7.2）
                ├── Premium IAP（$1.99：移除廣告 + Export）
                ├── Restore Purchases
                └── About（版本、隱私政策）
```

### 3.2 導覽模式對照

| 情境 | 模式 | 原因 |
|------|------|------|
| 日誌列表 → 詳情 | Push（NavigationLink） | 線性流程，支援滑回 |
| 日曆 → 詳情 | Push（共用 navigationDestination） | 同 Tab 一致 |
| 地圖 Pin → DiveSiteSheetView | Medium Detent Sheet | 地圖保持互動，連續切換 Pin |
| 匯入嚮導 | 狀態機（State enum） | 步驟不可返回 |
| Settings 子頁（Week 11） | Push | 標準設定頁 |

### 3.3 TabBar 標籤

| Tab index | 圖示 | 英文 | 繁中 |
|-----------|------|------|------|
| 0 | `list.bullet.below.rectangle` | Logbook | 日誌 |
| 1 | `map` | Map | 地圖 |
| 2 | `square.and.arrow.down` | Import | 匯入 |
| 3 | `gearshape` | Settings | 設定 |

---

## 4. Tab 1 — Logbook（日誌）

### 4.1 LogbookContainerView（容器）

- **Navigation Title**：「Dive Logbook」（`.large`）
- **右上角工具列**：切換 List ↔ Calendar 按鈕
- **共用 navigationDestination**：`DiveLog.self` → `DiveLogDetailView`
- **Week 11 擴充**：
- 接收來自 ImportWizardView 的「高亮最新匯入」訊號（NotificationCenter 或 EnvironmentObject）
- 右上角工具列新增「+」按鈕（`plus`）→ `.sheet` 呈現 `NewDiveEntryView`

---

### 4.2 DiveLogListView（列表）

#### 空狀態
- `ContentUnavailableView`，圖示 `water.waves`
- 標題：「No dives yet」
- 說明：「Use the Import tab to add your dive computer logs.」

#### 有資料狀態

**StatsHeaderView（頂部統計 Bar）**

```
┌─────────────────────────────────────────┐
│  [12]       [45.2h]       [62.0m]       │
│  Dives     Total Time    Deepest        │
└─────────────────────────────────────────┘
```

背景 `.bar`，三格等寬，Divider 分割，即時更新。

**DiveRowView（卡片）**

```
┌──────────────────────────────────────────┐
│ [20] │ 📍 Small Island, Komodo           │
│ [May]│   ↓ 52.3 m   ⏱ 94 min            │
│[2026]│   🌡 28°C   [EANx32]              │
└──────────────────────────────────────────┘
```

- 左側日期塊 46 pt，accent 色 2 pt 分隔線
- 卡片 `.secondarySystemGroupedBackground`，圓角 14 pt
- 整張卡片合為一個 accessibility element

**Week 11 新增：Import 成功高亮動畫**

```
新匯入的 DiveLog 卡片：
背景短暫閃現 Color.accentColor.opacity(0.15)
→ withAnimation(.easeOut(duration: 1.0)) { opacity → 0 }
觸發時機：NotificationCenter 收到 .didImportDives 通知
```

---

### 4.3 DiveCalendarView（月曆）

- 月份導航 Header（箭頭最小 44×44 pt）
- 星期列（隨系統 locale / firstWeekday 旋轉）
- DayCell：今天圈框、選中填滿、5 pt 潛水圓點
- 選中日潛水列表（ScrollView + NavigationLink push 詳情）
- 切換月份時 `selectedDate` 重置（設計決策）

---

### 4.4 DiveLogDetailView（詳情頁）

**現況**：✅ 已完成，含編輯功能（免費，不鎖 Premium，見下方「Week 11 擴充」）。

**結構（`.insetGrouped` List）**

```
Section 1 — Hero（透明背景）
  📍 Small Island, Komodo
  Wednesday, 20 May 2026, 09:30

Section 2 — Key Stats（3欄橫排）
  ↓ 52.3 m     ⏱ 94 min 05 sec     🌡 28°C
  Max Depth    Duration             Water Temp

Section 3 — Dive Info
  Gas:            Air
  Environment:    Seawater
  Source Format:  Subsurface XML

Section 4 — Location
  Location:     Small Island, Komodo
  Coordinates:  8.54321°, 119.48765°（有才顯示）

Section 5 — Notes（有才顯示正文，無則顯示灰色提示）

Section 6 — Buddy（有才顯示）
```

**Week 11 擴充 — DiveLogEditSheet**

Toolbar 右上 Edit 按鈕 → `.sheet` 呈現：

```
[Cancel]  Edit Dive  [Save]
─────────────────────────
Location      [TextField]
Date & Time   [DatePicker]
Max Depth     [TextField + 'm']
Water Temp    [TextField + '°C']
Gas Mix       [Picker]
Notes         [TextEditor]
Buddy         [TextField]

[Delete This Dive]（red destructive + Alert 確認）
```

> Duration 維持唯讀（解析器決定，不開放修改）

**Week 11 擴充 — NewDiveEntryView（手動新增）**

Logbook 右上角「+」按鈕 → `.sheet` 呈現：

```
[Cancel]  New Dive  [Save]
──────────────────────────
Location      [TextField]       （必填）
Date & Time   [DatePicker]      （預設 = now）
Max Depth     [TextField + 'm'] （必填）
Duration      [分 / 秒 Picker]  （手動新增時可設定）
Water Temp    [TextField + '°C']
Gas Mix       [Picker: Air / Nitrox / Trimix]
Notes         [TextEditor]
Buddy         [TextField]
```

> - Save 後自動插入 SwiftData，`sourceFormat = "manual"`
> - Save 後 sheet dismiss，列表自動跳至該筆（或捲動至頂端）
> - Duration 在 EditSheet 為唯讀，但在 NewDiveEntryView 為**可填**（因為手動建立沒有解析器）

---

## 5. Tab 2 — Map（地圖）

> **狀態**：✅ 已完成

### 5.1 整體佈局

```
┌──────────────────────────────────────┐
│ Map                        [🌐 / 🗺] │  ← NavigationBar（inline）+ 懸浮按鈕
├──────────────────────────────────────┤
│                                      │
│   [地圖主體 — 延伸至底部 safe area]   │
│                                      │
│      📍 Single pin                   │
│      [12] Cluster badge              │
│                                      │
│                                      │
│┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄│
│  ────  （拖曳把手）                   │  ← DiveSiteSheetView 0.35 detent
│  📍 Small Island, Komodo            │
│  Wed 20 May 2026                    │
│  ↓52.3m    ⏱94min    🌡28°C         │
└──────────────────────────────────────┘
```

---

### 5.2 資料來源

```swift
@Query var allDives: [DiveLog]
var mappableDives: [DiveLog] {
    allDives.filter { $0.latitude != nil && $0.longitude != nil }
}
```

---

### 5.3 技術架構（UIViewRepresentable）

**技術選型**：`MKMapView` via `UIViewRepresentable`（非 SwiftUI `Map` API）

| 類別 | 父類別 | 職責 |
|------|--------|------|
| `DiveSiteAnnotation` | `NSObject, MKAnnotation` | 持有一筆 DiveLog；coordinate / title / subtitle |
| `DiveSiteAnnotationView` | `MKMarkerAnnotationView` | 單點 pin；無 callout；`clusteringIdentifier = "diveCluster"` |
| `DiveClusterAnnotationView` | `MKAnnotationView` | 44×44 藍色圓形 badge；count label |
| `DiveMapRepresentable` | `UIViewRepresentable` | 封裝 MKMapView；annotation diff |
| `DiveMapRepresentable.Coordinator` | `NSObject, MKMapViewDelegate` | pin tap / cluster tap / deselect |
| `DiveSiteSheetView` | `View` | Medium Detent Sheet 內容（peek + 全詳情）|
| `MapView` | `View` | SwiftUI 主容器；@Query + ZStack + sheet |

---

### 5.4 ✅ Pin 點擊行為 — Medium Detent Sheet（已確認）

**完整流程**：

```
用戶 Tap Pin
  → MKMapViewDelegate.didSelect 觸發
  → selectedDive = annotation.dive（更新 @State）
  → isSheetPresented = true（若尚未開）
  → .sensoryFeedback(.impact(flexibility:.solid, intensity:0.7)) 觸發
  → 底部 DiveSiteSheetView 彈出，detent = .fraction(0.35)

Sheet 已開，用戶 Tap 另一個 Pin
  → selectedDive = newAnnotation.dive（更新 @State，Sheet 不關閉）
  → .sensoryFeedback 再次觸發（trigger 改變）
  → Sheet 內容無縫切換至新潛水資訊（動畫更新）

用戶向上拉 Sheet 至 .large
  → 完整 DiveLogDetailView 內容可見

用戶向下滑超過 0.35 detent 邊界
  → Sheet 自動 dismiss（iOS 預設行為）
  → isSheetPresented = false，selectedDive = nil
```

**State 管理（MapView 內）**

```swift
@State private var selectedDive: DiveLog?
@State private var isSheetPresented: Bool = false

// Sheet 宣告
.sheet(isPresented: $isSheetPresented, onDismiss: { selectedDive = nil }) {
    if let dive = selectedDive {
        DiveSiteSheetView(dive: dive)
            .presentationDetents([.fraction(0.35), .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
    }
}

// 觸覺反饋
.sensoryFeedback(
    .impact(flexibility: .solid, intensity: 0.7),
    trigger: selectedDive?.persistentModelID
)
```

> `.presentationBackgroundInteraction(.enabled(upThrough: .large))`  
> 關鍵設定：Sheet 存在時地圖仍可完整互動，用戶可連續點擊不同 Pin 切換 Sheet 內容。

---

### 5.5 DiveSiteSheetView 設計規格

**設計目標**：0.35 detent 時即顯示最重要資訊（地點名 + 3 項數據），拉至 large 後呈現完整詳情。

**結構（ScrollView，非 List）**

```
┌───────────────────────────────────┐
│       ──── （拖曳把手，系統提供）  │
│                                   │
│  📍 Small Island, Komodo         │  .title3.bold，最多 2 行
│     Wed, 20 May 2026 · 09:30     │  .subheadline，secondary
│                                   │
│  ┌─────────┬─────────┬─────────┐ │
│  │ ↓ 52.3  │   94    │   28    │ │
│  │    m    │   min   │   °C    │ │
│  │MaxDepth │Duration │WaterTemp│ │
│  └─────────┴─────────┴─────────┘ │  ← KeyStatRow（同 DetailView 設計）
│                                   │
│  ─────────────────────────────── │  ← Divider（此線剛好在 0.35 邊界附近）
│                                   │
│  （下方在 0.35 時折疊，拉起才可見） │
│                                   │
│  Dive Info                        │  Section Header
│  Gas:          Air                │
│  Environment:  Seawater           │
│  Source Format: Subsurface XML    │
│                                   │
│  Location                         │
│  Location:    Small Island...     │
│  Coordinates: 8.54321°, 119...    │
│                                   │
│  Notes                            │
│  No notes recorded.               │
│                                   │
└───────────────────────────────────┘
```

**Peek Section（0.35 detent 可見區域）**

- 水平內距：20 pt
- 頂部間距：16 pt（拖曳把手下方）
- 地點名：`.title3.bold()`，2 行截斷
- 日期時間：`.subheadline`，`.secondary`，locale-aware formatter
- KeyStatRow：與 `DiveLogDetailView` 相同的 3 欄橫排設計（複用 `KeyStatCell`），高約 70 pt

**Full Details Section（large detent 可見）**

- 與 `DiveLogDetailView` Section 3–6 相同資訊（Gas / Location / Notes / Buddy）
- 使用 `LazyVStack` + 自訂 Section Header，不用 `List`（避免 sheet 內 List 的滾動衝突）
- 底部 padding：`safeAreaInsets.bottom + 20`

---

### 5.6 ✅ Cluster 點擊行為（已確認：Zoom In）

```
Tap Cluster Badge
  → mapView.showAnnotations(cluster.memberAnnotations, animated: true)
  → 地圖自動計算邊界並 zoom-in-to-fit
  → mapView.deselectAnnotation（關閉任何 callout）
  → （不開 Sheet）
```

---

### 5.7 Map Type 切換按鈕

- 右上角懸浮（ZStack `.topTrailing`）
- 40×40 pt，`.regularMaterial` 背景，圓角 8 pt，系統陰影
- Standard 時：`globe.americas.fill`
- Hybrid 時：`map`
- 切換：`.standard` ↔ `.hybrid`
- AccessibilityLabel：「Switch to Hybrid Map」/ 「Switch to Standard Map」

---

### 5.8 空狀態（無 GPS 資料）

```swift
ContentUnavailableView {
    Label("No GPS Dive Sites", systemImage: "map.fill")
} description: {
    Text("Dives with GPS coordinates will appear on this map.")
}
```

以 `.overlay` 覆蓋地圖，僅在 `mappableDives.isEmpty` 時顯示。

> **Week 11 廣告擴充**：Premium 未解鎖時，ContentUnavailableView 下方加入 AdMob Banner

---

### 5.9 Annotation 視覺規格

**DiveSiteAnnotationView（單點 Pin）**

| 屬性 | 值 |
|------|-----|
| 父類別 | `MKMarkerAnnotationView` |
| `markerTintColor` | `UIColor.systemBlue` |
| `glyphImage` | `UIImage(systemName: "figure.open.water.swim")` |
| `clusteringIdentifier` | `"diveCluster"` |
| `canShowCallout` | **`false`**（改用 Sheet，不用 callout）|
| `isSelected` 狀態 | 保持 selected（高亮）直到用戶 dismiss sheet |

**DiveClusterAnnotationView（聚類）**

| 屬性 | 值 |
|------|-----|
| Frame | 44 × 44 pt |
| Shape | Circle（`cornerRadius = 22`）|
| 背景 | `UIColor.systemBlue` |
| Border | 2.5 pt white |
| Shadow | opacity 0.25, radius 4, offset (0, 2) |
| Label | count（< 100）/ `"99+"`（≥ 100）|
| Label 字型 | `.systemFont(14, .bold)`，white |
| AccessibilityLabel | `"\(count) dive sites"` |
| `collisionMode` | `.circle` |

---

### 5.10 首次載入行為

- 第一次 `updateUIView` 加入 annotations 時，呼叫 `showAnnotations(_:animated: true)` zoom-to-fit
- Coordinator 內 `hasZoomedToFit` flag 避免重複執行
- 後續資料變化：diff 更新（以 `persistentModelID` 比對），不重置視圖

---

### 5.11 定位權限

本 Week **不**實作使用者位置顯示：
- `mapView.showsUserLocation = false`
- 不需 Info.plist `NSLocationWhenInUseUsageDescription`

---

## 6. Tab 3 — Import（匯入）

### 6.1 整體結構

**Navigation Title**：「Import Dives」（`.large`）

步驟指示器（固定頂部）→ Divider → 內容區（ScrollView）

### 6.2 步驟指示器

```
  ①──────────②──────────③
Select     Import     Result
```

- 圓圈 26×26 pt，已完成：填滿 accent + checkmark；目前：填滿 accent + 數字；待完成：灰色
- 連接線：1 pt 灰色

### 6.3 Step 1 — Select

- 說明圖示（48 pt）+ 副標
- 支援格式卡片（2 欄 Grid）
- **Select File** 按鈕（`borderedProminent`，全寬，50 pt）
- 已選檔名顯示
- **Week 11 廣告位置**：格式卡片區塊下方加入 AdMob Banner（Premium 未解鎖時顯示）

### 6.4 Step 2 — Import

自動進入（選完檔即觸發），中央 ProgressView + 「Importing…」+ 檔名

### 6.5 Step 3 — Success / Failure

**Success**：
```
  ✅（64 pt）
  Import Successful
  12 dives imported
  （X skipped (duplicates)，若 > 0）
  [Done]（borderedProminent）
```

**Failure**：
```
  ❌（64 pt）
  Import Failed
  （錯誤訊息）
  [Try Again]（bordered）
```

### 6.6 ✅ Done 按鈕行為（已確認：自動切換 Logbook + 觸覺）

**完整流程（Week 11 實作）**：

```
用戶點擊 [Done]
  → UINotificationFeedbackGenerator().notificationOccurred(.success)  ← 觸覺
  → selectedTab = 0  ← 切換至 Logbook Tab（透過 @Binding 或 EnvironmentObject）
  → Logbook 列表 ScrollViewReader.scrollTo(firstDive.id, anchor: .top)  ← 捲動至頂端
  → 新匯入的 DiveLog 卡片背景短暫高亮（accentColor.opacity(0.15 → 0)，1 秒淡出）
  → resetToReady()（ImportWizardView 回到 Step 1）
```

**實作方式**：`MainTabView` 中以 `@State private var selectedTab = 0` 控制選中 Tab；`ImportWizardView` 接收 `Binding<Int>` 或使用 `EnvironmentObject`；高亮通知透過 `NotificationCenter.default.post(name: .didImportDives, object: nil)`。

**Week 10 先不實作**（ImportWizardView 不需改動），Week 11 統一處理。

---

## 7. Tab 4 — Settings（設定）

> **狀態**：✅ 已完成（`SettingsView.swift`）

### 7.1 計劃結構

```
Navigation Title: "Settings"（.large）

Section — Language
  Language   →（App 內建切換器 Picker，即時生效，見 §7.2）

Section — Premium（$1.99 買斷）
  ✦ Remove Ads + Export Backup   [$1.99 Unlock]
  Restore Purchases

Section — Data
  Export Backup（UDDF / CSV）    ← Premium 解鎖後可用
    （鎖定時：灰色 + 🔒 圖示）

Section — About
  Privacy Policy    →
  Terms of Use      →
  App Version       1.0.0 (Build 1)
```

### 7.2 語言切換（2026-07-28 更正：v1.0 規劃已被 v1.1 實作取代）

> 原規劃是「引導至 iOS App-Specific Settings」（下方保留原文供追溯），但
> **v1.1 實際做法改為 App 內建切換器**（`Services/AppLanguageManager.swift`），
> SettingsView 內 Picker 選擇語言，**立即生效不需離開 App**，「四段式解法」
> 同時涵蓋 SwiftUI 內容與 navigationTitle/tabItem 等系統層文字。細節見
> `docs/LOCALIZATION_GUIDE.md`「語言切換方式」。

**原規劃（v1.0，已被取代，僅供追溯）**：

```
Settings Row:
  Language  →  （Tap 觸發）
                ↓
  UIApplication.shared.open(
    URL(string: UIApplication.openSettingsURLString)!
  )
  ← 用戶在 iOS Settings.app 選擇語言後回到 App
  ← App 自動根據選擇的語言重新載入 String Catalog
```

### 7.3 ✅ IAP Premium 內容（已確認）

**免費版（核心全開）**：

| 功能 | 說明 |
|------|------|
| 全部 15 種解析器 | 核心功能，絕不鎖 |
| 手動新增 / 編輯 / 刪除潛水記錄 | 不鎖，搶 Dive Number 用戶 |
| 日誌列表、月曆、地圖聚類 | 不鎖 |
| 多語系 | 不鎖 |
| AdMob Banner 廣告（iOS only） | 免費版顯示（Logbook／Import／Settings 底部 + Map 空狀態，macOS 無廣告）|

**Premium $1.99 買斷解鎖（iOS only）**：

| 功能 | 說明 |
|------|------|
| 移除全站廣告 | Logbook／Import／Settings／Map 空狀態廣告全關 |

> **Export/Import Backup 澄清（2026-07-28）**：此功能與 Premium 無關，是免費
> 功能（不鎖），且目前因尚未完整測試通過，`SettingsView.swift` 用
> `showBackupSection = false` feature flag 暫時隱藏 UI（程式碼保留），待下一版
> 驗證後開放，與 IAP 購買狀態無關。原規劃的「Premium 解鎖 Export」已不成立。

### 7.4 ✅ 廣告位置（已確認，實際 4 處，原規劃僅 2 處已擴充）

**位置 1**：Import Tab Step 1 頁面，支援格式卡片區塊下方

```
[支援格式 Grid]
     ↓
[AdMob Banner 320×50 或 full-width adaptive]
     ↓
[Select File 按鈕]
```

**位置 2**：Map Tab 空狀態下方（`ContentUnavailableView` 下方加 `BannerAdView`）

```
[No GPS Dive Sites]
[Dives with GPS coordinates...]
     ↓
[AdMob Banner]
```

**位置 3**（實作後新增）：Logbook 列表底部（`PremiumAwareAdBanner` 固定於列表外的
底部區域，非穿插在 List rows 之間）

**位置 4**（實作後新增）：Settings 頁面底部

**原規劃「絕對禁止 Logbook 主列表內放置廣告」現況**：實際做法是 Banner 固定在
`.insetGrouped List` **之外**的底部區域，並非穿插在滾動列表的 rows 之間，
因此不違反原本「不得破壞列表滾動流暢度」的精神——原則本身（不得穿插在 rows
之間）仍然有效，只是新增了「列表容器外的固定底部欄」這個原規劃未考慮到的
第三種位置。

---

## 8. 跨切面設計

### 8.1 ✅ 多語系（已確認：18 種語言）

> ⚠️ **重大範圍變更**：原計劃 3 種語言（en / zh-Hant / zh-Hans）擴充至 **18 種**。

**框架**：Xcode String Catalog（`Localizable.xcstrings`）

**實際上線 18 語言清單**（2026-07-28 核對 `Localizable.xcstrings` 實際內容；
與本文件原規劃版本不同，原版列的 pt-BR/sv/nb/da/fi/ru/pl 皆非實際採用語言，
以下為正確清單）：

| # | 語言 | Locale |
|---|------|--------|
| 1 | English | `en` |
| 2 | English (UK) | `en-GB` |
| 3 | 繁體中文 | `zh-Hant` |
| 4 | 簡體中文 | `zh-Hans` |
| 5 | 日本語 | `ja` |
| 6 | 한국어 | `ko` |
| 7 | Deutsch | `de` |
| 8 | Français | `fr` |
| 9 | Español | `es` |
| 10 | Italiano | `it` |
| 11 | Nederlands | `nl` |
| 12 | Português (Portugal) | `pt-PT` |
| 13 | Bahasa Indonesia | `id` |
| 14 | Bahasa Melayu | `ms` |
| 15 | Tiếng Việt | `vi` |
| 16 | ภาษาไทย | `th` |
| 17 | Ελληνικά | `el` |
| 18 | Hrvatski | `hr` |

翻譯已全數完成並經多輪審核（見 `V1_2_BACKLOG.md` 翻譯疑慮裁定紀錄章節）；
`docs/LOCALIZATION_GUIDE.md` 為維護流程/用詞規範的權威來源。

---

### 8.2 Accessibility（WCAG 2.1 AA）

> 完整稽核結果與逐項驗證見 `WCAG_2.1_AA_AUDIT_CHECKLIST.md`（權威來源）；
> 下表僅列本文件原規劃項目的完成狀態。

| 要求 | 實作狀況 |
|------|---------|
| 觸控目標 ≥ 44×44 pt | ✅ |
| VoiceOver accessibilityLabel | ✅ |
| 組合元素 `.combine` | ✅ |
| `.isHeader` trait | ✅ |
| 色彩對比 4.5:1 | ✅ 已審查完成 |
| Dynamic Type | ✅ |
| Dark Mode | ✅ |
| DiveSiteSheetView Accessibility | ✅ |
| Cluster badge AccessibilityLabel | ✅ 已本地化 |

---

### 8.3 效能目標

| 場景 | 目標 | 狀態 |
|------|------|------|
| 日誌列表滑動 | 60 fps | ✅ |
| 地圖 100+ 標記 | < 200ms | ✅ 已實作，功能完整上線 |
| Sheet 開啟動畫 | ≤ 16ms（1 frame）| ✅ 已實作，功能完整上線 |
| 多個 Pin 連續切換 Sheet | 無卡頓 | ✅ 已實作，功能完整上線 |
| 月曆 divesByDay 計算 | 即時 | ✅ |

---

## 9. iOS 18 新功能

> **狀態（2026-07-28）**：❌ **已終止規劃**。Control Center 擴展／Lock Screen
> Widget 於 v1.1 backlog #9/#10 經 PM 確認不需要，不會排入後續版本；本節以下
> 內容保留僅供歷史參考，未實作亦無計劃實作。

### Control Center 擴展（未實作）

- 快速存取：啟動 App 至 Logbook Tab，或顯示最近潛水統計
- 使用 `ControlConfigurationIntent` + `AppIntent`

### Lock Screen Widget（WidgetKit，未實作）

- 小：最近潛水日期 + 深度
- 中：地點 + 深度 + 時間
- Widget Target 需獨立（JD2-LogbookWidget）

### Home Screen 圖示變體

- Light / Dark / Tinted 三版本
- Asset Catalog 各設對應 AppIcon

### 相容性策略（未實作章節不適用）

- `@available(iOS 18, *)` 保護所有新功能
- 降級：不可用時靜默略過

---

## 10. 確認決策紀錄

| # | 決策 | 確認結果 | 日期 |
|---|------|---------|------|
| **#1** | Map Pin 點擊行為 | ✅ Medium Detent Sheet（0.35 / .large），`presentationBackgroundInteraction(.enabled)` | 2026-05-20 |
| **#2** | 匯入成功後行為 | ✅ 自動切至 Logbook Tab + `.success` 觸覺 + 捲動頂端 + 1 秒高亮淡出（Week 11 實作）| 2026-05-20 |
| **#3** | App 內語言切換 | ✅ 引導至 iOS App-Specific Settings（`UIApplication.openSettingsURLString`）**⚠️ 2026-07-28 標註：此決策已被 v1.1 的 App 內建切換器（`AppLanguageManager`）取代，見 §7.2** | 2026-05-20 |
| **#4** | $1.99 Premium 內容 | ✅ 移除廣告 + Export Backup（UDDF / CSV）；核心功能全免費 | 2026-05-20 |
| **#5** | 廣告位置 | ✅ Import Tab Step 1 格式卡片下方 + Map Tab 空狀態下方；禁止放日誌列表 | 2026-05-20 |
| **#6** | Edit Dive — Duration | ✅ 唯讀（解析器決定）| 2026-05-20 |
| **#7** | 手動新增潛水入口 | ✅ Logbook Tab 右上角「+」按鈕 → sheet 呈現 `NewDiveEntryView`（Week 11 實作）| 2026-05-20 |
| **#8** | Map 空狀態文案 | ✅ 「No GPS Dive Sites / Dives with GPS coordinates will appear on this map.」| 2026-05-20 |
| **#9** | Cluster 點擊行為 | ✅ Zoom In（Below 標準；`showAnnotations` zoom-to-fit）| 2026-05-20 |
| **#10** | 多語系數量 | ✅ **18 種語言**（清單待 PM 確認）| 2026-05-20 |

---

## 11. Week 10–12 設計工作清單（歷史記錄，2026-07-28：全數已完成）

> 本節為 Week 10 規劃當時的工作清單快照，**所有項目均已完成**（含 Settings／
> Edit／IAP／廣告／18 語系翻譯／WCAG 審查／App Store 送審），保留原文不逐項
> 打勾，僅供追溯規劃脈絡；iOS 18 功能項目例外，已於 §9 說明終止規劃。

### Week 10（本週）— 地圖

**待 PM 回答**：
- [ ] 確認 18 語言完整清單
- [ ] 確認 DiveSiteSheetView 的 full details 是否要有「在地圖外開啟詳情頁」按鈕（push 到獨立詳情頁）

**Claude 實作**：
- [ ] `DiveSiteAnnotation.swift`（無 callout，`canShowCallout = false`）
- [ ] `DiveMapRepresentable.swift`（`didSelect` 觸發 callback，無 callout）
- [ ] `DiveSiteSheetView.swift`（新元件，peek + full details）
- [ ] `MapView.swift`（`isPresented` + `selectedDive` 雙 State，`presentationBackgroundInteraction`）
- [ ] `MainTabView.swift`（`MapPlaceholderView` → `MapView`）
- [ ] `Localizable.xcstrings`（4 個新 key）
- [ ] 地圖相關 Accessibility 標籤

**PM 驗證**：
- [ ] Simulator：pin 點擊 → sheet 0.35 出現，觸覺感受正確
- [ ] 連續點擊不同 Pin → sheet 內容切換無關閉
- [ ] Cluster tap → zoom in
- [ ] 拖曳把手 → sheet 至 large → 全詳情可見
- [ ] 地圖切換 Standard / Hybrid

### Week 11

- [ ] 確認決策 #7（手動新增潛水）
- [ ] 確認 18 語言清單（開始翻譯）
- [ ] `SettingsView`（語言引導 + IAP + About）
- [ ] `DiveLogEditSheet`（編輯功能，免費）
- [ ] AdMob Banner 整合（Import + Map 空狀態）
- [ ] IAP StoreKit 2 實作
- [ ] Import Done → 自動切 Logbook + 高亮動畫
- [ ] String Catalog 18 語翻譯
- [ ] iOS 18 功能（Control Center / Lock Screen / Icon）

### Week 12

- [ ] WCAG 2.1 AA 全畫面色彩對比審查
- [ ] VoiceOver 完整流程測試（所有 Tab）
- [ ] Dynamic Type 最大字級壓力測試
- [ ] 18 語言各抽樣驗證（特別注意 RTL 語言若有）
- [ ] App Store 截圖（6.7" / 6.1" / iPad）
- [ ] App Store 文案（en + zh-Hant，最少）
- [ ] Beta TestFlight 招募 50–100 人

---

*文件由 Claude 整理，基於 Week 9 完成的程式碼與 2026-05-20 PM 確認的所有決策。*  
*下次更新：Week 10 完成後，補充驗證結果。*
