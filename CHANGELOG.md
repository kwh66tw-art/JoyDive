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

### 2026-07-17 — v1.1 backlog 完工（6/7 項，widget 決定不做）

**功能**：
- #6/#7 `importExtrasJSON` 欄位：buddy / 裝置序號 / 韌體不再塞進 notes 文字，改結構化存儲；Detail 頁新增可折疊「原始資料」區塊
- #8 `avgDepth` 欄位：來源值優先，無則以剖面樣本梯形近似重建
- #14 Export/Import 備份：`DiveLogDatabase.exportAsJSON/importFromJSON` 從拋錯 stub 改為真正可用，Settings 頁新增入口
- #4/#5 移植 Ultra `DiveKit`：取代本地死碼 `Buhlmann.swift`/`DiveEngine.swift`/`AlgorithmConstants.swift`（9 項已知安全問題）；新增互動剖面圖（拖曳查看深度/水溫/ceiling/NDL，放開後保留選取）＋組織艙飽和度長條圖（預設收合，互動後才顯示）
- #12 Garmin Connect JSON 解析器（FIT 的替代匯入路線）
- #13 解析器測試覆蓋率：`DiveLogImporter.swift` 82.2% → 89.1%
- #9/#10 iOS 18 Widget：PM 確認不需要，終止規劃

**技術債（順手修復，與今日改動無關的舊問題）**：
- `project.pbxproj` 測試 target `TEST_HOST` 殘留改名前的 `JD2-Logbook.app`（應為 `JoyDive².app`），導致 `xcodebuild test` 完全無法建置
- 9 個測試檔案的 `@testable import JD2_Logbook` 未隨模組改名同步（實際模組為 `JoyDive_`）

**架構重點**：互動剖面圖與組織艙圖的選取狀態統一由 `DiveAnalysisView` 管理（非各自為政），重放引擎改為直接驅動 `Buhlmann` + 樣本間 ≤10s 線性內插（比對 JD2-Ultra companion `DiveReplay.swift` 對齊，取代原本用 `DiveEngine.tick()` 逐樣本呼叫、樣本間隔大時深度會瞬間跳變的失真做法）。

**待決策**（下次上架前）：macOS `Info.plist` 的 `LSApplicationCategoryType = public.app-category.sports-games` 會觸發系統誤判為遊戲、自動開啟 macOS 遊戲模式（`gamepolicyd` 只檢查分類值是否以 `games` 結尾）；需決定改為 `public.app-category.sports` 或 `public.app-category.healthcare-fitness`，同時要對齊 App Store Connect 的上架分類。

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
