# Garmin Connect JSON 解析器研究

## 1. 檔案格式特徵
*   **格式類型**：JSON。
*   **副檔名**：`.json`
*   **來源**：Garmin Connect 帳戶資料備份匯出中取得的潛水活動 (Dives Activity) 的 JSON。

## 2. 結構特徵與關鍵欄位
*   `activityId`：Garmin 潛水活動的唯一 ID。
*   `startTimeLocal`：ISO 8601 本地時間字串 (如 `2023-10-21T12:13:38.0`)。
*   `duration`：潛水總時間（秒）。
*   `summaries`：元數據總覽物件：
    *   `maxDepth`：最大深度（公尺）。
    *   `avgDepth`：平均深度（公尺）。
    *   `minTemperature`：最低水溫（攝氏 °C）。
*   `metadata` -> `deviceInfo` -> `deviceModelName`：記錄手錶型號（如 `Descent Mk2i`）。

## 3. Swift 解析器設計建議

### 偵測邏輯 (canHandle)
```swift
func canHandle(filePath: String) -> Bool {
    let ext = (filePath as NSString).pathExtension.lowercased()
    guard ext == "json" else { return false }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return false }
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
    return json["activityId"] != nil && json["activityType"] != nil
}
```

### 關鍵欄位轉換 (Mapping)
1.  **Swift Decodable 實作**：
    定義對應的 `Codable` Struct 便於解析：
    ```swift
    struct GarminConnectActivity: Codable {
        let activityId: Int
        let startTimeLocal: String
        let duration: Double
        let summaries: GarminSummaries
        
        struct GarminSummaries: Codable {
            let maxDepth: Double
            let avgDepth: Double
            let minTemperature: Double
        }
    }
    ```
2.  **平均深度備註追加**：
    `summaries.avgDepth` 應轉化為 `"Avg depth: XX m"`，追加寫入 `DiveLog` 的 `notes` 欄位以防止資料丟失。
