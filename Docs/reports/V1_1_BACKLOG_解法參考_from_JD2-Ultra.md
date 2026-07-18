# V1_1_BACKLOG 解法參考（from JD2-Ultra，2026-07-04；2026-07-13 補充）

> **性質**：JD2-Ultra 專案在規劃 companion（M18）時，逐項評估了本專案 `V1_1_BACKLOG.md` 的問題並已有實作方案。
> 依 PM 決策（2026-07-04）：**兩專案分開發展，JD2-Ultra 不修改本專案程式碼**——本文件僅提供解法參考，
> 是否採用、何時採用由 JD2-Logbook 自行決定。
> 參考實作全部在 `/Users/kevin/Documents/AppProject/JD2-ultra/`（下稱 Ultra）。
> ⚠️ 原標記「單向參考交付、不再同步更新」——2026-07-13 PM 指示追加一次補充（見文末新增章節），
> 反映 companion 上線後（0.2.9→0.2.11）發現的、與本專案原始程式碼有關的問題與後續已驗證的解法。

---

## ⚠️ 最重要：`BuhlmannCalculator` 請勿直接啟用（backlog #5 前置警告）

本專案預留的 `BuhlmannCalculator` **從未驗證過，內容可能不正確**（PM 2026-07-04 確認）。
而且其基底 JD2Core 有**已知的安全級問題清單**（postDive 卡死、40m ceiling 歸零、高度切換洗掉殘氮等
8 項）——完整清單與修法見 Ultra `JD2-ultra_決策.md` §4.2「JD2Core 需同步修正清單」。

**建議**：做組織艙功能（backlog #5）時，不要修 `BuhlmannCalculator`，直接以 **Ultra 的 `DiveKit`**
（`Ultra/DiveKit/`，SPM 套件）為準——它是同一套 JD2Core 的後代，但已經過：
- 四輪全碼稽核（0.1.1 27 項／0.2.2 7 項／0.2.4 4 項／0.2.8 3 項，含兩次外部稽核）全數修復
- 88 個單元測試（Bühlmann 對標值、狀態機、持久化、真實潛水紀錄端到端重放）
- 10 筆真實潛水電腦紀錄（多廠牌匯出）逐 tick 重放驗證

取用方式二選一：整包複製 `DiveKit/Sources/DiveKit/`（無 UI 純 Swift，iOS/macOS/watchOS 皆可編），
或依 §4.2 清單逐項回修既有 JD2Core。**日誌重放**（backlog #4/#5 需要的）參考
`Ultra/DiveKit/Tests/DiveKitTests/RealDiveSimulationTests.swift`——把 `profileSamples` 逐點餵
`DiveEngine.tick(depth:now:)` 即得逐點 ceiling/NDL/16 隔室張力，不需另寫演算法。

---

## 技術債解法

### 債 1：3 個 xcstrings 鍵補翻
Ultra 慣例＝Python 直接編修 `Localizable.xcstrings` JSON（批次加 `localizations` 節點），
再跑簡體字掃描自查。參考腳本模式：Ultra CHANGELOG 0.2.5–0.2.6 各批次（每批 5–16 鍵三語，零手誤）。
繁中範本沿用 backlog 內建（未記錄/氣溫：未記錄/能見度：未記錄）。

### 債 2：殭屍鍵清除
同上工具路徑：`del strings["JD2 Logbook"]` 後回寫；刪除前先 `grep -r` 全 Swift 確認零引用
（Ultra 在 0.2.5 清了 10+ 孤兒鍵，皆先驗證再刪）。

### 債 3：Restore 錯誤無回饋
Ultra `PurchaseManager.swift`（`Ultra/JD2UltraApp/Purchase/`）同場景寫法：restore 走
`do { try await AppStore.sync() } catch { lastError = error }`，UI 以 `@Observable` 曝露
`lastError` → alert。重點是**不要 `try?`**——與 SettingsView 主視圖行為一致即可。

---

## 功能擴充解法

