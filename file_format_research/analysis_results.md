# Suunto D4i XML 匯入失敗分析與各大潛水日誌格式解析器研究總報告

## 🔍 問題根因

**JD2-Logbook 目前完全不支援 Suunto D4i 的 XML 匯出格式。**

App 現有的 Suunto 解析器 (`SuuntoJSONParser`) 只支援 **Suunto App 的 JSON 格式**（`DeviceLog` 結構），
而你的 D4i 檔案是 **Suunto DM5/DM4 的 WCF XML 序列化格式**，兩者結構完全不同。

---

## 📦 D4i 檔案格式分析

### 基本資訊

| 檔案 | 大小 | 最大深度 | 潛水時間 | 日期 |
|------|------|---------|---------|------|
| [Dive_2021-10-09-0902.xml](file:///Users/kevin/D4i_logs/Dive_2021-10-09-0902.xml) | 16 KB | 9.93 m | 428 s (7 min) | 2021-10-09 |
| [Dive_2026-06-03-0821.xml](file:///Users/kevin/D4i_logs/Dive_2026-06-03-0821.xml) | 40 KB | 23.88 m | 2269 s (38 min) | 2026-06-03 |
| [Dive_2026-06-03-0948.xml](file:///Users/kevin/D4i_logs/Dive_2026-06-03-0948.xml) | 37 KB | — | — | 2026-06-03 |
| [Dive_2026-06-04-0819.xml](file:///Users/kevin/D4i_logs/Dive_2026-06-04-0819.xml) | 37 KB | — | — | 2026-06-04 |

### XML 結構特徵

```xml
<Dive xmlns="http://schemas.datacontract.org/2004/07/Suunto.Diving.Dal"
      xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
  <Algorithm>2</Algorithm>
  <AvgDepth>15.76</AvgDepth>
  <BottomTemperature>28</BottomTemperature>
  <Duration>2269</Duration>
  <MaxDepth>23.88</MaxDepth>
  <Source>D4i</Source>
  <StartTime>2026-06-03T08:21:21</StartTime>
  <DiveMixtures>
    <DiveMixture>
      <Oxygen>30</Oxygen>   <!-- 百分比 (30 = EANx30) -->
      <Helium>0</Helium>
    </DiveMixture>
  </DiveMixtures>
  <DiveSamples>
    <Dive.Sample>
      <Depth>1.56</Depth>          <!-- 公尺 -->
      <Temperature>28.9999943</Temperature>  <!-- 攝氏 -->
      <Time>0</Time>               <!-- 秒 -->
    </Dive.Sample>
    ...
  </DiveSamples>
</Dive>
```

### 與現有解析器的差異比較

| 特徵 | Suunto D4i XML (你的檔案) | `SuuntoJSONParser` (現有) | `SubsurfaceXMLParser` (現有) |
|------|--------------------------|--------------------------|------------------------------|
| 格式 | XML | **JSON** | XML |
| 副檔名 | `.xml` | `.json` | `.ssrf` / `.xml` |
| 根元素 | `<Dive xmlns="...Suunto.Diving.Dal">` | `{ "DeviceLog": ... }` | `<divelog program='subsurface'>` |
| O₂ 單位 | **百分比** (30 = 30%) | 分率 (0.30) | 百分比字串 "32%" |
| 水溫單位 | **攝氏** (直接值) | Kelvin (需 -273.15) | 攝氏 |
| 日期格式 | `2026-06-03T08:21:21` (無時區) | ISO 8601 含毫秒+時區 | `2024-10-06 02:33` |
| 深度剖面 | `<DiveSamples>` / `<Dive.Sample>` | `Samples[].Depth/Time` | `<sample>` |
| 來源 | DM5 電腦同步/直傳 | Suunto App 匯出 | Subsurface 軟體匯出 |

---

## 🚫 為什麼匯入失敗

格式偵測流程 ([DiveLogImporterFactory.selectImporter](file:///Users/kevin/Documents/AppProject/JD2-Logbook/JD2-Logbook/JD2Core/Importers/DiveLogImporter.swift#L173-L177)) 逐一檢查所有解析器：

1. **SubsurfaceXMLParser** (priority 0) → `.xml` 副檔名 ✅ → 但檢查內容需含 `divelog` + `program='subsurface'` → ❌ **失敗**
2. **UDDFParser** (priority 1) → 只接受 `.uddf` → ❌ 跳過
3. **SHEARWATERParser** (priority 2) → `.xml` 副檔名 ✅ → 預設 `canHandle` 只看副檔名 → ⚠️ **可能誤匹配！**
4. **SuuntoJSONParser** (priority 4) → 只接受 `.json` → ❌ 跳過

> [!WARNING]
> 如果 SHEARWATER 的 `canHandle` 沒有內容檢查（目前只用預設的副檔名匹配），D4i XML 可能會被 **錯誤地交給 SHEARWATERParser**，然後該 parser 直接拋出 `unsupportedFormat` 異常。
>
> 如果所有 parser 都不匹配，ImportCoordinator 拋出 `unsupportedFormat` 錯誤。

---

## 📂 潛水日誌格式與解析器研究總表

此目錄下整理了 JD2-Logbook 尚未支援的主流潛水紀錄檔案格式研究。包含各格式的 XML/JSON/二進位/資料庫結構特徵，以及未來實作解析器 (Importer) 時的欄位映射與偵測邏輯。

> [!IMPORTANT]
> 為了開發與驗證的精確性，本目錄中歸檔的範例檔案均已明確標註其屬性：
> *   <span style="color: blue;">**[Real / 真機資料]**</span>：來自潛水電腦錶實機導出，或開源測試庫去識別化後的真實日誌。
> *   `[Mock / 模擬資料]`：由於原廠隱私保護或缺乏開源實體檔，此檔案為**依據官方規格與社群格式逆向建構的模擬資料**。

| 格式名稱 | 優先級 | 範例檔案屬性 | 下載來源 / Mock 原因說明 |
| :--- | :--- | :--- | :--- |
| **Suunto DM4 / DM5 XML** | Tier 1 (高) | <span style="color: blue;">**[Real / 真機資料]**</span> | 1. 來自使用者的 D4i 錶實機快取。<br>2. 下載自 [Subsurface 測試目錄](https://github.com/subsurface/subsurface/tree/master/dives)。 |
| **Shearwater XML** | Tier 1 (高) | **`[Mock / 模擬資料]`** | **Mock 原因**：實機 XML 導出包含潛水員個人 GPS 軌跡與手錶序號等隱私，公開社群僅分享轉檔 script。故依 `depthviz` 解析規則建構結構對照檔。 |
| **DAN DL7 (.dl7)** | Tier 1 (高) | <span style="color: blue;">**[Real / 真機資料]**</span> | 原始 `.zxu` 與對照 XML 下載自 [Subsurface 測試目錄](https://github.com/subsurface/subsurface/tree/master/dives)。 |
| **Suunto SML** | Tier 1 (高) | **`[Mock / 模擬資料]`** | **Mock 原因**：Moveslink 快取包含個人隱私資料，開源社群無釋出實體檔。故依 `openambit` 與 `pyambit` 解析規格模擬建構。 |
| **Garmin Connect JSON** | Tier 1 (高) | **`[Mock / 模擬資料]`** | **Mock 原因**：Garmin 官方備份 JSON 含有大量個人隱私與帳戶憑證。故依 Garmin Connect Activity API 的欄位定義模擬建構。 |
| **Divesoft DLF (.dlf)** | Tier 2 (中) | <span style="color: blue;">**[Real / 真機資料]**</span> | 真實 Freedom/Liberty 潛電二進位檔，下載自 [Subsurface 測試目錄](https://github.com/subsurface/subsurface/tree/master/dives)。 |
| **Scubapro SmartTrak (.slg)** | Tier 2 (中) | <span style="color: blue;">**[Real / 真機資料]**</span> | 真實 SmartTRAK 資料庫備份檔，下載自 [Subsurface 測試目錄](https://github.com/subsurface/subsurface/tree/master/dives)。 |
| **Suunto SDE (.sde)** | Tier 2 (中) | <span style="color: blue;">**[Real / 真機資料]**</span> | 真實 SDE 壓縮包（解壓後為 DM3 XML），下載自 [Subsurface 測試目錄](https://github.com/subsurface/subsurface/tree/master/dives)。 |
| **Mares Dive Organizer (.sdf)** | Tier 2 (中) | **`[Mock / 模擬資料]`** | **Mock 原因**：本格式為微軟封閉的 SQL Server Compact (.sdf) 二進位資料庫，跨平台讀取困難，社群極少釋出此格式原始檔。故以資料表欄位定義作對照。 |
| **Heinrichs Weikamp OSTC** | Tier 2 (中) | **`[Mock / 模擬資料]`** | **Mock 原因**：OSTC 記憶體 bin dump 與特定韌體版本高度綁定且多為無意義的 Hex，故建立二進位結構對照說明檔。 |
| **Cressi PC Interface** | Tier 3 (低) | **`[Mock / 模擬資料]`** | **Mock 原因**：Cressi 導出的純文字結構易隨傳輸軟體更新而失效，社群無提供穩定實體檔。故依 Leonardo 規格建構對照 TXT。 |
| **Ratio iDive** | Tier 3 (低) | **`[Mock / 模擬資料]`** | **Mock 原因**：Ratio 潛水活動無通用檔案格式，通常透過藍牙 BLE 串口直接傳輸數據。故建立傳輸數據包的結構對照說明檔。 |
| **Cochran CAN (.can)** | Tier 3 (低) | **`[Mock / 模擬資料]`** | **Mock 原因**：老舊潛電的 raw 二進位 dump 檔，無公開規格，社群亦無釋出實體檔。故建立 EEPROM 區段對照檔。 |
| **Deepblu COSMIQ+** | Tier 3 (低) | **`[Mock / 模擬資料]`** | **Mock 原因**：Deepblu App 同步之 API payload 含有個人雲端憑證隱私，故依 Deepblu JSON schema 欄位模擬建構。 |
| **Aqualung i-Trak** | Tier 3 (低) | **`[Mock / 模擬資料]`** | **Mock 原因**：官方軟體內部資料庫結構為專有且閉源，實機常透過藍牙 BLE 直連，故建立資料庫欄位對照說明檔。 |
| **APD LogViewer (.apd)** | Tier 3 (低) | **`[Mock / 模擬資料]`** | **Mock 原因**：技術潛水 CCR 專用二進位格式，無公開規範與範例，故建立二進位 profile 區塊結構說明檔。 |
| **Reefnet Sensus (.csv)** | Tier 3 (低) | <span style="color: blue;">**[Real / 真機資料]**</span> | 真實 Sensus CSV 採樣檔，下載自 [Subsurface 測試目錄](https://github.com/subsurface/subsurface/tree/master/dives)。 |
| **Diving Log 6.0 (.sql)** | Tier 3 (低) | <span style="color: blue;">**[Real / 真機資料]**</span> | 真實 SQL 資料庫導出檔，下載自 [Subsurface 測試目錄](https://github.com/subsurface/subsurface/tree/master/dives)。 |
| **ATMOS (UDDF & FIT)** | 特殊品牌 | <span style="color: blue;">**[Real / 真機資料]**</span> | 複製自專案本地的 `TestFiles/ATOMS/` 真實裝置導出之 UDDF 與二進位 FIT 檔。 |

---

## 📂 各格式詳細設計指南

### 第一階段：Tier 1 (高優先主流格式)
*   [Suunto DM5 XML 設計指南](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Suunto-DM5_XML/parser_research.md)
*   [Shearwater XML 設計指南](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Shearwater_XML/parser_research.md)
*   [DAN DL7 設計指南](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/DAN_DL7/parser_research.md)
*   [Suunto SML 設計指南](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Suunto_SML/parser_research.md)
*   [Garmin Connect JSON 設計指南](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Garmin%20Connect_JSON/parser_research.md)

### 第二階段：Tier 2 (中優先品牌專有格式)
*   [Divesoft DLF 設計指南](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Divesoft_DLF/parser_research.md)
*   [Scubapro SmartTrak 設計指南](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Scubapro_LogTRAK/parser_research.md)
*   [Suunto SDE / SDP 設計指南](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Suunto_SDE_SDP/parser_research.md)
*   [Mares Dive Organizer 設計指南](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Mares_Dive_Organizer/parser_research.md)
*   [Heinrichs Weikamp OSTC 設計指南](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Heinrichs_Weikamp_OSTC/parser_research.md)

### 第三階段：Tier 3 (低優先其他專有格式)
*   [Cressi PC Interface 設計指南](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Cressi_PC_Interface/parser_research.md)
*   [Ratio iDive 設計指南](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Ratio_iDive/parser_research.md)
*   [Cochran CAN 設計指南](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Cochran_CAN/parser_research.md)
*   [Deepblu COSMIQ+ 設計指南](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Deepblu_COSMIQ/parser_research.md)
*   [Aqualung i-Trak 設計指南](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Aqualung_iTrak/parser_research.md)
*   [APD LogViewer 設計指南](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/APD_LogViewer/parser_research.md)
*   [Reefnet Sensus 設計指南](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Sensus_Reefnet/parser_research.md)
*   [Diving Log 6.0 設計指南](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Diving_Log/parser_research.md)

### 特殊品牌擴充：ATMOS (Atmos Mission 潛電)
*   [ATMOS UDDF 與 FIT 設計指南](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Atmos/parser_research.md)
