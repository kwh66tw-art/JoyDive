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

### 2026-07-17 — Import 格式清單重新規劃 + 剖面資訊列比照 Ultra companion

**Import tab「Supported Formats」**：格式數擴充到 16 種後，原本無分類的 2 欄
卡片格線難以掃視，改為依品牌/來源分 4 組（Universal / Suunto / Garmin /
Other Brands）＋單欄列表列。列的視覺語彙 port 自 JD2-Ultra companion
`DiveComponents.swift` 的 `SectionHeader`／`ValueRow` 慣例（圖示＋標題置左、
次要資訊置右，grouped 卡片背景＋列間 Divider），對齊 iOS 原生
`List(.insetGrouped)` 視覺語言，而非沿用舊版無來源依據的卡片格線設計。

**Dive Profile 互動剖面圖／組織艙負荷資訊列**：原本的圖示膠囊列（icon+text
pill）改為與 JD2-Ultra companion `DiveAnalysisView.calloutRow` 完全一致的
五欄等寬排版（Time / Depth / Temp / Ceiling / No Deco，label 在上、數值在
下）；新增「安全語意數值才用填色膠囊強調」規則——一般狀態為純深色文字，
只有真的減壓中（紅底白字）或免減壓時間逼近 10 分鐘（黃底黑字）時膠囊才
亮起，其餘與 Ultra 邏輯（`PlanModel.ndlText`：99+ / 分鐘）一致。

新增 4 個 xcstrings 翻譯 key（"Temp"／"No Deco"／"Universal"／"Other Brands"），
18 種語言全數補齊，優先沿用 Ultra 既有翻譯值。

### 2026-07-17 — 匯入格式全面擴充（10 個新解析器，8 個確認無法安全實作）

PM 指示全面查證 `/file_format_research` 盤點的 18 種潛水電腦/軟體格式，不接受
「叫使用者自己轉檔」的退讓方案。逐一重新驗證研究文件的假設（多處與真實樣本
不符，例如 Suunto SDE 內部其實是舊版 DM3 格式而非 DM5、DAN DL7 的 ZDT 記錄
語意與初版猜測相反），並在可能時搜尋開源參考實作交叉驗證byte-level正確性。

**新增 10 個格式解析器**：
- `SuuntoDM5XMLParser`：Suunto DM4/DM5 WCF XML（D4i 等錶款直傳），真實樣本逐欄位驗證
- `SHEARWATERParser`：從空 stub 改為真實實作，同時修正原本用預設 canHandle 誤攔截所有 `.xml`（含 D4i 檔）的根因 bug
- `SuuntoSMLParser`：Moveslink XML，含 Kelvin 水溫轉換
- `DANDL7Parser`：業界標準交換格式，欄位對照依開源 PyDL7 校正（研究文件誤判 ZDT 為逐樣本剖面，實為 dive trailer）
- `DivesoftDLFParser`：二進位格式，欄位偏移依開源 divesoft-parser 逐位元核對，並用真實樣本 3 個獨立欄位（start_time/max_depth/min_temperature）精確驗證吻合；v2 header（"DiVE" magic）明確拒絕而非臆測
- `SuuntoSDEParser`：ZIP 包裝的舊版 DM3 XML（非原研究猜測的 DM5 格式），歐式逗號小數處理
- `ReefnetSensusParser`：CSV，壓力→深度公式依 ReefNet 官方換算說明驗證；水溫欄位因無法可靠確認編碼，刻意不猜測轉換
- `DivingLogSQLiteParser`：原生 SQLite3（無需第三方套件），RTF 備註欄位手寫剝除器（避免引入 UIKit 依賴破壞 JD2Core 跨平台界線）
- `GarminConnectJSONParser`、`DeepbluCOSMIQParser`：格式假設（無公開 API 文件），待真實樣本驗證

**新增 `MinimalZipReader.swift`**：純 Swift 跨平台 ZIP 讀取器（PKWARE 公開規格，
支援 stored/deflate），取代原本只在 macOS 用 `/usr/bin/unzip` 的做法，順便修正
UDDF 的 ZIP 包裝格式在 iOS 原本完全無法匯入的既有缺口。

**確認 8 個格式目前無法安全實作**（Scubapro LogTRAK、Mares Dive Organizer、
Heinrichs Weikamp OSTC、Cressi PC Interface、Ratio iDive、Cochran CAN、
Aqualung i-Trak、APD LogViewer）：逐一檢查後證實為 Microsoft Access/SQL Server
Compact 等專有二進位資料庫無公開規格、或研究樣本僅為文字佔位符（無真實資料
可驗證），非偷懶跳過。具體理由見 `file_format_research/format_inventory.md`。

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
