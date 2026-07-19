# JD2-Logbook 架構設計

**最後更新**：2026-07-18（反映 v1.1：JD2Core 整包替換、State/ 新資料夾、10 個新格式解析器、ImportCoordinator/MinimalZipReader）

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
│ ┌────────┐┌─────────┐┌────────┐┌───────┐│
│ │ Models ││Importers││Algorithm││ State ││
│ │SwiftData││Parsers ││(部分死碼)││(快照) ││
│ └────────┘└─────────┘└────────┘└───────┘│
│              Utilities                   │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│           SwiftData / SQLite            │
└─────────────────────────────────────────┘
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

### JD2Core/State（v1.1 新增資料夾）

| 檔案 | 說明 |
|------|------|
| `DiveComputerState.swift` | 潛水電腦運算狀態快照（與 DiveKit 同源檔，見下方「與 DiveKit 的關係」）。 |
| `SurfaceStatus.swift` | 水面狀態（禁飛、系列潛水）快照。 |
| `LogSummary.swift` | 日誌摘要持久化。 |

> 這三個檔案是 DiveKit 演算法核心的資料模型層，隨 Algorithm/ 一併凍結（見下）。

### JD2Core/Importers（v1.1 大幅擴充：新增 10 個格式解析器）

#### DiveLogImporter Protocol

```swift
protocol DiveLogImporter {
    static var supportedExtensions: [String] { get }
    func canImport(fileURL: URL) -> Bool
    func importDives(from fileURL: URL) throws -> [DiveLog]
}
```

#### 格式支援現況（`DiveLogFormat` enum，22 格式宣告）

**舊架構遺留**——9 個解析器以 struct 內嵌在單一巨檔 `DiveLogImporter.swift`（2,482 行）：
UDDF、Peregrine、Subsurface CSV、Garmin FIT（Descent）、Garmin Connect JSON、Subsurface XML、
Suunto JSON、Oceanic、Seabear CSV。

**v1.1 新增**——9 個解析器獨立成檔（`file_format_research` 18 格式盤點的產出）：

| 解析器 | 格式 | 副檔名 | 備註 |
|---|---|---|---|
| `SuuntoDM5XMLParser` | Suunto DM5 | `.xml` | DM4/DM5 桌面軟體、D4i 錶款匯出 WCF XML |
| `SuuntoSMLParser` | Suunto SML | `.xml` | Moveslink/Moveslink2 快取 |
| `SuuntoSDEParser` | Suunto SDE | `.zip` 內含 | DM5 加密備份包，需 `MinimalZipReader` 解壓 |
| `DANDL7Parser` | DAN DL7 | 純文字 | Divers Alert Network 管線分隔格式 |
| `DivesoftDLFParser` | Divesoft DLF | 二進位 | Freedom/Liberty 專有格式 |
| `ReefnetSensusParser` | Reefnet Sensus | `.csv`/`.dat` | Sensus 採樣格式 |
| `DivingLogSQLiteParser` | Diving Log 6.0 | `.sql`/`.sqlite`/`.db` | 實際為 SQLite 資料庫 |
| `ShearwaterXMLParser` | Shearwater | `.xml` | 取代舊版內嵌解析器 |

**已宣告未實作**（`DiveLogFormat` 有 case、副檔名、優先權，但無對應 parser struct）：
Scubapro（LogTRAK）、Mares（Dive Organizer）、HW OSTC、Cressi（PC Interface）——
研究樣本在 `_JD2-family/dive-log-samples/_未實作格式研究樣本/`，供未來實作參考。

#### 支援工具（v1.1 新增）

| 檔案 | 說明 |
|---|---|
| `MinimalZipReader.swift` | 純 Swift 跨平台 ZIP 讀取器（僅讀單一具名條目）。取代原本 UDDF 靠 `Process` 呼叫系統 `unzip` 的作法——iOS 沙盒無法執行任意可執行檔，此為 iOS 平台的關鍵缺口修復，Suunto SDE 亦共用此能力。 |
| `ImportCoordinator.swift` | 統一匯入流程協調器：檔案驗證、格式自動偵測、解析、資料庫儲存的完整流程；批次匯入的去重邏輯所在（SYNC #2 已修復同批次互相漏檢問題）。 |

#### 測試樣本統一管理（2026-07-18）

原本分散在本 repo 的 `TestFiles/`（測試 fixture）與 `file_format_research/`（格式研究樣本）
已集中至家族共用目錄 `_JD2-family/dive-log-samples/`（供 ultra 等其他專案未來重用），
測試檔的 fixture 路徑已同步更新。詳見 `_JD2-family/F-00-文件登錄表.md`。

