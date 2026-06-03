# Changelog

All notable changes to JD2-Logbook will be documented in this file.

Format: `[vX.Y.Z] — YYYY-MM-DD`

---

## [v1.0.0] — 2026-08-18 (目標)

### Added
- 潛水日誌 CRUD（新增、編輯、刪除、列表、詳情）
- 日曆視圖（DiveCalendarView）
- 多格式匯入：UDDF / Subsurface XML / Subsurface CSV / Suunto JSON / Garmin FIT / Shearwater / Seabear CSV / Oceanic
- ImportCoordinator 自動格式偵測與批量匯入
- GPS 座標記錄 + MapKit 地圖顯示（潛點聚類）
- AdMob Banner 廣告（Logbook / Import / Settings / Map 空狀態）
- StoreKit IAP「Remove Ads $1.99」
- 18 種語言本地化（繁中、簡中、英文、日文、韓文、法文、德文、西班牙文、義大利文、荷蘭文、葡萄牙文、印尼文、馬來文、越南文、泰文、希臘文、克羅埃西亞文、英國英文）
- iOS + macOS 雙平台支援
- Bühlmann ZHL-16C 減壓演算法
- WCAG 2.1 AA 可達性合規

### Technical
- SwiftUI + SwiftData，iOS 17+ / macOS 14+
- Swift 6 strict concurrency
- GoogleMobileAds SDK v11 接入
- FitFileParser SPM 套件（Garmin FIT 解析）

---

## [開發階段紀錄]

### 2026-06-03 — AdMob 正式接入（commit 656a246）
- 接入 GoogleMobileAds SDK v11
- 更新 4 個正式 Ad Unit ID
- 修正 SDK v11 API 改名（BannerView / AdSizeBanner / Request）
- 修正 PremiumAwareAdBanner 高度約束問題

### 2026-06-02 — 死碼清理 + 部署目標統一（commit deda6ca / 56dc1a3）
- 刪除 ContentView、placeholder views 等死碼
- SwiftData schema 移除 `buddy` 欄位
- 修正 macOS DiveLogEditSheet O₂ 重複顯示 bug
- 統一部署目標 iOS 17.0 / macOS 14.0
- 新增 .gitignore

### 2026-05-xx — i18n 實裝（commit 84b7b47 / 682087c）
- 匯入 V7.2 多語系校訂版
- 中文用詞統一（繁中 / 簡中 區分）
- 修正 navigationTitle("") 空字串 key 問題

### 2026-05-17 — 專案初始化
- Xcode 專案建立，SwiftData 初始化
- JD2Core 模組架構確立
