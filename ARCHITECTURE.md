# JD2-Logbook 架構設計

**最後更新**：2026-07-28（反映 F5/F6 遷移後 + v1.2：DiveKit/DiveImportKit 改為家族共用
SPM 套件外部引用，本地 JD2Core/Algorithm 僅存 DiveReplayEngine.swift，State/ 資料夾已移除）

---

## 整體架構

```
┌─────────────────────────────────────────┐
│              SwiftUI Views              │
│  (Logbook / Map / Import / Settings)    │
└──────────────────┬──────────────────────┘
                   │ @Query / @Environment
┌──────────────────▼──────────────────────┐
│              JD2Core                    │
│ ┌────────┐┌──────────┐┌────────────────┐│
│ │ Models ││Importers ││Algorithm       ││
│ │SwiftData││(Adapter)││(DiveReplayEngine││
│ │        ││         ││ 僅此一檔)       ││
│ └────────┘└──────────┘└────────────────┘│
│              Utilities                   │
└──────────────────┬───────────┬──────────┘
                   │           │ SPM local path
┌──────────────────▼──────┐ ┌──▼───────────────────┐
│    SwiftData / SQLite   │ │ DiveKit / DiveKitUI   │
└──────────────────────────┘ │ DiveImportKit         │
                              │（_JD2-family/，家族   │
                              │ 三個 App 共用）        │
                              └───────────────────────┘
```

---

## 模組說明

### JD2Core/Models

| 檔案 | 說明 |
|------|------|
| `DiveLog.swift` | 主要 SwiftData 模型，包含潛水所有欄位（深度、時間、氣體、GPS 等）。`DiveProfileSample` 使用短 CodingKey (`t`/`d`) 節省 JSON 儲存體積。 |
| `DiveLogBackup.swift` | Export/Import 備份格式（v1.1 新增），供裝置間搬移/還原完整資料庫。 |
| `DiveLogDatabase.swift` | ModelContainer 單例，`DiveLogDatabase.shared.modelContainer` 提供全 App 存取。 |
| `DiveSettings.swift` | 使用者偏好設定模型（v1.1 新增）。 |
| `GasMix.swift` | 氣體混合（空氣、EAN、Trimix、純氧），含 O₂ / He / N₂ 百分比。 |
| `DiveEnvironment.swift` | 潛水環境枚舉（海水、淡水、高鹽）。 |
| `SimulatedDiveProfile.swift` | 匯入時若來源無逐秒剖面樣本，用於合成模擬剖面（v1.1 新增）。 |

### ~~JD2Core/State~~（F5 已移除，2026-07-18）

v1.1 曾新增此資料夾（`DiveComputerState.swift`／`SurfaceStatus.swift`／
`LogSummary.swift`，潛水電腦運算狀態/水面狀態/日誌摘要快照），F5 遷移時
這三個型別已上收進統一 `DiveKit` 套件本體（`DiveKit/Sources/DiveKit/
{DiveComputerState,SurfaceStatus,LogSummary}.swift`，供三個 App 共用），
本地資料夾已完全移除，改為 `import DiveKit` 直接使用。

### JD2Core/Importers（F6 已完成遷移，2026-07-19：全部解析器搬遷至 DiveImportKit）

現在只有 3 個檔案，v1.1 時代 9+9 個 struct 內嵌解析器＋`MinimalZipReader` 等
全部已搬遷到家族共用套件 `DiveImportKit`（15 種格式，本 repo 已無任何本地
解析器/去重邏輯拷貝）：

| 檔案 | 行數 | 說明 |
|---|---|---|
| `DiveImportKitAdapter.swift` | ~454 行 | **全 App 唯一 import DiveImportKit 的進入點**。把家族層 `DiveImportKit.DiveLogImporter`/`DiveLogFormat` 轉接成 App 本地型別。 |
| `DiveLogImporter.swift` | ~308 行 | 本地 `DiveLogImportError` enum（與 `DiveImportKit.DiveLogImportError` 同名同結構，errorDescription 樣板文字需與 Kit 保持同步，見 `SYNC_TO_JD2-ULTRA.md` #8 記錄的維護陷阱）＋本地 `DiveLogImporter` protocol 定義。 |
| `ImportCoordinator.swift` | ~322 行 | 統一匯入流程協調器：檔案驗證、格式自動偵測、解析、資料庫儲存、批次去重（App 層邏輯，非 Kit 範圍）。 |

發現匯入解析器 bug（格式解析錯誤、去重邏輯問題）一律回 `DiveImportKit`
（`_JD2-family/DiveImportKit`，獨立 git repo）修，不得在本 repo 本地修改
繞道（家族鐵律 3，單一戰場）。目前引用版本見 `_JD2-family/F-02-COMPAT_MATRIX.md`。

