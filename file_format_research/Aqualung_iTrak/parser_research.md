# Aqualung i-Trak 解析器研究

## 1. 檔案格式特徵
*   **格式類型**：Aqualung 官方日誌軟體內部的資料庫格式。
*   **主要硬體**：i200C, i300C, i330R, i770R 等 Aqualung 藍牙手錶。

## 2. 解析器設計建議
*   **藍牙直連 (BLE)**：
    對於 Aqualung 手錶，最成熟的方案是在 JD2-Logbook App 中直接使用 iOS CoreBluetooth 連接手錶，依循 Aqualung 的傳輸協定下載數據。
*   **中介格式**：
    檔案層面上，應引導使用者利用 Subsurface 直連下載，再轉存為 UDDF 匯入。
