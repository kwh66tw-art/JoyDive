# Shearwater XML 解析器研究

## 1. 檔案格式特徵
*   **格式類型**：Shearwater Cloud/Desktop 專有 XML 導出格式。
*   **副檔名**：`.xml`
*   **主要用途**：將 Shearwater 的潛水資料遷移至 Garmin Connect 或 Subsurface 等平台。

## 2. 結構特徵與關鍵標籤
*   `<start_time>`：ISO 8601 格式時間。
*   `<duration>`：潛水時間（秒）。
*   `<max_depth>`：最大深度（公尺）。
*   `<mean_depth>`：平均深度（公尺）。
*   `<water_temp>`：水溫（攝氏 °C）。
*   `<gases>`：內含一個或多個 `<gas>`：
    *   `<oxygen>`：氧氣比例。
    *   `<helium>`：氦氣比例。
*   `<samples>`：內含多個相隔固定秒數（如 10 秒或 20 秒）的 `<sample>` 節點：
    *   `<time>`：累計秒數。
    *   `<depth>`：當前深度（公尺）。
    *   `<temp>`：當前溫度（攝氏 °C）。
    *   `<pressure>`：當前殘壓（bar/psi）。

## 3. Swift 解析器設計建議

### 偵測邏輯 (canHandle) 防錯修正
現存的 `SHEARWATERParser` 僅檢查副檔名是否為 `.xml`，容易與其它的 XML 格式（如 Suunto DM5 XML）混淆。應升級 `canHandle` 進行內容特徵字串檢測：
```swift
func canHandle(filePath: String) -> Bool {
    let ext = (filePath as NSString).pathExtension.lowercased()
    guard ext == "xml" else { return false }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return false }
    guard let head = String(data: data.prefix(512), encoding: .utf8) else { return false }
    return head.contains("<logbook>") && head.contains("<computer_model>")
}
```

### 關鍵欄位轉換 (Mapping)
1.  **氣體百分比處理**：
    需要判定 `<oxygen>` 標籤中儲存的值是百分比整數（如 21）還是 fraction 分率（如 0.21），這會隨不同版本的 Shearwater Cloud 匯出而異。實作時應加上啟發式判定：`value > 1.0 ? value / 100.0 : value`。
2.  **平均深度備註**：
    由於 JD2-Logbook core model 沒有獨立的 `meanDepth` 欄位，解析時應將 `<mean_depth>` 格式化為 `"Avg depth: XX m"`，並追加到 `notes` 欄位中。
