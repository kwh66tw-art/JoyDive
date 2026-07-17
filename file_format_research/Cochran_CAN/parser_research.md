# Cochran CAN 解析器研究

## 1. 檔案格式特徵
*   **格式類型**：Cochran 專有二進位數據格式。
*   **副檔名**：`.can`

## 2. 結構特徵與解析挑戰
Cochran 是極為老舊的潛水電腦品牌（如 Cochran Commander）。其 `.can` 檔案是純二進位 dump，沒有任何標籤與公開規格。

## 3. Swift 解析器設計建議
*   **偵測邏輯 (canHandle)**：
    檢查副檔名是否為 `.can`。
*   **解析路徑**：
    本格式在現代 Swift 中幾乎無法直接解析。目前全球僅有 `libdivecomputer` 庫對該格式進行了逆向工程。在專案不整合 `libdivecomputer` 二進位庫的前提下，必須要求使用者使用 Subsurface 轉存為 UDDF，JD2-Logbook 不應為此老舊格式單獨編寫 Swift Parser。