### JD2Core/Algorithm ⚠️ 部分死碼，勿修改

```
Buhlmann.swift / DiveEngine.swift / DecoCalculator.swift / DivePlanner.swift /
FreeDive.swift / GuidanceBanner.swift / OxygenToxicity.swift
```

這些檔案與 `AppProject/DiveKit`（家族統一演算法核心）同源，但**目前無任何呼叫端引用，
是休眠死碼**，且對應 Ultra 側稽核已知 **9 項安全級問題尚未修復**（見 `V1_1_BACKLOG.md`
#4/#5）。一旦被 UI 接上會全部從休眠變成活的風險程式碼。

**F5 里程碑**（Logbook v1.1 送審後）會把這整組檔案換成 SPM 引用 `../DiveKit`，
詳見 `_JD2-family/F-01-FAMILY_ROADMAP.md`。**在 F5 之前，這些檔案凍結、不得修改**
（家族決策 `_JD2-family/decisions/2026-07-17_F4-JD2Core評估結論.md`）。

`DiveReplayEngine.swift` 是例外——它是本 repo**現行使用**的日誌回放引擎（匯入後計算
NDL/減壓狀態摘要），語意與即時電腦不同，**不隨 F5 遷移**，繼續留在 JD2Core。

### JD2Core/Utilities

| 檔案 | 說明 |
|---|---|
| `Extensions.swift` | 共用型別擴充。 |
| `MockDataSeeder.swift` | 開發/測試用假資料產生器。 |

### Services

- `PurchaseManager.swift` — StoreKit 2 IAP 管理，`@Observable`，提供 `isPremium` 狀態給全 App

---

## SwiftData Schema

目前版本（v1.1）欄位（節錄；完整定義見 `DiveLog.swift`，v1.1 additive 新增數個欄位＋預設值，
lightweight migration 即足夠，無需額外 migration 指引）：

```
DiveLog
├── id: UUID
├── dateTime: Date
├── duration: TimeInterval        (秒)
├── maxDepth: Double              (公尺)
├── avgDepth: Double?             (v1.1 新增)
├── waterTemperature: Double?     (攝氏)
├── airTemperature: Double?
├── location: String?
├── latitude: Double?
├── longitude: Double?
├── gasMix: GasMix               (embedded)
├── diveEnvironment: DiveEnvironment
├── notes: String?
├── importExtrasJSON: String?     (v1.1 新增：非標準欄位保留，供匯入格式擴充)
├── sourceDevice: String?         (v1.1 新增：裝置欄位)
└── profileSamples: Data?        (JSON 編碼的 [DiveProfileSample])
```

> ⚠️ `buddy` 欄位已於 commit `56dc1a3` 移除（v1.0 schema breaking change）。
> 模擬器如有舊資料需 Erase All Content and Settings。

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
- 語言切換：導向系統 iOS Settings（App Language）
- 空字串問題根治：改用 `Text(verbatim: "")` 避免產生空 key

---

## SPM 依賴

| 套件 | URL | 用途 |
|------|-----|------|
| `FitFileParser` | https://github.com/roznet/FitFileParser | Garmin FIT 二進位格式解析 |
| `GoogleMobileAds` | https://github.com/googleads/swift-package-manager-google-mobile-ads | AdMob SDK v11 |
| `GoogleUserMessagingPlatform` | https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git | AdMob 同意框架（UMP） |

---

## 與 DiveKit／家族的關係

本專案是 JD2 家族三個 App 之一。共用演算法核心事實來源是 `AppProject/DiveKit`
（ultra／immersion 已引用，見 `_JD2-family/F-02-COMPAT_MATRIX.md`）。Logbook 的
`JD2Core/Algorithm/`＋`JD2Core/State/` 是**尚未遷移的凍結 fork**——詳見上方
「JD2Core/Algorithm ⚠️」一節與 `_JD2-family/decisions/2026-07-17_F4-JD2Core評估結論.md`。

---

## 重要慣例

- **勿手動腳本編輯 `project.pbxproj`**（曾破壞檔案）
- 專案使用 `fileSystemSynchronizedGroups`：新增/刪除 `.swift` 檔自動進出 build
- `git index.lock` 殘留時：`rm -f .git/index.lock .git/HEAD.lock`（需在 Mac 端執行）
- 雙平台改動需明確標註 `#if os(iOS)` / `#if os(macOS)`
