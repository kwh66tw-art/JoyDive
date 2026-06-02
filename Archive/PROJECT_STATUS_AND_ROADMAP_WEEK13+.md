# JD2-Logbook 專案架構與代辦清單（Week 13+ 整合版）

**最後更新**：2026-05-28  
**當前進度**：Week 13 完成，正準備進入上線前最後衝刺  
**目標上線日期**：2026-08-18（App Store 正式版）  
**PM 時間預算**：已用 ~110 小時，剩餘 contingency 可用

---

## 目錄

1. [專案概覽](#1-專案概覽)
2. [完整架構](#2-完整架構)
3. [技術棧](#3-技術棧)
4. [進度總結（Week 1–13）](#4-進度總結week-1–13)
5. [已知踩雷與解決方案](#5-已知踩雷與解決方案)
6. [P0 待辦（上線前必做）](#6-p0-待辦上線前必做)
7. [P1 待辦（Week 13–14，第二優先）](#7-p1-待辦week-13–14第二優先)
8. [P2 待辦（v1.0.1 延後）](#8-p2-待辦v101-延後)
9. [執行策略與時程](#9-執行策略與時程)

---

## 1. 專案概覽

### 核心定位
**JD2-Logbook** 是一款 iOS + macOS 雙平台潛水日誌應用，支援從多種潛水電腦（6+ 格式）匯入記錄，提供 GPS 地圖、統計分析、多語系。

### 目標用戶
- 休閒潛水員（OWD–DM）
- 有潛水電腦設備
- 繁體中文為主要市場（但支援 18 種語言）

### 版本與上線計畫
```
v1.0（原定 2026-08-18）
  ├── 核心功能全數完成
  ├── iOS 18 新功能（Control Center / Lock Screen）
  ├── WCAG 2.1 AA 可達性合規
  ├── 18 種語言本地化
  └── App Store 正式版

v1.0.1（緊急修復）
  └── Beta 反饋 P1 bug 修復

v1.1（後續迭代）
  ├── 其他 3 種解析器（Seabear / Seac / Divesoft）
  ├── Export 功能擴充（高階選項）
  └── 社群功能試驗
```

---

## 2. 完整架構

### 2.1 導覽結構

#### iOS 版
```
JD2_LogbookApp (WindowGroup)
  └── MainTabView (TabView)
      ├── Tab 0: LogbookContainerView
      │   └── NavigationStack
      │       ├── DiveLogListView (列表 / 月曆切換)
      │       │   ├── StatsHeaderView (統計 Bar)
      │       │   └── DiveRowView (卡片) → push → DiveLogDetailView
      │       └── DiveCalendarView
      │           └── → DiveLogDetailView
      │
      ├── Tab 1: MapView
      │   ├── DiveMapRepresentable (MKMapView UIViewRepresentable)
      │   │   ├── DiveSiteAnnotation / DiveSiteAnnotationView (pin)
      │   │   └── DiveClusterAnnotationView (聚合)
      │   ├── MapTypeToggleButton (右上，Standard/Hybrid)
      │   └── .sheet → DiveSiteSheetView (Medium Detent 0.35/.large)
      │
      ├── Tab 2: ImportWizardView
      │   ├── Step 1: 格式選擇 + 檔案選取
      │   ├── Step 2: 解析中...
      │   └── Step 3: 成功/失敗
      │
      └── Tab 3: SettingsView
          ├── Language (iOS Settings 引導)
          ├── Premium IAP ($1.99 buy-once)
          ├── Export Backup (Premium only)
          └── About

```

#### macOS 版（Week 13 重構）
```
JD2_LogbookApp (WindowGroup)
  └── MainTabView (NavigationSplitView，不是 TabView)
      ├── Sidebar (NavigationStack)
      │   ├── "Dive Logbook" (with toggle/+ buttons)
      │   ├── "Map"
      │   ├── "Import"
      │   └── "Settings"
      │
      └── Detail (NavigationStack 或 HSplitView)
          ├── 日誌列表/月曆
          ├── 地圖 (with HSplitView 側邊詳情)
          ├── 匯入嚮導
          └── 設定
```

### 2.2 資料模型

```
DiveLog (SwiftData Model)
├── UUID id (PrimaryKey)
├── String? location
├── String? siteName
├── Date diveDateTime
├── Double? maxDepth (m)
├── Int? duration (秒)
├── Double? waterTemperature (°C)
├── String gasType (Air / Nitrox / Trimix)
├── String? environmentType (Seawater / Freshwater)
├── Double? latitude
├── Double? longitude
├── String? notes
├── String? buddy
├── String sourceFormat (UDDF / SubsurfaceXML / ... / manual)
├── @Relationship var diveProfile: DiveProfile?
└── Timestamp createdAt, modifiedAt
```

### 2.3 核心模組

| 模組 | 職責 | 關鍵檔案 |
|------|------|---------|
| **解析器** | 6 種檔案格式解析 | `DiveLogImporter.swift` (615 tests ✅) |
| **UI 視圖** | 4 個 Tab，雙平台兼容 | `Views/` (iOS/macOS @if guard) |
| **地圖** | GPS 座標、聚類、Pin 互動 | `DiveMapRepresentable.swift` + `DiveSiteAnnotation.swift` |
| **多語系** | 18 種語言 String Catalog | `Localizable.xcstrings` (133 keys) |
| **IAP** | Premium 購買 ($1.99) | `StoreManager.swift` + StoreKit 2 |
| **廣告** | AdMob Banner | `AdBannerView.swift` (Premium gate) |
| **匯出** | UDDF / CSV 格式 | `DiveExporter.swift` (Premium only) |

---

## 3. 技術棧

| 層級 | 技術選型 | 備註 |
|------|---------|------|
| **UI Framework** | SwiftUI 5 | NavigationStack、TabView、Sheet |
| **資料庫** | SwiftData | 本地持久化，無需 Core Data |
| **地圖** | MapKit (MKMapView UIViewRepresentable) | 不用 SwiftUI Map API |
| **檔案選取** | UIDocumentPickerViewController (iOS) / NSOpenPanel (macOS) | 沙盒受限 |
| **多語系** | Xcode String Catalog (`.xcstrings`) | 支援 18 種語言 |
| **IAP** | StoreKit 2 | 非 SKProductsRequest |
| **廣告** | Google Mobile Ads SDK (SPM) | AdMob Banner (320×50 / 728×90 adaptive) |
| **權限** | LocationManager (Core Location) | Pending: recenter 功能 |
| **最低 iOS 版本** | iOS 17.0 (建議) | sensoryFeedback API 相容性 |
| **macOS 支援** | Native SwiftUI (不用 Catalyst) | 需 macOS 14+ (Sonoma) |

---

## 4. 進度總結（Week 1–13）

### ✅ 完成項目

#### **Week 1–2：基礎搭建**
- [x] Xcode 工作區搭建 + SPM 初始化
- [x] JoyDiveCore 代碼複製 + 編譯驗證
- [x] SwiftData 模型設計 + 初始化流程
- [x] i18n 基礎架構決策 (String Catalog)

#### **Week 3–6：核心 4 種解析器**
- [x] **UDDF Parser** (350+ 行，50+ tests)
- [x] **SubsurfaceXML Parser** (Suunto / Shearwater / Cressi / Mares / Garmin)，42 tests
- [x] **SubsurfaceCSV Parser** (RFC 4180 邊界情況)，20+ tests
- [x] **SuuntoJSON Parser** (官方樣本 3 個)，15+ tests
- [x] **ImportCoordinator** 統一匯入流程，4 種格式混合成功率 >95%
- [x] **性能基準**：100 檔案匯入 < 10 秒

#### **Week 7–8：擴展解析器 (2 種)**
- [x] **Garmin Connect API** 或 FIT 二進位
- [x] **Oceanic (OCF + XML)** 混合格式
- [x] 7 種格式全量測試，單元測試覆蓋率 >85%

#### **Week 9–10：UI + GPS 地圖**
- [x] **日誌列表視圖** (StatsHeaderView + DiveRowView 卡片)
- [x] **月曆視圖** (DiveCalendarView，locale-aware)
- [x] **日誌詳情頁** (唯讀，.insetGrouped List)
- [x] **匯入嚮導** (3 步驟狀態機)
- [x] **GPS 地圖** (MKMapView + 聚類，100+ 標記 <200ms)
- [x] **Medium Detent Sheet** (0.35 peek / .large full)
- [x] **Map Type Toggle** (Standard / Hybrid)
- [x] **基礎多語系** (3 種語言完成)

#### **Week 11：廣告 + IAP + 設定 + iOS 18 功能**
- [x] **AdMob Banner** (Import Step 1 + Map 空狀態)
- [x] **IAP Premium** ($1.99 buy-once，移除廣告 + Export)
- [x] **SettingsView** (語言、Premium、About)
- [x] **多語系編輯** (免費，Duration 唯讀)
- [x] **手動新增潛水** (NewDiveEntryView + Save)
- [x] **18 種語言翻譯** (130 keys × 18 langs，i18n_review_V3.csv)
- [x] **Control Center 擴展** (iOS 18，快速存取)
- [x] **Lock Screen Widget** (最近潛水)
- [x] **Home Screen 圖示變體** (Light / Dark / Tinted)

#### **Week 12：測試 + 修復 + 上線準備**
- [x] **Export 功能** (UDDF 3.2.2 / CSV RFC 4180，Premium gate)
- [x] **18 語言最終確認** (133 keys，複數結構、物理符號)
- [x] **macOS 跨平台修復** (18 檔，`#if os(iOS)`/macOS 分支)
- [x] **文件選擇器 Crash 修復** (.entitlements 沙盒設定)
- [x] **整合測試清單** (15 項檢查)
- [x] **WCAG 基礎** (accessibilityLabel + VoiceOver)

#### **Week 13：macOS UI 重構 + 地圖完善**
- [x] **macOS NavigationSplitView** (Sidebar + Detail)
- [x] **月曆年月快速選擇** (Popover Picker)
- [x] **DiveLogListView macOS 卡片改造** (移除藍色 Focus Ring)
- [x] **設定頁 macOS 樣式** (.formStyle(.grouped))
- [x] **地圖詳情面板** (iOS Sheet / macOS HSplitView)
- [x] **聚合徽章數字防消失** (annotation didSet 防護)
- [x] **地圖互動穩定性** (DispatchQueue.main.async 延後執行)
- [x] **Build 成功** (iOS + macOS 雙平台全過)

---

### ⚠️ 已知踩雷與解決方案（已驗證正確）

#### **1. 聚合徽章數字消失**
**症狀**：Cluster zoom in/out 後數字變空白  
**真因**：`clusteringIdentifier` 被 MapKit 原地重指派時重置為 nil  
**✅ 解法**：`DiveSiteAnnotationView` 覆寫 `annotation` didSet，重套 `clusteringIdentifier`（代碼已實作）

#### **2. SwiftUI MapKit 重入無窮迴圈**
**症狀**：在 updateUIView render 流程同步呼叫 `setCenter`/`selectAnnotation` → `reentrant layout` 卡頓、數字消失  
**✅ 解法**：所有地圖互動操作包 `DispatchQueue.main.async` 延後執行（已在代碼）

#### **3. 不要用 @Binding 回寫指令狀態**
**症狀**：指北/置中用 Bool binding 在 async 內設回 false，回寫時機不可靠  
**✅ 解法**：改用 Int token（每次 +1），Coordinator 比對 `lastToken`（recenter 設計已定案）

#### **4. macOS 檔案選擇器 Crash**
**症狀**：EXC_BREAKPOINT "Selected File Read app sandbox entitlement"  
**✅ 解法**：加 `.entitlements` 檔案 + `CODE_SIGN_ENTITLEMENTS` pbxproj 設定（已修復）

#### **5. 地圖聚合不消失的過時方案**
**已驗證無效**（別再試）：自繪 image badge、NSImage drawingHandler、MKMarkerAnnotationView auto-count、viewFor 內設 glyphText  
**唯一正確解**：覆寫 `annotation` didSet，因為這是不論新建/dequeue/原地重指派都必觸發的節點

---

## 5. P0 待辦（上線前必做）

### ✅ 驗證類（無 coding，純測試）

#### **P0-1：多語系全面審查**
**職責**：PM  
**時間**：1.5 小時  
**檢查清單**：
- [ ] 開啟 `JD2-Logbook_i18n_review_V3.csv` 或最新 Excel
- [ ] 驗證所有 133 keys 在繁中、簡中、英文是否完整（不是「needs_translation」）
- [ ] 特別檢查：
  - 單位符號（m / min / °C / %%）是否統一
  - 複數結構（`%d dives`）是否按語言規則（歐洲 one/other、亞洲 other only）
  - 日期格式是否按 locale 本地化（月名、星期）
  - 新增字串（高氧 Nitrox / Export / Premium）是否完整
- [ ] **若有缺字或不一致，列清單，通知我補齊**

**預期產出**：i18n 最終確認報告（有無遺漏 / 建議修正）

---

#### **P0-2：WCAG 2.1 AA 可達性審核**
**職責**：PM  
**時間**：2 小時  
**檢查清單**：

**a) 觸控目標**
- [ ] 所有按鈕、圖標、可互動元素 ≥ 44×44 pt
- [ ] 日曆箭頭、地圖切換按鈕、月份選擇是否都 ≥ 44×44
- [ ] 特別檢查：DiveRowView 卡片點擊區域（應整張卡片可點）

**b) VoiceOver 導覽**
- [ ] 開啟 iOS Settings → Accessibility → VoiceOver
- [ ] 完整走過所有 Tab（Logbook → Map → Import → Settings）
- [ ] 驗證每個 accessibilityLabel 是否有意義（非自動生成亂碼）
- [ ] 檢查清單：
  - [ ] DiveRowView：「xxx 潛水在 [地點]，[日期]，深度 xxx 公尺」
  - [ ] 月曆日期：「[日期]，[潛水數] 筆潛水」
  - [ ] 地圖 Pin：「[地點] Pin，點擊查看詳情」
  - [ ] Cluster Badge：「[數字] 潛水地點」
  - [ ] 按鈕：「編輯」「匯出」「移除廣告」

**c) 色彩對比**
- [ ] 用 Xcode Accessibility Inspector 檢查關鍵 UI 元素
- [ ] 驗證文字 vs 背景對比 ≥ 4.5:1
- [ ] 特別檢查：
  - [ ] DiveRowView 次要資訊（灰色文字）
  - [ ] 列表選中狀態是否可識別（非只靠顏色）
  - [ ] 地圖 Cluster badge 白字 vs 藍色背景

**d) 動態字體**
- [ ] iOS Settings → Accessibility → Display & Text Size → 調整到最大 (A)
- [ ] 回到 App，驗證所有 UI 是否正確縮放（無重疊、截斷）
- [ ] 特別檢查：DiveLogDetailView 的 Section headers、DiveSiteSheetView 地點名

**預期產出**：WCAG 審核報告（檢查項目 + 有無不合規，若有列出具體位置）

---

#### **P0-3：測試覆蓋率 + 匯入成功率驗證**
**職責**：我（Claude）  
**時間**：1 小時  
**執行**：
```bash
# 1. 單元測試覆蓋率
swift test --configuration Release  # 看輸出的 coverage %

# 2. 7 種格式混合匯入測試
# 創建測試 Bundle，包含 TestFiles/ 內各 7 種格式 1 個檔案
# 依序匯入，驗證成功率
```

**預期產出**：測試覆蓋率報告 + 匯入成功率 log（應 >85% 覆蓋、>95% 成功率）

---

### ⚠️ 實作類（需 coding）

#### **P0-4：定位「回到我的位置」按鈕（recenter）**
**職責**：我（Claude）  
**時間**：2 小時  
**前置條件**：
1. Info.plist 加權限聲明
2. macOS entitlements 加定位權限（已在 Week 12）
3. SafeLocationManager 架構已審核定案

**實作清單**：
- [ ] 新檔 `Services/SafeLocationManager.swift`
  - `@MainActor final class ... : NSObject, ObservableObject`
  - `@Published authorizationStatus`
  - 漸進式授權（點擊按鈕才請求，不在地圖載入時）
  - 被拒絕時彈 Alert + 「前往設定」
  
- [ ] 修改 `DiveMapRepresentable`
  - 加 Int token `shouldRecenter`（非 Bool）
  - Coordinator 在 `didUpdate userLocation` delegate 時執行置中
  - `showsUserLocation` 只在已授權時開啟
  
- [ ] 修改 `MapView`
  - 加 "回到我的位置" 按鈕（圖示 `location.fill` / 被拒 `location.slash.fill`）
  - 放右上控制鈕組（圖層切換下方）
  - 觸發時 token += 1，Coordinator 接收並執行置中

**預期產出**：recenter 功能完整，點擊按鈕自動置中使用者位置（已授權情況）

---

## 6. P1 待辦（Week 13–14，第二優先）

### **P1-1：macOS UI 完全修正（尚未 commit）**
**職責**：我（Claude）  
**時間**：4–6 小時  
**背景**：本週 Week 13 macOS 修正只做完 A–F 6 項，還有大量 UI 問題待修

**按優先順序執行**（參考 `ui_ux_audit_report.md` v3.1）：

1. **Diff B（最優先）** — 雙導航對稱對齊
   - MacLogbookSplitView 左欄加 NavigationStack + `.navigationTitle("Dive Logbook")`
   - 右欄保留 NavigationStack + `.navigationTitle("")`（空標題保證高度對稱）
   - 消除頂部空白與不對稱

2. **Diff C** — 月曆清空右欄功能
   - `DiveCalendarView.onDiveTapped` 改 `((DiveLog?)->Void)?`
   - 點空白日期 / 取消選取時呼叫 `onDiveTapped?(nil)`

3. **Diff D** — Settings 頂部補丁
   - SettingsView `.formStyle(.grouped).padding(.top, -16)`

4. **P1（高優先）** — List 選取框過大 + 藍色 Focus Ring
   - `.listStyle(.sidebar)` 取代 `.plain`
   - 移除 `.listRowBackground`
   - 加 `.focusable(false)`

5. **P2（較低優先）** — iOS 月曆年月快速選擇
   - 月份標題包 `Menu { yearPicker + monthPicker }`（iOS only）

**預期產出**：macOS UI 完整修正後的 git commit

---

### **P1-2：iOS 18 新功能完整驗證**
**職責**：PM  
**時間**：2 小時  
**檢查清單**：
- [ ] Control Center 擴展是否在 iOS 18 設備上正確顯示（可能需實機測試）
- [ ] Lock Screen Widget 是否能正確更新最近潛水資訊
- [ ] Home Screen 圖示三版本（light / dark / tinted）是否在各模式下正確應用
- [ ] 降級策略：在 iOS 17 及以下設備上是否靜默略過（無 crash）

**預期產出**：iOS 18 功能驗證報告

---

### **P1-3：AdMob 正式 Ad Unit ID 接入**
**職責**：PM（人工操作）+ 我（支援）  
**時間**：30 分鐘  
**步驟**：
1. PM 在 AdMob console 建立正式 App + 兩個 Banner Ad Unit（Import + Map 空狀態）
2. 提供 App ID 和兩個 Ad Unit ID
3. 我修改 `AdBannerView.swift` 的常數
4. 修改 `Info.plist` 加 `GADApplicationIdentifier`
5. Build 並驗證廣告是否顯示

**預期產出**：AdMob 正式 SDK 接入完成，廣告正常顯示

---

## 7. P2 待辦（v1.0.1 延後）

### **P2-1：Beta TestFlight 測試**
**時間**：3–5 天（測試者）  
**步驟**：
1. Xcode Build Archive
2. App Store Connect → Distribute → Upload
3. 加入 Internal Testers（至少 5 人）
4. 測試重點：
   - [ ] 匯入 7 種格式各 1 個檔案
   - [ ] IAP 購買（Sandbox Tester 帳號）
   - [ ] Export UDDF / CSV
   - [ ] 地圖 pin tap、聚類點擊
   - [ ] 18 種語言各抽樣（至少 en / zh-Hant / ja / de）
5. 收集反饋，歸類 P0 / P1 / P2

**預期產出**：Beta 反饋清單 + bug 修復清單

---

### **P2-2：App Store 提審文件準備**
**時間**：2 小時  
**檢查清單**：
- [ ] 截圖（2 語言）：
  - iPhone 6.9" (Pro Max 風景)：6–10 張
  - iPhone 6.1"（基礎）：6–10 張
  - iPad 13"（橫屏）：5 張
- [ ] App 描述：
  - [ ] 繁中（主要）
  - [ ] 簡中（可選）
  - [ ] 英文（國際市場）
- [ ] 關鍵字：潛水、日誌、GPS、電腦 等（多語言）
- [ ] 隱私政策 URL（必填）
- [ ] 支援 URL（建議填）
- [ ] 年齡分級問卷（通常 4+）
- [ ] App Icon 確認
- [ ] Bundle ID、Build Number 檢查

**預期產出**：App Store Connect 完整資訊填妥

---

### **P2-3：其他 3 種解析器（v1.1 預備）**
**時間**：估 Week 7–8 的規模（12 小時 PM + Claude coding）  
**目標格式**：
- Seabear (SDE / DLF)
- Seac (SEAC DX / CX 二進位)
- Divesoft (FreediveComputer 日誌)

**何時動手**：v1.0 上線後、穩定運行 1–2 週後再開始

---

## 8. 執行策略與時程

### 立刻行動（今天–明天）

#### **Day 1（今日）**
1. **你審查 i18n**（P0-1，1.5h）
   - 開啟 CSV 檔，逐行檢查
   - 產出「i18n 最終審查報告」

2. **你審查 WCAG**（P0-2，2h）
   - 開啟 VoiceOver、Accessibility Inspector
   - 走一遍所有 Tab
   - 產出「WCAG 審核報告」

3. **我驗證測試覆蓋率**（P0-3，1h）
   - 跑 `swift test`，驗證覆蓋率
   - 產出「測試報告」

#### **Day 2（明天）**
1. **我實作 recenter**（P0-4，2h）
   - SafeLocationManager 新檔
   - DiveMapRepresentable 修改
   - MapView 新增按鈕

2. **我修正 macOS UI**（P1-1，4–6h）
   - 依序執行 Diff B → C → D → P1 → P2
   - 每個 diff 後停下，等你 build 截圖確認

3. **你驗證 iOS 18 功能**（P1-2，2h）
   - 可在實機或 iOS 18 beta simulator 上驗證

### 提審前衝刺（Week 14）

1. **Beta TestFlight**（3–5 天）
   - 招募 50–100 測試者
   - 收集反饋
   - 修復 P0 bugs

2. **App Store 文件準備**（2 小時）
   - 截圖、描述、隱私政策

3. **最後編譯 + 簽署**（PM 人工操作）
   - Xcode Archive
   - App Store Connect Upload
   - 提審

4. **等待 App Store 審核**（3–5 天，不需我們做什麼）
   - 通常沒有問題，直接通過

### 發佈與上線

- **審核通過** → 立刻發佈至 App Store（同時 iOS + macOS）
- **監控 Crash Rate**（v1.0 上線後 1 週）
  - < 0.5% 為安全線
  - > 0.5% 立刻發佈 v1.0.1 修復

---

## 9. 風險與應對

| 風險 | 機率 | 應對 |
|------|------|------|
| i18n 有大量缺字 | 15% | 優先補繁中，其他 16 語延至 v1.1 |
| WCAG 不合規（色彩對比） | 20% | 調整文字顏色或背景，Week 14 優先修 |
| iOS 18 功能在 iOS 17 crash | 10% | `@available` 保護，或關閉功能 |
| recenter 權限流程複雜 | 5% | 方案已定案，實作應直接 |
| Beta 反饋大量 bug | 35% | 優先修 P0（閃退），P1 延至 v1.0.1 |
| App Store 審核被駁 | 5% | 檢查隱私政策、條款、IDFA 宣告等 |

**Contingency**：预留 30 小時應急時間（已內含在 PM 110 小時預算）

---

## 附錄：Git 提交清單

**待 commit**（需你在本機終端手動執行）：

```bash
# 清除 git lock（若存在）
rm -f .git/index.lock

# Stage 所有修改
git add -A

# P0-1：recenter 功能
git commit -m "feat(map): add 'back to my location' button with SafeLocationManager (P0-4)"

# P0-2：macOS UI 修正（Diff B–P2）
git commit -m "fix(macOS): complete UI layout — dual navigation, calendar sync, settings style (P1-1)"

# P0-3：iOS 18 驗證結果
git commit -m "test: verify iOS 18 features (Control Center, Lock Screen, App Icons)"

# P1-1：AdMob Ad Unit ID 更新
git commit -m "config: update AdMob Ad Unit IDs to production (P1-3)"
```

---

**文件版本**：v1.0（Week 13 完整整合）  
**下次更新**：Week 14 中期，補充最新進度

