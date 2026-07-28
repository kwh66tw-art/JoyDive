# 🔍 JD2-Logbook 專案完整程式碼稽核報告

**稽核員**：資深技術架構師 & 軟體品質稽核專家  
**稽核對象**：JD2-Logbook 專案所有 Swift 核心程式碼（含減壓演算法、資料層、UI/UX 邏輯與跨平台適配）  
**稽核日期**：2026 年 7 月 26 日  

---

## 📋 Executive Summary (稽核摘要)

本專案整體架構設計優良，模組化程度高，並成功將潛水資料處理核心解耦至 `DiveImportKit` 與 `DiveKit`。Swift 6 Strict Concurrency 與 `@MainActor` 的線程安全界線劃分清晰，多語系切換及 macOS/iOS 跨平台佈局（`NavigationSplitView` / `HSplitView`）亦展現了高度的專業水準。

然而，經深度稽核原始碼後，發現了 **3 項重大邏輯與潛水資料安全風險 (🚨)**，以及 **3 項架構與 UI/UX 改善建議 (⚠️)**。本報告詳細列出各項問題點與改善建議。

---

## 🚨 重大風險 (Risks) — 必須優先處理

### 1. 潛水日誌深度顯示硬編碼截斷漏洞 (UI/UX 與資料真實性衝突)
* **位置**：[Extensions.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Utilities/Extensions.swift#L13-L19) `Double.depthFormatted`
* **原始碼**：
  ```swift
  var depthFormatted: String {
      if self >= 40.0 {
          return "> 40m"
      }
      return String(format: "%.1f m", self)
  }
  ```
* **風險說明**：
  本 App 為**潛水日誌 (Logbook)** 應用程式，使用者會記錄或匯入 40 公尺以上的歷史潛水紀錄（如 42m, 45m, 60m 的技術潛水或休閒潛水極限）。當 UI 調用 `.depthFormatted` 時，所有 $\ge 40\text{m}$ 的深度將被寫死強制顯示為 `"> 40m"`，遮蔽了真實的最大深度數據。
* **潛水安全與 UX 影響**：即時潛水儀表板或許會有 40m 警示，但在**日誌檢視**與歷史數據統計中，硬性遮蔽數據會讓使用者無法取得準確的潛水日誌紀錄。

---

### 2. 編輯潛水時靜默破壞 Trimix 混合氣體資料 (資料損壞風險)
* **位置**：[DiveLogEditSheet.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Logbook/DiveLogEditSheet.swift#L124-L127)
* **原始碼**：
  ```swift
  case .trimix:
      // Trimix 目前不支援手動編輯，降級為 Air
      _gasMixType      = State(initialValue: .air)
      _nitroxO2Percent = State(initialValue: 32.0)
  ```
* **風險說明**：
  當使用者匯入包含 **Trimix (氦氮氧三混氣)** 的潛水日誌後，若在 `DiveLogDetailView` 點擊「Edit」並儲存，`DiveLogEditSheet` 在解碼 gasMixJSON 時遇到 `.trimix` 會**直接將氣體設定降級為 Air (`"air"`)** 並寫回資料庫。
* **潛水安全與 UX 影響**：使用者僅想修改地點或備註，儲存後其 Trimix 氣體資料卻被不可逆地覆蓋改寫為空氣，導致事後重放與氣體紀錄嚴重失真。

---

### 3. 水面負深度傳入 Buhlmann 天花板計算之邊界隱患
* **位置**：[DiveReplayEngine.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Algorithm/DiveReplayEngine.swift#L152-L161) `makePoint()`
* **原始碼**：
  ```swift
  private static func makePoint(sample: DiveProfileSample, buhlmann: Buhlmann, gasMix: GasMix) -> ReplayPoint {
      ReplayPoint(
          timeSeconds: sample.timeSeconds,
          depthMeters: sample.depthMeters,
          waterTemp: sample.waterTemp,
          ceilingDepth: buhlmann.ceiling(at: sample.depthMeters),
          ndlSeconds: buhlmann.ndlSeconds(at: max(sample.depthMeters, 0), gasMix: gasMix),
          tissuePressures: buhlmann.tissuePressures
      )
  }
  ```
* **風險說明**：
  程式碼中 `ndlSeconds` 考慮到了波浪或水面採樣造成的負深度，使用了 `max(sample.depthMeters, 0)` 進行邊界防護；但 `ceilingDepth` 卻直接將可能為負數的 `sample.depthMeters` 傳給 `buhlmann.ceiling(at:)`。若 Buhlmann 內部未對負深度做校正，計算 Bar 環境壓時會得出低於大氣壓的數值，可能引發非預期的浮點數異常或計算錯誤。

---

## ⚠️ 優化建議 (Suggestions) — 建議改進

### 1. `DiveLog.averageAscentRate` 計算邏輯名實不符
* **位置**：[DiveLog.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Models/DiveLog.swift#L216-L221)
* **說明**：
  ```swift
  var averageAscentRate: Double {
      guard diveTimeSeconds > 0 else { return 0 }
      let timeInMinutes = Double(diveTimeSeconds) / 60.0
      return maxDepth / timeInMinutes
  }
  ```
  `averageAscentRate` 被命名為「平均上升速率」（Ascent Rate），但公式卻是 `maxDepth / 總潛水時間`。這代表的是全程的綜合平均移動速度，無法代表真正的「上升速率」（Ascent Rate）。建議更名為 `averageSpeed` 或實作基於剖面樣本上升段的精確上升速率計算。

### 2. `DiveLog` 計算屬性 `profileSamples` 主執行緒解碼開銷
* **位置**：[DiveLog.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Models/DiveLog.swift#L208-L213)
* **說明**：
  `profileSamples` 為計算屬性，每次被 View 讀取時都會執行 `JSONDecoder().decode([DiveProfileSample].self, from: data)`。在列表中滾動或重新繪製剖面圖時，會反覆在 MainActor 上解碼數百至數千點的 JSON，造成不必要的 CPU 負擔。建議加入輕量快取或延遲解碼機制。

### 3. `DiveLogEditSheet` 部分裝備欄位缺乏英制 (Imperial) 單位雙向轉換
* **位置**：[DiveLogEditSheet.swift](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2-Logbook/Views/Logbook/DiveLogEditSheet.swift#L458-L535)
* **說明**：
  `DiveLogEditSheet` 雖然在 `maxDepth` 與 `waterTemperature` 上實作了 `UnitSystem` 的雙向綁定轉換，但在配重 `weightTotal` (固定標示 kg) 與氣瓶壓力 `cylinderStartPressure` (固定標示 bar) 處卻硬編碼了公制單位。當使用者切換至英制系統 ($ft / ^\circ F$) 時，配重與壓力輸入框並未自動轉換為 $lbs$ 與 $PSI$，容易造成輸入單位混淆。

---

## ✅ 通過項目 (Passed) — 符合品質與安全標準

1. **減壓演算法與 GF 修正 (Bühlmann ZHL-16C)**：
   * `DiveReplayEngine.swift` 的組織分壓與 $M\text{-value}$ 換算 `tissueLoadPercent` 符合標準公式 $M_{gf} = P_{amb} \cdot \left(\frac{GF}{b} + 1 - GF\right) + GF \cdot a$。
   * 重放引擎具備步長 $\le 10\text{s}$ 的線性內插，防止大樣本間隔產生的深度跳變失真。

2. **多語系 (i18n) 四段式架構**：
   * 採用 `AppLanguageManager` 結合行程級 `AppleLanguages` Override、`\.locale` 環境變數與 `.localized(_:)` 手動查表，徹底解決了 NavigationBar 與 TabBar 系統層元件無法即時切換語系的平台限制。

3. **Swift 6 並行安全與資料庫架構**：
   * `DiveLogDatabase` 嚴格限制在 `@MainActor`。
   * `ImportCoordinator` 的背景解析透過 `parseAndValidateForBackground` 僅處理 `Sendable` 的 DTO (`ParsedDiveLog`)，完全消除了跨 Actor 傳遞 SwiftData `@Model` 物件造成的崩潰隱患。
   * 批次匯入去重機制採用（地點 + 最大深度 + 60秒內時間差）動態指紋比對，邏輯嚴密。

4. **macOS / iOS 雙平台 UI/UX 深度優化**：
   * macOS 專屬 `NavigationSplitView` 與 `HSplitView` 結合了列表鍵盤方向鍵導覽 (`onMoveCommand`)。
   * 色彩對比度符合 WCAG 2.1 AA 標準（`accessibleSecondary` 在淺/深色模式下對比度均 $\ge 4.5:1$）。

---

## 🎯 稽核結論

本專案整體技術架構紮實、程式碼乾淨且規範。**只要優先修復上述 3 項重大風險 (🚨)**（特別是 `depthFormatted` 的 40m 限制修復與 Edit Sheet 對 Trimix 資料的保護），本 App 即可達標上線標準。

*本報告僅提供稽核診斷，未對 codebase 進行任何程式碼異動。*
