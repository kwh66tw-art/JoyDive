# JD2-Logbook 全盤程式碼稽核報告

> **稽核日期**：2026-07-26  
> **稽核範圍**：全部 37 個 Swift 原始碼檔案、Localizable.xcstrings（738KB）、Info.plist  
> **稽核方法**：4 名子代理平行讀取全部原始碼 → 整合分析，**零參考文件**  
> **稽核人**：AI 資深技術架構師

---

## 📊 稽核摘要

| 等級 | 數量 | 說明 |
|:---:|:---:|:---|
| 🚨 風險 | **12** | 可能導致潛水安全隱患、App 崩潰、資料損壞或審核被拒 |
| ⚠️ 建議 | **26** | 效能優化、架構改善或程式碼整潔度 |
| ✅ 通過 | **18** | 邏輯正確，符合標準 |

---

## 🚨 風險項目（必須優先處理）

### R-01：NSAllowsArbitraryLoads = true — ATS 安全漏洞

**檔案**：[Info.plist](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Info.plist)

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <key>NSAllowsArbitraryLoadsForMedia</key>
    <true/>
</dict>
```

此設定**完全關閉 Apple 的 App Transport Security (ATS)**，允許任意未加密的 HTTP 連線。這是極其嚴重的安全隱患，可能導致：
- 網路請求被中間人攻擊（MITM）竊聽
- App Store 審核被拒（Apple 要求 ATS 必須啟用，除非有正當理由）
- 使用者隱私資料洩露

> [!CAUTION]
> 除非有明確的第三方 SDK 要求（如特定的廣告網路），否則**必須移除此設定**。如需例外，應使用 `NSExceptionDomains` 針對特定域名開放，而非全局關閉。

---

### R-02：DiveKit Trimix 氦氣追蹤缺口

**檔案**：[DiveReplayEngine.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Algorithm/DiveReplayEngine.swift)

外部框架 `DiveKit` 的 `Buhlmann` 實作**僅追蹤氮氣**（Compartment 無 `pHe` 欄位），不支援 Trimix 的氦氣代謝。呼叫 `ndlSeconds()` 時會觸發 `assertionFailure`。

**程式碼已有防護**：`DiveReplayEngine.replay()` 偵測到 Trimix 時會走短路路徑，標記 `decoDataUnavailable = true`，僅提供深度/時間/溫度，不計算 NDL/Ceiling。

```swift
// trimix 短路行為：不計算減壓數據，避免 DiveKit 崩潰
replay.decoDataUnavailable = true
```

**風險評估**：短路保護有效，**不會崩潰**。但使用者對 Trimix 潛水的分析功能受限。

> [!IMPORTANT]
> 此為已知限制，PM 已決策 F5 階段繞過。建議在 UI 上向使用者明確提示「Trimix 潛水的減壓分析暫不可用」，避免混淆。

---

### R-03：DiveLogListView deepestDive 單位硬編碼為 "m"

**檔案**：[DiveLogListView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Logbook/DiveLogListView.swift)

統計區的「最深潛水」使用 `String(format: "%.1fm", deepestDive)` **直接硬編碼公制單位**：
- 英制用戶看到的數值未經換算
- 單位永遠顯示 "m" 而非 "ft"

> [!CAUTION]
> 此為**數據顯示錯誤**。英制用戶的 deepestDive 統計數據完全失真。

---

### R-04：DiveLogDatabase.getStatistics() 語義失真

**檔案**：[DiveLogDatabase.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Models/DiveLogDatabase.swift)

```swift
let averageDepth = dives.isEmpty ? 0.0
    : dives.reduce(0) { $0 + $1.maxDepth } / Double(count)