#### 測試樣本統一管理（2026-07-18）

原本分散在本 repo 的 `TestFiles/`（測試 fixture）與 `file_format_research/`（格式研究樣本）
已集中至家族共用目錄 `_JD2-family/dive-log-samples/`（供 ultra 等其他專案未來重用），
測試檔的 fixture 路徑已同步更新。詳見 `_JD2-family/F-00-文件登錄表.md`。

### JD2Core/Algorithm（F5 已完成遷移，2026-07-18）

現在**僅存 `DiveReplayEngine.swift`** 一個檔案。原本 v1.1 曾有的本地 fork
（`Buhlmann.swift`／`DiveEngine.swift`／`DecoCalculator.swift`／
`DivePlanner.swift`／`FreeDive.swift`／`GuidanceBanner.swift`／
`OxygenToxicity.swift`，與 Ultra 側稽核已知 9 項安全級問題同源）已於 F5
里程碑**整包刪除**，改為 `import DiveKit` 使用家族統一套件（SPM local
path 引用 `../../_JD2-family/DiveKit`，見下方「SPM 依賴」）。演算法問題
發現後一律回統一 DiveKit 修（單一戰場，見 `../CLAUDE.md` 家族鐵律），
**不得在本 repo 繞道本地修改**。

`DiveReplayEngine.swift` 是**本 repo 專屬、現行使用**的日誌回放引擎（匯入後
計算 NDL/減壓狀態摘要），語意與即時電腦不同，`import DiveKit` 呼叫
`Buhlmann`/`AlgorithmConstants` 等家族核心型別，本身不隨家族遷移（非演算法
本體，是 Logbook 特有的剖面重放邏輯）。

### JD2Core/Utilities

| 檔案 | 說明 |
|---|---|
| `Extensions.swift` | 共用型別擴充。 |
| `MockDataSeeder.swift` | 開發/測試用假資料產生器。 |

### Services

- `PurchaseManager.swift` — StoreKit 2 IAP 管理，`@Observable`，提供 `isPremium` 狀態給全 App

---

## SwiftData Schema

實際欄位（核對 `DiveLog.swift` 現況，非 embedded 型別而是多數以字串/JSON 存儲，
供匯入器彈性寫入不同來源格式）：

```
DiveLog（@Model）
├── dateTime: Date
├── location: String
├── latitude / longitude: Double?
├── maxDepth: Double                    (公尺)
├── avgDepth: Double                    (公尺；0 = 未記錄，additive 欄位)
├── diveTimeSeconds: Int
├── entryTime / exitTime: Date?
├── gasMixJSON: String                  (GasMix enum 的 JSON 編碼，非 embedded)
├── waterTemperature: Double            (攝氏)
├── airTemperature: Double?
├── environmentType: String             ("seawater"/"freshwater"/"altitude")
├── surfacePressureBar: Double = 1.0    (高海拔環境用)
├── metersPerBar: Double = 10.0
├── weather / surfaceCondition / waterflow: String?
├── visibility: Double?                 (公尺)
├── wetsuitThickness: String?
├── weightTotal: Double?                (公斤)
├── cylinderMaterial / cylinderSize: String?
├── cylinderStartPressure / cylinderEndPressure: Double?  (bar)
├── notes: String = ""
├── profileSamplesJSON: String = "[]"   (JSON 編碼 [DiveProfileSample]，短 key t/d/w)
├── sourceFormat: String = "manual"     (匯入來源格式標記)
├── importExtrasJSON: String = "{}"     (匯入來源無對應欄位的原始資料 dump)
├── createdAt / updatedAt: Date
```

`DiveProfileSample`（非 `@Model`，profileSamplesJSON 內嵌結構）：
`timeSeconds` (t) / `depthMeters` (d) / `waterTemp?` (w)。

> ⚠️ `buddy` 欄位已於 commit `56dc1a3` 移除（v1.0 schema breaking change）。
> 模擬器如有舊資料需 Erase All Content and Settings。所有 v1.1 新增欄位皆為
> additive + 有預設值，lightweight migration 即足夠。

---

## UI 架構

### iOS：TabView

```
MainTabView (TabView)
├── Tab 0: LogbookContainerView
│   ├── DiveLogListView
│   ├── DiveCalendarView
│   └── DiveLogDetailView
├── Tab 1: MapView (MapKit)
├── Tab 2: ImportWizardView (3 步驟精靈；v1.1 改版格式清單以匹配新解析器)
└── Tab 3: SettingsView
```

