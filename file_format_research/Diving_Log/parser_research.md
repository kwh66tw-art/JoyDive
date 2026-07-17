# Diving Log 6.0 資料庫解析器研究

## 1. 檔案格式特徵
*   **格式類型**：Diving Log 6.0 備份或導出的 SQL / Access / SQLite 檔案。
*   **副檔名**：`.sql`, `.db`, `.mdb`
*   **範例檔案**：
    *   [TestDivingLog4.1.1.sql](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Diving_Log/TestDivingLog4.1.1.sql) (真實資料，Diving Log SQL 導出檔)

## 2. 結構特徵與解析方式
*   **SQL/Access 結構**：Diving Log 6.0 會在資料庫中儲存 `Logbook`、`Place`、`Buddy` 等多個關聯資料表。
*   **二進位 Profile**：深度剖面數據在舊版 Access 裡通常以二進位或特定字串序列化儲存。

## 3. Swift 解析器設計建議

### 偵測邏輯 (canHandle)
```swift
func canHandle(filePath: String) -> Bool {
    let ext = (filePath as NSString).pathExtension.lowercased()
    return ["sql", "db", "mdb"].contains(ext)
}
```

### 解析建議
與其在 Swift App 中編寫複雜的 SQLite 多表查詢與資料還原（尤其是處理複雜的 profile blob 數據），強烈建議引導 Windows 用戶在 Diving Log 6.0 中使用 **"Export -> UDDF"** 功能。UDDF 格式包含了所有的潛水日誌與完整 profile 數據，JD2-Logbook 藉此即可實現完美相容。