### #4 互動式剖面圖＋ #5 組織艙飽和度（同 sprint，backlog 備註正確）
- 演算法：見上方警告——用 DiveKit 重放，**不要**修 BuhlmannCalculator。
- 剖面樣本擴充 `{t,d}` → `{t,d,temp}`：additive 短鍵（Ultra 用 `t`/`d`，建議水溫鍵 `w`），
  舊資料解碼 `temp` 為 nil 優雅降級——Ultra 的 `DiveProfileSample`（`JD2UltraApp/Data/DiveLogEntry.swift`）
  即此模式（Codable 短鍵＋optional additive）。
- 互動點查：SwiftUI `Chart`＋`chartOverlay` drag gesture 取最近樣本；ceiling/NDL 值由重放結果陣列查表。

### #6/#7/#8 importExtrasJSON／裝置序號／avgDepth
- SwiftData **additive 欄位＋預設值免手動 migration**：`var importExtrasJSON: String = "{}"`、
  `var avgDepth: Double = 0`（Ultra 實測多次 additive 遷移零事故：`warningEvents`/`recovered`/
  `lastWaterActivityAt` 等，見 Ultra CHANGELOG 0.2.6–0.2.8）。
- avgDepth 計算：時間加權積分 ∫depth·dt／時長；**注意結束 tick 的邊界**——Ultra 曾有「最後一秒
  深度未入積分但時長已計」的低估 bug（外部稽核 G4），修法見 `DiveLogRecorder.freeTick` 結算前補積分。
- 匯入器無剖面只有摘要時：avgDepth 以樣本梯形近似重建（參考 `DiveLogRecorder.saveRecoveredEntry`）。

### #9/#10 Control Center／Lock Screen widget
Ultra watch complication 同構：**App Group 快照檔＋WidgetKit TimelineProvider**（30 分 entry×24＋
`TimelineEntryRelevance`），關鍵教訓：**App 存檔後必須呼叫 `WidgetCenter.reloadAllTimelines()`**——
Ultra 曾漏接導致 widget 資料永遠過期（0.2.8 修）。參考 `Ultra/JD2UltraWidgets/Widgets.swift`。

### #11 地圖 recenter
`MapCameraPosition` state＋右下角圓鈕 `position = .userLocation(fallback:)`；記得
`CLLocationManager` 授權態變化時鈕的 enable/disable。

### #12 Garmin Connect JSON
建議實作時同步驗證 Ultra `_TestData` 的 5 個 .fit 對應樣本（兩專案共享測試資產價值）。

### #13 解析器覆蓋率
`swift test --enable-code-coverage` ＋ `xcrun llvm-cov report`；Ultra 的匯入驗證模式＝
真實裝置匯出檔全檔重放斷言不變量（不只 happy path），見 `RealDiveSimulationTests`。

---

## 附：listview 素列作法（PM 2026-07-04 於 Ultra companion 已定案的樣式，供本專案參考）

iOS 潛水列表改 Apple 原生素列（無卡片外框、系統分隔線）。作法（已在本專案程式碼上驗證可編譯，
iOS＋macOS build 皆過後回退——依分開發展原則未保留）：
1. `DiveRowView`：移除 `.padding(12)`＋`.background(...)`＋`.clipShape(RoundedRectangle(14))`＋
   `.strokeBorder` overlay，改 `.padding(.vertical, 6)`。
   ⚠️ **macOS 需保留卡片樣式**（選取框畫在卡片邊框上，是 ScrollView+LazyVStack 選取方案的載體）——
   用 `ViewModifier` 平台分流（`#if os(macOS)` 保留原樣，iOS 素列）。
2. 兩處 iOS `List` 呼叫端（`DiveLogListView`、`DiveCalendarView`）：移除
   `.listRowInsets(...)`＋`.listRowSeparator(.hidden)`（恢復系統分隔線與預設 inset）；
   flash 高亮的 `.listRowBackground` 保留。

---

## 追加章節（2026-07-13）：companion 上線後發現與本專案原始碼有關的問題

以下是 companion（M18-3 移植本專案 UI 後）上線至今（0.2.9→0.2.11）跑過幾輪稽核才浮現、
**根源在本專案原始程式碼、而非移植過程新引入**的問題，或原提案已在生產環境跑滿驗證、
狀態值得更新的項目。

### ⚠️ 提醒：本專案 UI 檔案目前「零單位換算」，未來若加英制選項會踩到同一批地雷

