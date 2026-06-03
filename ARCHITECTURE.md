# JD2-Logbook 架構設計

**最後更新**：2026-06-03

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
│  ┌─────────┐ ┌──────────┐ ┌──────────┐ │
│  │ Models  │ │Importers │ │Algorithm │ │
│  │SwiftData│ │Parsers   │ │Bühlmann  │ │
│  └─────────┘ └──────────┘ └──────────┘ │
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
| `DiveLogDatabase.swift` | ModelContainer 單例，`DiveLogDatabase.shared.modelContainer` 提供全 App 存取。 |
| `GasMix.swift` | 氣體混合（空氣、EAN、Trimix、純氧），含 O₂ / He / N₂ 百分比。 |
| `DiveEnvironment.swift` | 潛水環境枚舉（海水、淡水、高鹽）。 |

### JD2Core/Importers

#### DiveLogImporter Protocol

所有解析器遵循統一 protocol：

```swift
protocol DiveLogImporter {
    static var supportedExtensions: [String] { get }
    func canImport(fileURL: URL) -> Bool
    func importDives(from fileURL: URL) throws -> [DiveLog]
}
```

#### 支援格式一覽

| 解析器 | 支援格式 | 副檔名 | 備註 |
|--------|---------|--------|------|
| `UDDFParser` | UDDF | `.uddf` | XML，多品牌通用 |
| `SubsurfaceXMLParser` | Subsurface XML | `.ssrf`, `.xml` | 涵蓋 Suunto / Shearwater / Cressi / Mares / Garmin |
| `SubsurfaceCSVParser` | Subsurface CSV | `.csv` | RFC 4180，支援多行 notes、引號轉義 |
| `SuuntoJSONParser` | Suunto JSON | `.json` | DeviceLog → DiveLog 映射 |
| `GarminDescentParser` | Garmin FIT（二進位） | `.fit` | via `FitFileParser` SPM 套件 |
| `ShearwaterParser` | Shearwater | `.xml` | XML 格式 |
| `SeabearCSVParser` | Seabear CSV | `.csv` | 格式偵測與 SubsurfaceCSV 區分 |
| `OceanicParser` | Oceanic | `.xml` | OCF+XML 混合 |

#### ImportCoordinator

自動偵測格式、分派至對應解析器，提供統一批量匯入介面：

```swift
ImportCoordinator.shared.importFiles([URL]) async throws -> ImportResult
```

### JD2Core/Algorithm

- `Bühlmann.swift` — Bühlmann ZHL-16C 減壓演算法（計算組織飽和度、NDL）
- `DiveEngine.swift` — 演算法驅動層，接受 DiveProfileSample 陣列輸入

### Services

- `PurchaseManager.swift` — StoreKit 2 IAP 管理，`@Observable`，提供 `isPremium` 狀態給全 App

---

## SwiftData Schema

目前版本（v1.0）欄位：

```
DiveLog
├── id: UUID
├── dateTime: Date
├── duration: TimeInterval        (秒)
├── maxDepth: Double              (公尺)
├── avgDepth: Double?
├── waterTemperature: Double?     (攝氏)
├── airTemperature: Double?
├── location: String?
├── latitude: Double?
├── longitude: Double?
├── gasMix: GasMix               (embedded)
├── diveEnvironment: DiveEnvironment
├── notes: String?
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
├── Tab 2: ImportWizardView (3 步驟精靈)
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

---

## 重要慣例

- **勿手動腳本編輯 `project.pbxproj`**（曾破壞檔案）
- 專案使用 `fileSystemSynchronizedGroups`：新增/刪除 `.swift` 檔自動進出 build
- `git index.lock` 殘留時：`rm -f .git/index.lock .git/HEAD.lock`（需在 Mac 端執行）
- 雙平台改動需明確標註 `#if os(iOS)` / `#if os(macOS)`
