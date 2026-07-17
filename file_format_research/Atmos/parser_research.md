# ATMOS 潛水電腦解析器研究 (Atmos Mission One / Two / Three)

ATMOS 系列電腦錶支援以下兩種資料匯出與同步格式。JD2-Logbook 可以透過相應的實作或擴展模組對其進行完整支援。

---

## 1. ATMOS UDDF 格式 (.uddf)

### 格式說明
ATMOS 手錶官方 App 目前最主要的資料導出格式為 **UDDF (Universal Dive Data Format)**，這是基於 XML 的開源潛水資料交換標準。

### 範例檔案 (真機實測)
*   [ATMOS_Export_20260604155809.uddf](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Atmos/ATMOS_Export_20260604155809.uddf) —— **`[Real Data / 真機資料]`**，Atmos App 導出的真實潛水日誌，含有經去識別化後的完整深度採樣點。

### Swift 相容與整合方案
專案中已有完整實作的 **`UDDFParser`**。
*   **整合動作**：
    我們不需要為 ATMOS UDDF 單獨建立新的解析器！只需將 ATMOS App 導出的 `.uddf` 檔案直接送入現有的 `UDDFParser` 即可完美無縫解析。

---

## 2. ATMOS FIT 格式 (.fit)

### 格式說明
ATMOS 裝置在與電腦透過 USB 連接時，其內部儲存的日誌與 Garmin 相同，使用的是 **FIT (Flexible and Interoperable Data Transfer)** 二進位格式。

### 範例檔案 (真機實測)
*   [dive_202605311803.fit](file:///Users/kevin/Documents/AppProject/JD2-Logbook/file_format_research/Atmos/dive_202605311803.fit) —— **`[Real Data / 真機資料]`**，Atmos 錶內導出的真實二進位 FIT 潛水軌跡檔。

### Swift 相容與整合方案
由於 `GarminDescentParser` 底層使用的是強大的 `FitFileParser`（ roznet/FitFileParser），它本質上能夠解析**任何**符合標準 FIT 規格的二進位檔案。為了支援 ATMOS，只需在 Garmin 解析器中移除嚴格的 Garmin 製造商識別碼檢查，即可使其成為通用 FIT 解析器，直接無縫讀取此 ATMOS FIT 檔。
