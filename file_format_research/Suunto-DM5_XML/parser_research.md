# Suunto DM5 XML 解析器研究

## 1. 檔案格式特徵
*   **格式類型**：WCF (Windows Communication Foundation) XML 序列化格式。
*   **命名空間**：`xmlns="http://schemas.datacontract.org/2004/07/Suunto.Diving.Dal"`
*   **副檔名**：`.xml` (或包裝在 `.sde` 壓縮包中)。

## 2. 結構特徵與關鍵標籤
*   `<StartTime>`：格式為 `YYYY-MM-DDTHH:MM:SS` (通常無時區偏移)。
*   `<Duration>`：整數，代表潛水總時間（秒）。
*   `<MaxDepth>`：浮點數，最大深度（公尺）。
*   `<BottomTemperature>`：整數，水底最低溫度（攝氏 °C）。
*   `<DiveMixtures>`：氣體列表。每個 `<DiveMixture>` 包含：
    *   `<Oxygen>`：**百分比整數**（例如 `30` 代表 30% O2，即 EANx30）。
    *   `<Helium>`：**百分比整數**（例如 `0`）。
*   `<DiveSamples>`：深度剖面樣本集。包含多個 `<Dive.Sample>`：
    *   `<Time>`：相對於開始時間的秒數。
    *   `<Depth>`：目前深度（公尺）。
    *   `<Temperature>`：目前水溫（攝氏 °C）。

## 3. Swift 解析器設計建議

### 偵測邏輯 (canHandle)
```swift
func canHandle(filePath: String) -> Bool {
    let ext = (filePath as NSString).pathExtension.lowercased()
    guard ext == "xml" else { return false }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return false }
    guard let head = String(data: data.prefix(512), encoding: .utf8) else { return false }
    return head.contains("Suunto.Diving.Dal")
}
```

### 關鍵欄位轉換 (Mapping)
1.  **時間處理**：`<StartTime>` 為無時區本地時間，解析時應使用 `DateFormatter` 並設定 `timeZone = TimeZone(secondsFromGMT: 0)` 或使用裝置本地時區。
2.  **溫度轉換**：DM5 XML 直接使用攝氏度 (Celsius) 表示水溫，**不需要**像 Suunto App JSON 那樣進行 `Kelvin - 273.15` 的單位轉換。
3.  **氣體分率**：`<Oxygen>` 與 `<Helium>` 是整數百分比，轉換至 JD2 `gasMixJSON` 時需除以 `100.0` 轉為 fraction。
    *   例如 `O2 = 30` 應轉換為 `fO2 = 0.30`。
4.  **剖面樣本名稱**：節點名稱為 `<Dive.Sample>`，包含點號。Swift XMLParser 讀取此節點時會將其視為完整的 Element Name，需注意字串比對要精確。