### macOS：NavigationSplitView

```
MainTabView (NavigationSplitView)
├── Sidebar: Logbook / Map / Import / Settings
└── Detail:
    ├── Logbook → MacLogbookSplitView (HSplitView)
    │   ├── 左欄: List / Calendar
    │   └── 右欄: Detail / Empty state
    ├── Map → MapView
    ├── Import → ImportWizardView
    └── Settings → SettingsView
```

---

## 廣告架構

- `AdBannerView`：`UIViewRepresentable` 包裝 GoogleMobileAds `BannerView`（SDK v11）
- `PremiumAwareAdBanner`：封裝 Premium 判斷，Premium 用戶自動隱藏
- 廣告版位：Logbook 底部、Settings 底部、Import 底部、Map 空狀態
- macOS：廣告完全不渲染（`#if os(iOS)`）

---

## 多語系

- 使用 `Localizable.xcstrings`（String Catalog，Xcode 15+）
- 18 種語言：`zh-Hant`、`zh-Hans`、`en`、`en-GB`、`ja`、`ko`、`fr`、`de`、`es`、`it`、`nl`、`pt-PT`、`id`、`ms`、`vi`、`th`、`el`、`hr`
- 語言切換：v1.1 起改為 **App 內建切換器**（`Services/AppLanguageManager.swift`，
  獨立於系統設定，SettingsView 內 Picker 選擇即時生效不需重開 App）。並非早期
  v1.0 規劃的「導向系統 iOS Settings」做法——採「四段式解法」（行程級
  `AppleLanguages` override／`.environment(\.locale)`／`localized(_:)` 手動查表／
  `UserDefaults` 持久化）同時涵蓋 SwiftUI 內容與 navigationTitle/tabItem 等系統
  層文字
- 空字串問題根治：改用 `Text(verbatim: "")` 避免產生空 key

---

## SPM 依賴

| 套件 | 來源 | 用途 |
|------|-----|------|
| `DiveKit` | local path `../../_JD2-family/DiveKit`（家族共用，policy `.full`） | 減壓演算法核心（Buhlmann/DiveEngine/DecoCalculator 等），現行版本見 `_JD2-family/F-02-COMPAT_MATRIX.md` |
| `DiveKitUI` | 同上 local path | 共用 UI 元件（`DiveProfileChartView`／`DiveStatCell` 等剖面圖/統計格） |
| `DiveImportKit` | local path `../../_JD2-family/DiveImportKit`（家族共用） | 全部 15 種格式解析器＋去重邏輯，本 repo 僅保留 `DiveImportKitAdapter.swift` 作為唯一 import 進入點 |
| `FitFileParser` | https://github.com/roznet/FitFileParser | Garmin FIT 二進位格式解析（DiveImportKit 內部依賴） |
| `GoogleMobileAds` | https://github.com/googleads/swift-package-manager-google-mobile-ads | AdMob SDK |
| `GoogleUserMessagingPlatform` | https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git | AdMob 同意框架（UMP，目前已引入但程式碼未實際使用） |

---

## 與 DiveKit／DiveImportKit／家族的關係

本專案是 JD2 家族三個 App 之一。共用演算法核心與匯入解析器的事實來源分別是
`_JD2-family/DiveKit`／`_JD2-family/DiveImportKit`（ultra／immersion 亦引用，
見 `_JD2-family/F-02-COMPAT_MATRIX.md`）。

- **F5（2026-07-18）已完成**：`JD2Core/Algorithm/` 的本地 fork 整包刪除，改為
  `import DiveKit` 外部引用；`JD2Core/State/` 資料夾移除，三個型別上收進
  DiveKit 本體。本 repo 目前**無任何演算法拷貝**。
- **F6（2026-07-19）已完成**：全部 15 種格式解析器搬遷至 `DiveImportKit`，本
  repo 僅留 `JD2Core/Importers/DiveImportKitAdapter.swift` 作為唯一 import
  進入點。
- 發現演算法或解析器問題一律回對應 Kit 修（單一戰場，見 `../CLAUDE.md` 家族
  鐵律 3），不得在本 repo 繞道本地修改。

---

## 重要慣例

- **勿手動腳本編輯 `project.pbxproj`**（曾破壞檔案）
- 專案使用 `fileSystemSynchronizedGroups`：新增/刪除 `.swift` 檔自動進出 build
- `git index.lock` 殘留時：`rm -f .git/index.lock .git/HEAD.lock`（需在 Mac 端執行）
- 雙平台改動需明確標註 `#if os(iOS)` / `#if os(macOS)`
