# APD LogViewer (.apd) 解析器研究

## 1. 檔案格式特徵
*   **格式類型**：APD (Ambient Pressure Diving) 循環呼吸器 (CCR) 的二進位日誌格式。
*   **副檔名**：`.apd`

## 2. 結構特徵與技術指標
*   **二進位結構**：主要儲存高頻率的 ppO2 感測器數據（如三個 O2 電芯的電壓值與 ppO2）、稀釋氣 (Diluent) 與氧氣殘壓。
*   **解析挑戰**：這是技術潛水 CCR 專用的特殊二進位檔。

## 3. Swift 解析器設計建議
*   **偵測邏輯 (canHandle)**：
    檢查副檔名是否為 `.apd`。
*   **設計建議**：
    JD2-Logbook 屬於休閒潛水主導的日誌 App，若要直接解析 APD CCR 的二進位 profile，需要編寫複雜的二進位位元偏移解析。建議引導技術潛水員使用 Subsurface（內建 APD 模組）將數據轉存成帶有多個氣體/ppO2 採樣點的 UDDF，再匯入 JD2。
