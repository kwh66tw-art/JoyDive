# JD2-Logbook

潛水日誌 App，支援 iOS 17+ 與 macOS 14+，採用 SwiftUI + SwiftData 開發。

## 功能摘要

- **日誌管理**：新增、編輯、刪除潛水記錄，含深度剖面、氣體混合、環境資料
- **多格式匯入**：支援 15 種格式（UDDF、Subsurface XML/SSRF、Subsurface CSV、Suunto JSON/DM5/SML/SDE、Garmin FIT（via FitFileParser）/Connect JSON、Shearwater、Seabear CSV、Oceanic、DAN DL7、Divesoft DLF、Reefnet Sensus、Diving Log 6.0），全部解析器現由家族共用套件 `DiveImportKit` 提供
- **GPS 地圖**：CoreLocation 記錄潛點座標，MapKit 地圖顯示與聚類
- **多語系**：18 種語言（繁中、簡中、英文、日文、韓文、法文、德文、西班牙文、義大利文、荷蘭文、葡萄牙文、印尼文、馬來文、越南文、泰文、希臘文、克羅埃西亞文、英國英文）
- **廣告 & Premium**：AdMob Banner 廣告，StoreKit IAP $1.99 移除廣告
- **雙平台**：iOS/iPadOS TabView + macOS NavigationSplitView 共用大部分 View

---

## 環境需求

| 項目 | 需求 |
|------|------|
| Xcode | 16.0+ |
| iOS 部署目標 | 17.0 |
| macOS 部署目標 | 14.0 |
| Swift | 6.0 |
| SPM 依賴 | DiveKit／DiveKitUI／DiveImportKit（家族共用 local path）、FitFileParser、GoogleMobileAds、GoogleUserMessagingPlatform |

---

## 如何編譯

1. 開啟 `JD2-Logbook/JD2-Logbook.xcodeproj`
2. 等待 Xcode 解析 SPM 依賴（DiveKit/DiveKitUI/DiveImportKit 為 local path，指向
   `../../_JD2-family/`，需確認該目錄存在；另外 FitFileParser、GoogleMobileAds、
   GoogleUserMessagingPlatform 為遠端套件）
3. 選擇 target `JD2-Logbook`，選擇模擬器或真機
4. `⌘R` 執行

> ⚠️ 首次執行若模擬器有舊資料（schema 含 `buddy` 欄位），需 Erase All Content and Settings。

---

## 專案結構

```
JD2-Logbook/                        ← 本 repo 根目錄
├── JD2-Logbook/                    ← Xcode 專案資料夾
│   ├── JD2-Logbook.xcodeproj
│   ├── JD2-Logbook/                ← App target（SwiftUI Views、Services）
│   │   ├── Views/
│   │   │   ├── Logbook/            ← 日誌列表、詳情、編輯
│   │   │   ├── Map/                ← MapKit 地圖
│   │   │   ├── Import/             ← 匯入精靈
│   │   │   ├── Settings/           ← 設定、IAP
│   │   │   └── Shared/             ← 共用元件（AdBannerView、Color 擴展等）
│   │   ├── Services/
│   │   │   └── PurchaseManager.swift
│   │   ├── Localizable.xcstrings   ← 18 種語言本地化
│   │   └── JD2_LogbookApp.swift    ← App 進入點
│   ├── JD2Core/                    ← 核心業務邏輯（Adapter、模型；解析器/演算法本體已遷至家族 Kit）
│   │   ├── Models/                 ← DiveLog、GasMix、DiveEnvironment（SwiftData）
│   │   ├── Importers/              ← DiveImportKitAdapter（唯一 import 進入點）+ ImportCoordinator
│   │   ├── Algorithm/              ← 僅 DiveReplayEngine.swift（演算法本體改用外部 DiveKit）
│   │   └── Utilities/
│   ├── JD2-LogbookTests/           ← XCTest 解析器單元測試
│   └── JD2-LogbookUITests/         ← UI 測試
├── docs/                           ← 技術維護文件（含 reports/ 事件報告、handoff-archive/）
├── Archive/                        ← 開發過渡性文件（HANDOFF、計劃文件等）
├── logbook/                        ← 隱私政策（privacy.md，GitHub Pages 線上版唯一來源）
├── README.md                       ← 本文件
├── ARCHITECTURE.md                 ← 架構設計說明
├── CHANGELOG.md                    ← 版本異動紀錄
├── P0-00-文件登錄表_v1.10.md        ← 全專案文件唯一索引
├── V1_RELEASE_CHECKLIST.md         ← 上線前驗證清單
├── UI_UX_SPEC.md                   ← UI/UX 規格
├── WCAG_2.1_AA_AUDIT_CHECKLIST.md  ← WCAG 2.1 AA 合規清單
└── CLAUDE.md                       ← Claude agent 工作指引
```

> 測試樣本原本放在本 repo 的 `TestFiles/`，已於 2026-07-18 集中搬遷至家族共用
> 目錄 `_JD2-family/dive-log-samples/`（供 ultra 等其他專案重用），本 repo 已
> 無此資料夾。

---

## 相關文件

- [ARCHITECTURE.md](ARCHITECTURE.md) — 架構設計與模組說明
- [CHANGELOG.md](CHANGELOG.md) — 版本紀錄
- [V1_RELEASE_CHECKLIST.md](V1_RELEASE_CHECKLIST.md) — 上線前驗證清單
- [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) — 已知問題與 v1.1 規劃
- [docs/ADMOB_IAP_SETUP.md](docs/ADMOB_IAP_SETUP.md) — 廣告與 IAP 設定紀錄
- [WCAG_2.1_AA_AUDIT_CHECKLIST.md](WCAG_2.1_AA_AUDIT_CHECKLIST.md) — 可達性合規

---

**目標上線**：2026 年 8 月 18 日
