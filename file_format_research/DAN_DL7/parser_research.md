# DAN DL7 / ZXU 解析器研究

## 1. 檔案格式特徵
*   **格式類型**：DAN (Divers Alert Network) 設計的純文字管道符號 `|` 分隔欄位資料格式。也被稱為 `ZXU` 格式。
*   **副檔名**：`.zxu`, `.zxl`, `.dl7` 或 `.txt`
*   **格式用途**：用來向 DAN 提交潛水安全研究計畫數據的電腦中性標準格式。

## 2. 結構特徵與關鍵標籤
檔案逐行讀取，每行第一個欄位為紀錄類型識別碼：

*   **`FSH` (File Set Header)**：
    *   例如：`FSH|^~\&{}|ANST01^12X456^A|ZXU|20180106163705+02:00|`
*   **`ZRH` (Record Header)**：
    *   定義使用的計量單位，如 `C` (攝氏)、`bar` (壓力)、`L` (公升)。
    *   例如：`ZRH|^~\&{}|||MFWG|ThM|C|bar|L|`
*   **`ZDH` (Dive Header)**：潛水元數據。
    *   欄位 6：開始時間，格式為 `YYYYMMDDHHMMSS` (如 `20180101101000`)。
    *   欄位 7：潛水時間（分鐘）。
    *   欄位 8：最大深度（公尺）。
*   **`ZDT` (Dive Time Sample)**：深度時間剖面樣本。
    *   欄位 4：相對於開始時間的秒數或分鐘數（取決於 ZRH 宣告的採樣率）。
    *   欄位 5：深度。
    *   欄位 6：水溫。

## 3. Swift 解析器設計建議

### 偵測邏輯 (canHandle)
```swift
func canHandle(filePath: String) -> Bool {
    let ext = (filePath as NSString).pathExtension.lowercased()
    guard ["zxu", "zxl", "dl7", "txt"].contains(ext) else { return false }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return false }
    guard let head = String(data: data.prefix(256), encoding: .utf8) else { return false }
    return head.hasPrefix("FSH|") && head.contains("ZXU")
}
```

### 關鍵欄位轉換 (Mapping)
1.  **資料按行解析**：
    Swift 讀取檔案時先利用 `components(separatedBy: .newlines)` 切割成行，再針對非空行用 `components(separatedBy: "|")` 切割欄位。
2.  **狀態機控制**：
    由於一個 DL7 檔案可能包含多個 ZDH 潛水活動以及對應的多個 ZDT 採樣，解析時應使用迴圈，當讀到 `ZDH` 時建立新的 `DiveLog` 實體，隨後讀取的 `ZDT` 均關聯到當前這個實體。
