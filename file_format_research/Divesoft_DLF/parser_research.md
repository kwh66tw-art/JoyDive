# Divesoft Freedom / Liberty DLF 解析器研究

## 1. 檔案格式特徵
*   **格式類型**：Divesoft 專有二進制日誌檔格式 (Binary log file)。
*   **副檔名**：`.dlf`
*   **範例檔案**：
    *   [Freedom_MIX2_header_v2_00000007.dlf](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Divesoft_DLF/Freedom_MIX2_header_v2_00000007.dlf) (真實資料，Divesoft Freedom)
    *   [Liberty_CCR_header_v1_00000011.dlf](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Divesoft_DLF/Liberty_CCR_header_v1_00000011.dlf) (真實資料，Divesoft Liberty CCR)

## 2. 結構特徵與二進位規範
Divesoft 官方對於開發者社群較為友善，提供了二進位結構的對照表。一般解析器會包含：
*   **Header 區塊**：前數百個 bytes，包含潛水電腦型號 (Freedom/Liberty)、硬體序號、軟體版本。
*   **潛水統計區塊**：包含最大深度 (Max Depth)、潛水持續時間 (Duration)、氣體切換設定。
*   **Profile 數據點**：通常以二進位區塊 (Binary Blob) 保存。

## 3. Swift 解析器設計建議

### 偵測邏輯 (canHandle)
```swift
func canHandle(filePath: String) -> Bool {
    let ext = (filePath as NSString).pathExtension.lowercased()
    guard ext == "dlf" else { return false }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)), data.count > 128 else { return false }
    // 檢查 DLF 的二進位 Magic Header 特徵字元
    let headerStr = String(decoding: data.prefix(16), as: UTF8.self)
    return headerStr.lowercased().contains("divesoft")
}
```

### 解析邏輯 (參考開源實作)
*   **參考專案**：[DiveWithDamian/divesoft-parser (GitHub)](https://github.com/DiveWithDamian/divesoft-parser) 提供了一個 Python 的 `DLFDecoder` 參考。
*   **設計建議**：
    在 Swift 中，可以使用 `FileHandle` 或 `Data` 的二進位 Subdata 切割。配合 `withUnsafeBytes` 來讀取 `UInt32` 或 `Float` 的二進位數值。
    1.  注意 Endianness（大部分潛電使用 Little Endian，須以 `.littleEndian` 進行數字還原）。
    2.  讀取 Profile 區塊時，按照設定的採樣間隔（如 1s 或 2s）逐個 block 讀取深度與溫度。
