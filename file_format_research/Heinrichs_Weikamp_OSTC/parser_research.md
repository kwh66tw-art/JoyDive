# Heinrichs Weikamp OSTC 解析器研究

## 1. 檔案格式特徵
*   **格式類型**：開源二進位記憶體傾卸檔 (Raw EEPROM Binary Dump) 或直連串口協議。
*   **副檔名**：`.bin` 或 `.raw`

## 2. 結構特徵與解析方式
*   **硬體開放性**：Heinrichs Weikamp (OSTC) 是業界知名的開源潛水電腦，其韌體與通訊協議完全開源。
*   **Raw Bin 結構**：直接從 OSTC 下載下來的 `.bin` 檔案通常是潛電內部 EEPROM 的 raw 數據，內部按固定位元組偏移 (Byte Offsets) 紀錄潛水日誌清單、採樣點。由於隨不同韌體版本 (Firmware Versions) 的記憶體地圖 (Memory Map) 會改變，解析時需要對應特定韌體版本。

## 3. Swift 解析器設計建議

### 偵測邏輯 (canHandle)
```swift
func canHandle(filePath: String) -> Bool {
    let ext = (filePath as NSString).pathExtension.lowercased()
    return ext == "bin" || ext == "raw"
}
```

### 實作建議
*   **直接藍牙同步 (BLE)**：
    OSTC 支援藍牙直連。比起去解析多變的 `.bin` 快照，更建議在 JD2-Logbook 的 iOS/macOS App 中整合 `libdivecomputer` 的 Swift 封裝（如 `libdc-swift`），直接透過藍牙進行數據同步讀取。
*   **檔案匯入**：
    建議使用者使用 Subsurface 直讀 OSTC，再導出成 **UDDF** 進一步匯入 JD2。
