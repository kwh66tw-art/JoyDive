# Suunto SDE / SDP 解析器研究

## 1. 檔案格式特徵
*   **格式類型**：SDE 實質上是一個 **ZIP 壓縮包**，解壓後內含一到多個標準 XML 檔案（通常命名為 `0.xml`, `1.xml` 等）。
*   **副檔名**：`.sde` 或 `.sdp` (SDP 通常為 DM5 的專案設定檔)
*   **範例檔案**：
    *   [TestDiveDM3.SDE](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Suunto_SDE_SDP/TestDiveDM3.SDE) (真實資料，DM3 導出 SDE 檔)

## 2. 解壓後的 XML 結構
解壓 SDE 得到的 `0.xml` 採用 Suunto DM5 相同的 WCF XML 序列化格式（`xmlns="http://schemas.datacontract.org/2004/07/Suunto.Diving.Dal"`）：
```xml
<Dive xmlns="http://schemas.datacontract.org/2004/07/Suunto.Diving.Dal">
    <MaxDepth>24.5</MaxDepth>
    ...
</Dive>
```

## 3. Swift 解析器設計建議

### 偵測邏輯 (canHandle)
由於 SDE 是 ZIP，其前 4 個 bytes 會是 ZIP 的 Magic Header `PK\x03\x04` (`[0x50, 0x4B, 0x03, 0x04]`)：
```swift
func canHandle(filePath: String) -> Bool {
    let ext = (filePath as NSString).pathExtension.lowercased()
    guard ext == "sde" else { return false }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)), data.count >= 4 else { return false }
    // 檢查 ZIP magic bytes
    return data.prefix(4).elementsEqual([0x50, 0x4B, 0x03, 0x04])
}
```

### 解析方案
在 Swift 中，解析 `.SDE` 的流程如下：
1.  **第一步：解壓縮**。在 macOS 環境下可使用系統 `/usr/bin/unzip` 指令（透過 `Process` 執行），或者在 iOS 使用 `ZipFoundation` 庫解壓。
2.  **第二步：呼叫 DM5 XML 解析器**。將解壓出來的 `0.xml` 送入 `SuuntoDM5XMLParser` 進行資料提取。這可以實現程式碼的最大化複用。
