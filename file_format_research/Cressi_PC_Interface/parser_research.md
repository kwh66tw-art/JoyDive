# Cressi PC Interface 解析器研究

## 1. 檔案格式特徵
*   **格式類型**：Cressi Leonardo/Giotto 等潛水手錶官方傳輸軟體導出的 `.txt` 或 `.csv` / `.html` 文字格式。
*   **副檔名**：`.txt`, `.csv`

## 2. 結構特徵與解析挑戰
Cressi 的 PC Interface 軟體沒有統一的標準 XML 或 JSON，通常是結構鬆散的純文字或 CSV 格式。
*   **Metadata**：包含潛水日期、最大深度、總時間。
*   **Profile**：以純文字行記錄時間點的深度。

## 3. Swift 解析器設計建議
*   **偵測邏輯 (canHandle)**：
    檢查文字首部是否包含 `"Cressi"`、`"Leonardo"` 或 `"Giotto"` 字樣。
*   **解析與遷移路徑**：
    因為 Cressi 導出的純文字結構不穩定（易隨 PC 軟體更新而改變），最穩健的解析方案是建議使用者直接將 Cressi 電腦錶連接到 **Subsurface**（Subsurface 原生支援 Cressi 直連下載），再從中導出成 UDDF XML，再載入至 JD2-Logbook。
