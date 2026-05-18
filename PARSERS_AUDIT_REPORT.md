# 潛水日誌解析器深度稽核報告 (Week 3-6)

**稽核日期**: 2026-05-18
**審查範圍**: Week 3-6 所涵蓋之核心解析器代碼，包含 `UDDFParser`, `SubsurfaceCSVParser`, `SuuntoJSONParser`, `SubsurfaceXMLParser` 以及 `ImportCoordinator`。

---

## 🚨 1. 嚴重架構衝突 (Critical Architecture Conflict)

在專案中發現了**兩個完全不同的 `DiveLogImporter` 協議定義與 `UDDFParser` 實作**：

1. **根目錄版本 (`/UDDFParser.swift`)**：
   - 包含舊版的 `DiveLogImporter` 協議（使用 `URL` 作為參數，並定義了 `validate` 方法）。
   - 依賴 `ZipFoundation` 進行 ZIP 解壓縮。
   - 使用了簡化版的 `DiveLog` 結構體（Placeholder）。
2. **核心版本 (`JD2Core/Importers/DiveLogImporter.swift`)**：
   - 包含新版的 `DiveLogImporter` 協議（使用 `String` 路徑，並包含 `canHandle`, `validateContent`）。
   - 包含 `DiveLogImporterFactory` 工廠模式。
   - 內建的 `UDDFParser` 在 macOS 使用 `Process` 呼叫 `/usr/bin/unzip`，並標記 iOS 暫不支援 ZIP（因為缺少 ZipFoundation）。

**🛠️ 修正建議**：
- **必須刪除**根目錄的 `/UDDFParser.swift` 以避免命名衝突與架構混亂。
- 將 `ZipFoundation` 的解壓縮邏輯整合進 `JD2Core` 的 `UDDFParser` 中，使其在 iOS 環境下也能解壓縮 `.uddf` ZIP 容器。

---

## ⚠️ 2. ImportCoordinator 的重大邏輯漏洞 (Critical Logic Bug)

在 `JD2Core/Importers/ImportCoordinator.swift` 中，`deduplicateDives` 方法的重複判斷邏輯存在嚴重缺陷：

```swift
!existing.contains { existing in
    Calendar.current.isDate(existing.dateTime, inSameDayAs: dive.dateTime)
        && existing.location == dive.location
        && existing.maxDepth == dive.maxDepth
}
```

**問題描述**：
使用 `isDate(..., inSameDayAs:)` 只比較「日期」。如果潛水員在**同一天**於**同一個地點**進行了兩次潛水，且剛好**最大深度相同**（例如在同一個訓練場地進行兩次 20m 潛水），第二次潛水將會被誤判為重複並被拋棄！

**🛠️ 修正建議**：
潛水日誌的去重應該比較「精確的時間點」而不是「同一天」。
建議將判斷改為比較兩次潛水的時間差是否小於某個閾值（例如 5 分鐘內視為同一筆，或直接精確比較秒數）：
```swift
abs(existing.dateTime.timeIntervalSince(dive.dateTime)) < 60 // 誤差在 1 分鐘內
```

---

## 🔍 3. SubsurfaceCSVParser 解析器漏洞 (Edge Case Bugs)

在 `SubsurfaceCSVParser` 中，有兩個潛在的邊界情況處理漏洞：

**漏洞 A：潛水時間解析 (`parseDurationMMSS`)**
```swift
let parts = str.split(separator: ":").map(String.init)
guard parts.count == 2, ...
```
**問題**：該函數預期格式為 `MM:SS` (包含剛好兩個部分)。如果匯出的 CSV 潛水時間超過 1 小時，且格式變為 `HH:MM:SS`（包含三個部分），`parts.count` 將會是 3，導致回傳 `0`。這會讓超過 1 小時的潛水記錄全部失效。
**🛠️ 修正建議**：需支援 `HH:MM:SS` 三段式的解析防呆。

**漏洞 B：日期格式解析 (`parseDateTime`)**
```swift
let dp = date.split(separator: "/").map(String.init)
```
**問題**：假設格式固定為 `M/D/YY` 或 `M/D/YYYY`。但 CSV 是純文字格式，如果在其他語系（如歐洲）匯出，格式極可能是 `DD.MM.YYYY` 或 `YYYY-MM-DD`。一旦分隔符號不是 `/`，或者年份在最前面，解析就會崩潰或回傳 nil。
**🛠️ 修正建議**：使用正規表達式或 `DateFormatter` 支援多種常見日期格式的 Fallback。

---

## ✅ 4. SuuntoJSONParser (表現優異)

- `SuuntoJSONParser` 的實作非常穩健。
- 正確地處理了 `Header` 以及 `Samples` 陣列。
- 將水溫從 Kelvin (絕對溫度) 轉換為攝氏溫度的邏輯正確。
- 氣體 (O2 分率) 轉換為 `gasMixJSON` 格式的防呆（小於 0.005 誤差視為空氣）處理得很漂亮。
- 唯一可挑剔點是使用了純原生的 `JSONSerialization` 取代 `Codable`。雖然這在處理非嚴格格式時更具彈性，但維護上會稍顯冗長，但目前狀態完全可接受。

---

## 📝 5. 結論與下一步行動 (Action Items)

總體而言，Week 3-6 的解析器代碼架構非常漂亮，`DiveLogImporterFactory` 提供了絕佳的擴展性。但存在幾個會導致**資料丟失**的潛在 Bug 需要立刻修復。

**建議的修復順序 (P0 -> P2)**：
1. **[P0]** 修改 `ImportCoordinator.swift` 中的去重邏輯，避免同一天同地點的潛水被誤刪。
2. **[P0]** 刪除根目錄的 `/UDDFParser.swift`，清理架構。
3. **[P1]** 增強 `SubsurfaceCSVParser.swift` 中對時間 (`HH:MM:SS`) 與日期 (`YYYY-MM-DD`) 的容錯能力。
4. **[P2]** 完善 `JD2Core` 內 `UDDFParser` 針對 iOS 的 ZIP 解壓縮支援。
