# Suunto SML (Suunto Markup Language) 解析器研究

## 1. 檔案格式特徵
*   **格式類型**：Suunto 早期桌面同步軟體 Moveslink / Moveslink2 所快取與產生的 XML 檔案。
*   **副檔名**：`.sml` 或 `.xml`
*   **特徵特點**：在 Suunto App 的新版數據導出中，它會以 JSON 包裝並對應到 `"suunto/sml"` 的 Key。

## 2. 結構特徵與關鍵標籤 (XML 格式)
*   `<DeviceLog>`：日誌的根節點。
*   `<Header>`：包含活動元數據：
    *   `<Duration>`：總時間（秒）。
    *   `<DateTime>`：ISO 8601 格式時間。
    *   `<Device>` / `<Name>`：設備型號名稱（例如 `Suunto Ambit2`）。
*   `<Samples>`：包含時間序列的 `<Sample>`：
    *   `<Time>`：自潛水開始以來的時間（秒）。
    *   `<Depth>`：當前深度（公尺）。
    *   `<Temperature>`：當前水溫，**單位為絕對溫度 Kelvin (K)**！
    *   `<Pressure>`：當前環境氣壓/水壓。

## 3. Swift 解析器設計建議

### 偵測邏輯 (canHandle)
```swift
func canHandle(filePath: String) -> Bool {
    let ext = (filePath as NSString).pathExtension.lowercased()
    guard ext == "sml" || ext == "xml" else { return false }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return false }
    guard let head = String(data: data.prefix(1024), encoding: .utf8) else { return false }
    return head.contains("<DeviceLog>") && head.contains("suunto")
}
```

### 關鍵欄位轉換 (Mapping)
1.  **水溫單位轉換 (Kelvin → Celsius)**：
    SML XML 中記錄的溫度通常是絕對溫度 (Kelvin)，例如 `298.15`。解析時必須轉換為攝氏度：
    $$\text{Celsius} = \text{Kelvin} - 273.15$$
    *   298.15 K 應轉換為 25.0 °C。
    *   273.15 K 應轉換為 0.0 °C。
2.  **GPS 座標處理**：
    SML 常常會記錄經緯度。某些 Moveslink 產生的 SML 檔案中，緯度與經度是使用**弧度 (Radians)** 記錄而非十進位度數 (Degrees)。
    *   如果偵測到值介於 $\pm\pi$ 之間，可能需要進行弧度轉換：
        $$\text{Degrees} = \text{Radians} \times \frac{180}{\pi}$$
