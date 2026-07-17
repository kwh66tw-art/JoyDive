# Scubapro SmartTrak / LogTRAK 解析器研究

## 1. 檔案格式特徵
*   **格式類型**：專有二進位資料庫檔 (MS Access MDB 結構，內含 Scubapro 潛水二進位 Blob) 或 HSQL 資料庫結構。
*   **副檔名**：`.slg` (SmartTRAK) 或 `.asd` / `.logtrak`
*   **範例檔案**：
    *   [Demo_SmartTrak.slg](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Scubapro_LogTRAK/Demo_SmartTrak.slg) (真實資料，SmartTRAK 匯出檔)

## 2. 結構特徵與解析障礙
*   **SLG 結構**：`.slg` 檔案本質上是打包過的二進位資料庫檔案。其中潛水記錄的深度剖面 (Profile Data) 與溫度以特有的二進位 Blob 形式存放在資料表中。由於演算法和壓縮機制為專有，直接編寫解析器極為困難。
*   **LogTRAK 結構**：較新版 LogTRAK 軟體主要是在使用者的隱藏目錄（例如 `.jtrak/DB_V4/` 下的 `jtrak.script`）中儲存一個 HSQL (HyperSQL) 資料庫。

## 3. Swift 解析器設計建議

### 偵測邏輯 (canHandle)
*   對於 `.slg` 檔：
    ```swift
    func canHandle(filePath: String) -> Bool {
        let ext = (filePath as NSString).pathExtension.lowercased()
        return ext == "slg"
    }
    ```

### 建議的解析與遷移路徑
由於 SLG/LogTRAK 屬於封閉型微軟資料庫與專有二進位格式，在 iOS/macOS 的 Swift 環境下進行直接原生解析，技術成本與維護難度極高。
*   **社群推薦方案**：
    引導使用者先在電腦端使用 **Subsurface** 載入 `.slg` 或 `.asd`，再將其轉存為開源標準的 **UDDF** 或 Subsurface XML (`.ssrf`)。JD2-Logbook 接著直接解析 UDDF 即可，能以極低的開發成本獲得 100% 的精確度。