companion 稽核（2026-07-05）發現：M18-3 移植進來的本專案原始 UI 檔案，深度/氣瓶壓力/配重/
能見度/水溫等數值**全部直接印出公制原始值，完全沒有呼叫任何單位換算函式**——這不是本專案
現有的 bug（本專案目前沒有英制選項，所以不算功能缺陷），但**如果日後本專案要加公英制切換，
以下檔案會全部需要逐一補上換算呼叫，不會自動繼承任何全域設定**：

- `DiveLogDetailView`、`DiveLogEditSheet`（含輸入框雙向換算）
- `DiveRowView`、`DiveLogListView`（Deepest 統計）
- `DiveProfileChartView`（Y 軸標籤）
- `DiveAnalysisView`（拖曳資訊列）
- `DiveSiteSheetView`／`DiveMapRepresentable`／`DiveSiteAnnotation`（地圖 pin 副標題）

Ultra 這邊的修法：`SettingsStore` 集中提供 `formatDepth`/`formatTemperature`/`formatPressure`/
`formatWeight`/`formatAltitude` 等函式，上述每個顯示點與輸入框改呼叫對應函式（輸入框用
`convertedBinding` 包一層，內部 `@State` 恆存公制、`save()` 邏輯不變）。若本專案之後真的要做
英制選項，可直接參考這個「集中換算函式＋轉換 binding」模式，不需重新設計。

### #12 Garmin Connect JSON 解法已完整實作（仍待真實樣本驗證）

`GarminConnectJSONParser`（`Ultra/JD2UltraPhone/Import/GarminConnectJSONParser.swift`）已完成、
以內容特徵偵測避免誤吞 Suunto JSON。**格式仍是假設實作**——當初沒有真實 Garmin Connect 匯出檔
可對照，欄位對應是照文件推測的，**PM 尚未提供真實匯出樣本回驗**。本專案如果要採用，建議先拿到
一份真實匯出檔一起驗證，而不是直接信任目前的欄位對應。

### avgDepth 梯形重建方案：已離開提案階段，生產環境驗證通過

原文件 #6/#7/#8 章節提到的「匯入器無剖面只有摘要時，avgDepth 以樣本梯形近似重建」與「結束
tick 的邊界積分」兩個方案，在 Ultra 這邊已經不是紙上方案——已隨 M18 全數上線並跑滿 DiveKit
88/88＋phone 24/24 測試（含真實潛水紀錄端到端重放），可視為驗證過的參考實作，非未試想法。

### Widget／Live Activity 基礎設施：已擴充至完整生命週期（原 #9/#10 的下一步）

原文件提到的「App Group 快照檔＋WidgetKit TimelineProvider＋`WidgetCenter.reloadAllTimelines()`」
模式，Ultra 這邊後續擴充到 iOS Lock Screen widget＋Dynamic Island／Live Activity
（`JD2UltraPhoneWidgets`），模擬器 E2E 已驗證（禁飛倒數即時顯示、前景續期）。若本專案之後也要做
#9/#10，這裡有更完整的參考範本可以看，而不是只有 watch complication 那一版。⚠️ Live Activity
真機推播/前景續期完整生命週期仍待 Ultra 自己真機驗證，此部分本專案採用前建議先觀望 Ultra 真機
驗收結果。

### 债 3（Restore 失敗無回饋）：解法已確認可用

原文件建議的 `do/catch` 寫法（不吞錯誤、`@Observable` 曝露 `lastError` 給 alert）已在 companion
上線並跑過稽核，沒有再被回報問題，可視為驗證過的參考寫法。

---
*來源：JD2-Ultra M18 companion 規劃 v1.1（`JD2-ultra/JD2-ultra_M18_companion規劃_v1.1.md`）＋
companion 上線後稽核（CHANGELOG「稽核5」「稽核5 續」章節，2026-07-05／06）。
本文件為單向參考交付，是否有進一步更新視 PM 是否再次指示；問題請對照 Ultra 對應版本
（v0.2.8 為 2026-07-04 版本基準、v0.2.10 為 2026-07-13 補充章節基準，皆為 git tag／commit 可查）。*
