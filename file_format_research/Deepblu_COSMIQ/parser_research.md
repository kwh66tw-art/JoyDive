# Deepblu COSMIQ+ 解析器研究

## 1. 檔案格式特徵
*   **格式類型**：JSON payload（從 Deepblu 雲端 API 取得）。
*   **副檔名**：`.json`

## 2. 結構特徵與欄位
Deepblu 潛水紀錄包含豐富的社交元數據與 GPS，主要由其藍牙 App 同步上傳至雲端。
*   關鍵欄位：`max_depth_meter`, `duration_second`, `start_time` (ISO 8601), `profile_points` (包含時間與深度的陣列)。

## 3. Swift 解析器設計建議
*   **偵測邏輯 (canHandle)**：
    檢查 JSON 中是否含有 `deepblu` 或 `cosmiq` 的欄位標記。
*   **解析邏輯**：
    可直接宣告 Swift `Decodable` 的 Struct，使用 `JSONDecoder` 進行解碼，將深度剖面點 `profile_points` 映射成 `DiveProfileSample` 數值。
