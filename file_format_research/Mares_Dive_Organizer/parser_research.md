# Mares Dive Organizer 解析器研究

## 1. 檔案格式特徵
*   **格式類型**：微軟 SQL Server Compact Edition 資料庫格式。
*   **副檔名**：`.sdf` 或 `.dbf`

## 2. 結構特徵與解析障礙
*   **非 SQLite**：Mares Dive Organizer **沒有**使用業界常見的 SQLite 引擎，而是使用微軟已淘汰的 SQL Server Compact Edition (SDF)。
*   **平台相容性**：SDF 引擎是微軟 Windows 平台的專有技術。在 macOS / iOS 平台下，沒有原生驅動可以讀取或查詢 `.sdf` 資料庫。這使得在 Swift 中直接讀取 Mares 的本地資料庫檔案變得極為困難。

## 3. Swift 解析器設計建議

### 偵測邏輯 (canHandle)
```swift
func canHandle(filePath: String) -> Bool {
    let ext = (filePath as NSString).pathExtension.lowercased()
    return ext == "sdf"
}
```

### 建議的解析與遷移路徑
1.  **導出至 UDDF**：
    引導使用者先在電腦端將 Mares Dive Organizer 資料匯出，或者載入至 **Subsurface** 再匯出成開源標準的 **UDDF** 或 XML。
2.  **中間轉檔服務**：
    社群多元使用 [divelogs.de](https://www.divelogs.de) 這類免費線上平台作為轉換器，將 Mares 資料庫上傳並轉存成標準 XML / UDDF，再匯入 JD2-Logbook。