```

此處計算的是**「所有潛水的最大深度之平均」**，但命名為 `averageDepth`（平均深度）。這在語義上是失真的——使用者期望看到的是 `avgDepth`（每次潛水的平均深度之平均），而非 `maxDepth` 的平均。

**建議**：改用 `$1.avgDepth`，或將屬性重新命名為 `averageMaxDepth` 以釐清語義。

---

### R-05：大量 UI 字串未本地化

**嚴重程度**：影響所有非英語用戶

以下檔案存在大量硬編碼英文字串，未經 `languageManager.localized()` 或 `String(localized:)` 包裝：

| 檔案 | 未本地化字串範例 |
|:---|:---|
| [DiveAnalysisView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Logbook/DiveAnalysisView.swift) | `"Tissue Loading"`, `"Fast"`, `"Slow"`, `"Time"`, `"Depth"`, `"Temp"`, `"Ceiling"`, `"No Deco"` |
| [ImportWizardView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Import/ImportWizardView.swift) | `"Auto-detects format..."`, `"Try Again"`, `"Done"` |
| [MapView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Map/MapView.swift) | `"Dive Site"`, `"Dives with GPS coordinates will appear..."` |
| [DiveSiteSheetView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Map/DiveSiteSheetView.swift) | `"Max Depth"`, `"Dive Time"`, `"Water Temp"` |
| [SettingsView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Settings/SettingsView.swift) | Section headers: `"Language"`, `"Units"`, `"GPS Location"`, `"Premium"`, `"Backup"`, `"About"`, `"Developer Tools"` |
| [DiveLogListView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Logbook/DiveLogListView.swift) | `"No dives yet"`, `"Use the Import tab..."`, `"Dives"`, `"Total Time"`, `"Deepest"` |
| [DiveLogDetailView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Logbook/DiveLogDetailView.swift) | `"Dive Profile"`, `"Key Stats"`, `"Conditions"`, `"Equipment"`, `"Location"`, `"Notes"` |
| [DiveCalendarView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Logbook/DiveCalendarView.swift) | `"No dives on this date."`, `"Select a date..."` |
| [DiveLogEditSheet.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Logbook/DiveLogEditSheet.swift) | `"Seawater"`, `"Freshwater"`, `"Altitude"` 等 Picker 選項 |

> [!WARNING]
> 專案支援 6 種語言（en/zh-Hant/ja/ko/es/fr），但大量字串僅顯示英文。此問題在非英語市場（尤其 zh-Hant 繁體中文為主要目標市場）影響嚴重。

---

### R-06：NSLocationWhenInUseUsageDescription 未本地化

**檔案**：[Info.plist](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Info.plist)

位置權限說明僅有英文版。非英語用戶看到的系統權限彈窗將顯示英文，與 App 內語系不一致。

**需要**：為每個支援語系建立 `InfoPlist.strings` 本地化檔案。

---

### R-07：SwiftData Schema 無版本管理

**檔案**：[JD2_LogbookApp.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/JD2_LogbookApp.swift)

```swift
.modelContainer(for: DiveLog.self)
```

未指定 `Schema` 版本或 `MigrationPlan`。若 `DiveLog` 模型發生結構性變更（新增非可選欄位、重命名屬性），App 更新後可能**無法打開舊資料庫**，導致使用者資料完全無法存取。

---

### R-08：備份資料結構與 DiveLog 模型需手動同步

**檔案**：[DiveLogBackup.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Models/DiveLogBackup.swift) ↔ [DiveLog.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Models/DiveLog.swift)

`DiveLogBackupEntry` 是獨立的 DTO（與 `@Model` 解耦，這是**好的架構**），但新增欄位時必須手動在兩者間同步。測試中的 `testDiveLogBackupEntryRoundTrip` 有驗證 round-trip，但僅限於已有欄位。未來新增欄位若忘記同步，**靜默資料損壞**。

> [!NOTE]
> 目前的 round-trip 測試 (`DiveLogModelTests`) 已涵蓋 `avgDepth`、`importExtrasJSON`、`notes`、`profileSamples` 等欄位，架構設計本身是合理的。風險在於**流程管理**：新增欄位時必須同步更新 DTO + 測試。

---

### R-09：備份還原無重複偵測

**檔案**：[DiveLogBackup.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Models/DiveLogBackup.swift)

還原功能直接插入記錄，不檢查是否已存在相同記錄。用戶誤觸還原兩次將產生完全重複的潛水日誌。

---

### R-10：刪除全部資料缺乏足夠保護

**檔案**：[SettingsView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Settings/SettingsView.swift)

僅有一次 Alert 確認。建議：
- 增加二次驗證（如輸入 "DELETE" 文字確認）
- 在刪除前自動觸發備份

---

### R-11：DiveReplayEngine Schreiner/Haldane 方程式語義

**檔案**：[DiveReplayEngine.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Algorithm/DiveReplayEngine.swift)

程式碼中 `DiveReplayEngine` 已改用 `DiveKit` 框架的 `Buhlmann` 類別進行減壓計算。`DiveKit` 的實作品質需要獨立稽核。以下為在 `DiveReplayEngine` 本體中觀察到的潛在問題：

- 每次計算 `tissueLoadPercent` 時都重新建立 `Buhlmann` 實例（`let probe = Buhlmann(environment: environment)`），有效能浪費的疑慮
- 若 `DiveKit` 的 Buhlmann 常數（半衰期、a/b 係數）不正確，影響所有 ceiling/NDL 結果

> [!IMPORTANT]
> 建議對 `DiveKit` 框架本身進行獨立稽核，確認其 ZHL-16C 常數表準確性。

---

### R-12：GDPR / CCPA 廣告追蹤同意機制缺失

**檔案**：[AdBannerView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Shared/AdBannerView.swift)

AdMob 整合未包含任何使用者同意管理（Google UMP SDK）。歐盟與加州用戶的廣告追蹤需取得明確同意。

> [!WARNING]
> 缺乏同意機制可能違反 GDPR 第 6 條及 CCPA，導致法律風險與 App Store 審核問題。

---

## ⚠️ 建議項目

### 架構與設計

#### S-01：違反 MVVM — View 層含大量業務邏輯

| 檔案 | 違規內容 |
|:---|:---|
| [DiveLogEditSheet.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Logbook/DiveLogEditSheet.swift) | `save()` 方法長達上百行，含資料庫初始化、空值處理、字串修剪、JSON 拼接、`modelContext.insert()` |
| [DiveCalendarView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Logbook/DiveCalendarView.swift) | `divesByDay` 計算屬性在主執行緒對所有日誌做 O(N) 分組 |
| [DiveLogListView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Logbook/DiveLogListView.swift) | 搜尋過濾、排序、統計計算直接在 View |
| [DiveAnalysisView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Logbook/DiveAnalysisView.swift) | 直接實例化與控制 `DiveReplayEngine` |
| 多處 View | `modelContext.delete()` 直接在 View 中呼叫 |

---

#### S-02：狀態管理不一致

混用 `@StateObject` + `ObservableObject`（`AppLanguageManager`、`PurchaseManager`）與 `@State` + `@Observable`（`ImportCoordinator`）。建議統一為 Swift 5.9+ `@Observable` macro。

---

#### S-03：DiveLogDatabase.fetchDives(at:) 效能問題

**檔案**：[DiveLogDatabase.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Models/DiveLogDatabase.swift)

使用 `context.fetch(descriptor)` 載入全部日誌至記憶體後再用 `.filter` 做 `localizedCaseInsensitiveContains`。大量資料時記憶體峰值過高。

---

#### S-04：DiveMapRepresentable Annotation 暴力重建

**檔案**：[DiveMapRepresentable.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Map/DiveMapRepresentable.swift)

```swift
func updateUIView(_ mapView: MKMapView, context: Context) {
    mapView.removeAnnotations(mapView.annotations)
    // 重新加入所有 annotations
}
```

每次 SwiftUI 更新都**移除並重建所有 Annotation**，造成地圖閃爍且效能低落。建議實作差異比對（diff）。

---

#### S-05：DiveMapRepresentable 使用 DispatchQueue.main.async

**檔案**：[DiveMapRepresentable.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Map/DiveMapRepresentable.swift)

在 Swift 6 的現代並行架構中，應改用 `Task { @MainActor in }` 替代 `DispatchQueue.main.async`，以避免時序問題。

---

### UI/UX

#### S-06：地圖座標過濾邏輯不一致

| 檔案 | 邏輯 |
|:---|:---|
| [MapView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Map/MapView.swift) | `latitude != 0 \|\| longitude != 0`（OR） |
| [DiveLogDetailView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Logbook/DiveLogDetailView.swift) | `latitude != 0 && longitude != 0`（AND） |

會導致同一筆記錄在地圖/詳情頁的顯示行為不一致。建議：
1. 統一邏輯
2. 考慮使用 `Optional<Double>` 替代 `0.0` 作為「無座標」哨兵值

---

#### S-07：DiveAnalysisView Timer 未在 onDisappear 清除

**檔案**：[DiveAnalysisView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Logbook/DiveAnalysisView.swift)

自動播放使用 `Timer.scheduledTimer`，但**未在 `onDisappear` 時 invalidate**。記憶體洩漏與背景狀態更新風險。

---

#### S-08：DiveAnalysisView 隱式動畫影響範圍過大

**檔案**：[DiveAnalysisView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Logbook/DiveAnalysisView.swift)

`.animation(.easeInOut(duration: 0.15), value: selectedIndex)` 是隱式動畫，可能影響 View 中其他不應動畫的元件。建議改用 `withAnimation { ... }` 明確控制。

---

#### S-09：數字鍵盤缺少 Done 按鈕

**檔案**：[DiveLogEditSheet.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Logbook/DiveLogEditSheet.swift)

使用 `.keyboardType(.numberPad)` / `.decimalPad` 的 TextField 沒有鍵盤工具列「完成」按鈕，iOS 用戶無法收起數字鍵盤。

**建議**：加入 `.toolbar { ToolbarItem(placement: .keyboard) { Button("Done") { ... } } }`

---

#### S-10：日曆無年份快速導航

**檔案**：[DiveCalendarView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Logbook/DiveCalendarView.swift)

只有月份前後導航，無法快速跳轉至特定年份。長年潛水員操作體驗差。

---

#### S-11：DiveRowView 深度指示器不隨單位縮放

**檔案**：[DiveRowView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Logbook/DiveRowView.swift)

```swift
.frame(width: 4, height: max(20, CGFloat(diveLog.maxDepth) * 0.8))
```

視覺高度使用公尺原始值，英制模式下視覺意義失真。

---

#### S-12：MainTabView 自動切換 Tab 可能打斷用戶

**檔案**：[MainTabView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/MainTabView.swift)

`@AppStorage` 的 `importedLogCount` 變化觸發 Tab 跳轉，背景匯入時可能打斷用戶當前操作。

---

#### S-13：廣告橫幅高度硬編碼

**檔案**：[MainTabView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/MainTabView.swift)

```swift
AdBannerView().frame(height: 50)
```

不同裝置（iPad 等）的 AdMob Banner 尺寸不同。應使用動態高度。

---

#### S-14：ImportWizardView 暫存檔清理不保證

**檔案**：[ImportWizardView.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Import/ImportWizardView.swift)

匯入檔案先複製到 `tempDir`，成功後才刪除。若 App 崩潰或用戶提早離開，暫存檔殘留。

---

### 單位轉換

#### S-15：深度轉壓力假設硬編碼為海水

**檔案**：[DiveReplayEngine.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Algorithm/DiveReplayEngine.swift)

```swift
depth / 10.0 + 1.0  // 海水：10m = 1 bar
```

淡水應為 `depth / 10.3 + 1.0`。目前無法區分。（此行為取決於 `DiveKit` 的 `DiveEnvironment` 是否處理此差異。）

---

#### S-16：純氧標示為 "Nitrox 100"

**檔案**：[GasMix+LocalizedDisplay.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Utilities/GasMix+LocalizedDisplay.swift)

100% O2 邏輯上歸類為 Nitrox 顯示。技術潛水慣用 "Oxygen" 或 "O2"。

---

### 無障礙 (Accessibility)

#### S-17：缺乏 Accessibility 標記

全專案**未見顯著的** `.accessibilityLabel` / `.accessibilityHint` / `.accessibilityValue` 實作。VoiceOver 用戶將無法有效使用：
- 自訂日曆格子
- 深度色彩指示器
- 組織壓力長條圖
- 潛水剖面圖表
- 數值輸入 TextField（VoiceOver 不知道是「深度」還是「溫度」）

---

### 本地化品質

#### S-18：部分新增字串缺少 ja / ko / es / fr 翻譯

**檔案**：[Localizable.xcstrings](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Localizable.xcstrings)

多個較新的 key 僅有 en 與 zh-Hant 翻譯，其餘四語系標記 `"needs_review"` 或缺失。

---

#### S-19：韓文 / 西班牙文翻譯品質存疑

部分韓文 (ko) 與西班牙文 (es) 語感偏機器翻譯，法文 (fr) 有個別重音遺漏。zh-Hant 與 ja 品質較佳。

---

### 服務層

#### S-20：UserLocationProvider 持續追蹤 + 過度精確

**檔案**：[UserLocationProvider.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Services/UserLocationProvider.swift)

- `desiredAccuracy = kCLLocationAccuracyBest`：潛點地圖用 `kCLLocationAccuracyHundredMeters` 即可
- 未見 `stopUpdatingLocation()`，持續耗電
- 錯誤僅 `print` 到 Console，用戶無從得知

---

#### S-21：PurchaseManager 非受管 Task

**檔案**：[PurchaseManager.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Services/PurchaseManager.swift)

`init()` 中 `Task { [weak self] in await self?.listenForTransactions() }` 為非受管背景 Task，在測試或極端情況下難以控制。

---

### 測試覆蓋

#### S-22：測試覆蓋不足

| 模組 | 覆蓋 | 說明 |
|:---|:---:|:---|
| DiveReplayEngine | ⚠️ 基礎 | 有 NDL 遞減測試、淺潛/深潛、Trimix 短路。**缺：** 不同 GF 值、高海拔環境 |
| UnitSystem | 🚨 無 | 無專門測試檔 |
| Views（全部） | 🚨 無 | 無 UI Test |
| Services（3個） | 🚨 無 | 無測試 |
| DiveLog Model | ✅ 良好 | 含邊界值、round-trip、向後相容 |
| ImportCoordinator | ✅ 良好 | 最完整測試（22KB），含重複偵測、異常排除 |
| GasMix | ✅ 良好 | 含 fO2 > 1.0 極端防呆 |
| DiveImportKitAdapter | ⚠️ 單一格式 | 僅 UDDF，缺其他格式 |

---

#### S-23：JD2_LogbookTests.swift 為空殼

**檔案**：[JD2_LogbookTests.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-LogbookTests/JD2_LogbookTests.swift)

```swift
func testExample() throws { XCTAssertTrue(true) }
```

無意義測試，建議移除或替換。

---

#### S-24：DiveImportKitAdapter 缺負向測試

**檔案**：[DiveImportKitAdapterTests.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-LogbookTests/DiveImportKitAdapterTests.swift)

僅 UDDF 正常路徑。缺：損壞資料、缺欄位、空白檔案、其他格式（CSV, FIT）。

---

#### S-25：GasMix 缺 fHe 邊界測試

**檔案**：[GasMixTests.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-LogbookTests/GasMixTests.swift)

無 `fHe < 0` 或 `fO2 + fHe > 1.0` 的防呆測試。

---

#### S-26：DiveReplayEngine 缺高海拔 / 不同 GF 測試

**檔案**：[DiveReplayEngineTests.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-LogbookTests/DiveReplayEngineTests.swift)

僅測試預設 `DiveEnvironment`。缺：不同梯度因子（GF）、高海拔環境。

---

## ✅ 通過項目

| # | 項目 | 說明 |
|:---:|:---|:---|
| P-01 | 溫度轉換公式 | °C ↔ °F (`*9/5+32`, `-32*5/9`) ✅ |
| P-02 | 深度轉換因子 | 3.28084 m→ft ✅ |
| P-03 | 壓力轉換因子 | 14.5038 bar→PSI ✅ |
| P-04 | 重量轉換因子 | 2.20462 kg→lbs ✅ |
| P-05 | 單位標籤對應 | m/ft, °C/°F, bar/PSI 正確 ✅ |
| P-06 | 內部儲存一律公制 | 深度=m, 溫度=°C, 壓力=bar ✅ |
| P-07 | DiveProfile 儲存一律公制 | 消除轉換歧義 ✅ |
| P-08 | GasMix 本地化顯示名稱 | Air / Nitrox / Trimix 判斷正確 ✅ |
| P-09 | 深度色彩閾值 | 18m/30m/40m 符合休閒潛水標準 ✅ |
| P-10 | Trimix 短路保護 | 偵測 trimix 後安全跳過不支援的減壓計算 ✅ |
| P-11 | DiveLogBackupEntry DTO 解耦 | 使用獨立 DTO 與 `@Model` 解耦，架構正確 ✅ |
| P-12 | ImportCoordinator 並行安全 | `Task.detached` 背景解析 → MainActor 寫入 ✅ |
| P-13 | DiveImportKitAdapter Sendable 設計 | `parseAndValidateForBackground` 確保跨 actor 安全 ✅ |
| P-14 | 安全範圍 URL 存取 | 正確使用 `startAccessingSecurityScopedResource` ✅ |
| P-15 | 語系選擇器使用原生文字 | 繁體中文、日本語、한국어… ✅ |
| P-16 | 平台色彩抽象 | iOS/macOS 跨平台正確 ✅ |
| P-17 | StoreKit 2 交易完成 | `transaction.finish()` 確保佇列不卡死 ✅ |
| P-18 | DiveProfileSample 向後相容 | 舊版 `{t,d}` JSON 正確解碼，新版 `{t,d,w}` 可選水溫 ✅ |

---

## 📋 修正優先順序建議

### Phase 1：上架阻斷（Release Blocker）
1. **R-01**：移除 `NSAllowsArbitraryLoads = true`（ATS 安全漏洞）
2. **R-03**：修正 deepestDive 硬編碼單位（數據失真）
3. **R-05**：本地化所有硬編碼 UI 字串
4. **R-06**：本地化 Info.plist 權限說明
5. **R-12**：實作 GDPR/CCPA 同意管理（法律風險）

### Phase 2：安全與正確性
6. **R-04**：修正 getStatistics() 語義失真
7. **R-11**：獨立稽核 DiveKit 框架的 ZHL-16C 常數
8. **S-07**：修正 Timer 洩漏
9. **S-15**：確認 DiveKit 海水/淡水處理

### Phase 3：資料安全
10. **R-07**：實作 SwiftData MigrationPlan
11. **R-08**：備份 DTO 新增欄位流程文件化
12. **R-09**：備份還原增加重複偵測
13. **R-10**：刪除資料增加保護

### Phase 4：體驗與架構優化
14. **S-01**：重構 MVVM（抽取 ViewModel）
15. **S-04**～**S-06**：Map 效能與一致性
16. **S-09**：數字鍵盤 Done 按鈕
17. **S-17**：加入 Accessibility 支援
18. **S-18**～**S-19**：完善多語系翻譯品質
19. **S-22**～**S-26**：補強測試覆蓋

---

> [!NOTE]
> 本稽核報告基於 4 個研究子代理**完整讀取所有原始碼**後的靜態分析，未執行編譯或 runtime 測試。  
> `DiveReplayEngine` 實際使用外部 `DiveKit` 框架的 `Buhlmann` 類別，框架本身的演算法正確性需獨立稽核。  
> Info.plist 中的 AdMob ID (`ca-app-pub-9582822701117167~2224926394`) 為實際值，非佔位符。
