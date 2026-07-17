# Reefnet Sensus 解析器研究

## 1. 檔案格式特徵
*   **格式類型**：Reefnet Sensus 數據記錄器產生的 `.dat` (二進位) 或 `.csv` (純文字) 檔案。
*   **副檔名**：`.dat`, `.csv`
*   **範例檔案**：
    *   [TestSensusSingle.csv](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Sensus_Reefnet/TestSensusSingle.csv) (真實資料，Sensus CSV 匯出檔)

## 2. CSV 結構特徵
*   **Header 區塊**：以特定標籤開始（如設備資訊與採樣率）。
*   **採樣數據**：以逗號分隔，通常包含時間 (Time) 與深度 (Depth)。

## 3. Swift 解析器設計建議

### 偵測邏輯 (canHandle)
```swift
func canHandle(filePath: String) -> Bool {
    let ext = (filePath as NSString).pathExtension.lowercased()
    guard ext == "csv" else { return false }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return false }
    guard let head = String(data: data.prefix(512), encoding: .utf8) else { return false }
    return head.contains("Sensus") || head.contains("Reefnet")
}
```

### 解析邏輯
1.  **時間處理**：Sensus 通常記錄的是相對秒數，直接映射為 `DiveProfileSample` 的 `timeSeconds`。
2.  **剖面轉換**：由於 Sensus 是純粹的數據記錄器（Data Logger），其不包含氣體等複雜數據，解析時只需重點提取時間、深度與水溫即可。
