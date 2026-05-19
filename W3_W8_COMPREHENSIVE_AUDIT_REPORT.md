# W3-W8 程式碼與潛水醫學邏輯全面稽核報告 (Comprehensive Audit Report)

**日期**：2026-05-19
**稽核員**：首席技術架構師與軟體品質稽核專家 (Agent)
**稽核範圍**：`JD2Core` (Algorithm, Models, Constants, Importers)

---

## 1. 演算法與潛水醫學理論 (Bühlmann ZHL-16C)

### 1.1 組織隔室與半衰期 (Compartments & Half-times)
- **稽核結果：✅ 通過**
- **醫學依據**：採用標準 Bühlmann ZHL-16C 的 16 個隔室參數 (Half-times, a 係數, b 係數)，數值精確無誤。
- **組織初始壓力**：嚴格區分了 `AlgorithmConstants.fN2Air = 0.7902` (用於初始化組織) 與 `GasMix.air.fN2 = 0.79` (用於氣體加總)。這完全符合 Bühlmann 1983 年原著對於大氣中氮氣與微量氣體組合的定義。

### 1.2 Schreiner Equation (惰性氣體吸收/排出方程)
- **稽核結果：✅ 通過**
- **醫學依據**：完美實作了連續深度變化的 Schreiner 積分方程。
- **架構亮點**：在氣體切換 (Gas-switch) 時，使用了 `prevDepth` 計算 `Palv_initial`，防止 Schreiner 基線產生不合理偏移，物理意義與邊界條件處理非常優秀。

### 1.3 NDL 解析解 (No-Decompression Limit)
- **稽核結果：✅ 通過**
- **醫學依據**：當前 NDL 的計算透過反解 Schreiner 方程，求得組織達到 M-value (經 GF 調整) 的所需時間。
- **極端案例保護**：當 $P_{alv} < M_{value}$ 時，組織漸近線處於安全範圍，判定 NDL 為無限大 (回傳 `99+` 標記)。這是非常優雅且符合生理事實的處理方式（例如使用高氧氣體在淺水區）。

### 1.4 梯度因子 (Gradient Factors, GF)
- **稽核結果：✅ 通過**
- **醫學依據**：GF Low (0.40) 與 GF High (0.85) 的線性插值計算精準。
- **鎖定基線**：在 `DiveEngine` 觸發 `.ascent` (上升) 狀態時，鎖定了 `firstCeilingBar` 作為 GF 插值的下限深度，此舉完全符合 Erik Baker 的 GF 實作醫學規範。

---

## 2. 核心狀態機與安全警報 (DiveEngine)

### 2.1 潛水狀態流轉 (State Machine)
- **稽核結果：✅ 通過**
- **邏輯評估**：具備嚴謹的 6 階段狀態機。1.2m 下潛觸發、1.0m 結束潛水，並配有 3 分鐘的水面延遲 (Post-Dive Delay)，有效防止海面波浪造成的誤判 (Yo-yo dives 斷層)。

### 2.2 40m 絕對深度限制 (Critical Safety)
- **稽核結果：✅ 通過**
- **邏輯評估**：強制攔截深度大於 40m 的運算 (`depth >= HARD_DEPTH_LIMIT`)，強制 NDL 歸零並觸發警告，防止休閒潛水員暴露於極度危險的氮醉與高壓氧中毒風險。

### 2.3 安全停留 (Safety Stop)
- **稽核結果：✅ 通過**
- **邏輯評估**：觸發條件嚴密（最深深度 >= 10m，並在上升至 6m 觸發）。有效區間設為 3m-5m，暫停區間 5.1m-7.0m，持續 3 分鐘。此設定對齊主流高階潛水電腦錶 (如 Garmin, Shearwater) 的行為模式。

### 2.4 時間補償與熔斷機制 (Data Gap Handling)
- **稽核結果：✅ 通過**
- **邏輯評估**：針對硬體藍牙感測器可能斷線的情況，設計了 `maxCompensateTotalSec = 120.0` 與 `tickChunkSizeSec = 10.0`。這能確保感測器短暫斷線恢復後，組織壓力透過時間切片 (Time-Chunking) 補算，不會產生突變；大於 120 秒的斷線則觸發熔斷，避免提供錯誤的減壓資訊。

### 2.5 中樞神經系統氧中毒 (CNS % 計算) 🚨🚨
- **稽核結果：❌ 嚴重醫學邏輯缺陷 (Critical Defect)**
- **問題描述**：目前 `calculateCNS(po2: Double)` 的實作為純粹的比例換算 `(po2 - 0.5) / po2Threshold * 50.0`。
- **醫學依據**：CNS 氧中毒累積**必須基於時間與 PO2 的積分 (Oxygen Clock)**，並依據 NOAA (National Oceanic and Atmospheric Administration) 的 CNS 暴露極限表。目前的寫法沒有「累積」概念，只要潛水員上升、PO2 下降，CNS 就會瞬間歸零。這在潛水醫學上是非常危險的錯誤。

---

## 3. 日誌解析模組 (Importers & Parsers)

### 3.1 基礎架構 (DiveLogImporter)
- **稽核結果：✅ 通過**
- **邏輯評估**：Protocol 設計與 Factory 模式解耦良好。針對檔案驗證 (Magic bytes, XML Prefix) 的實作效率極高，沒有記憶體洩漏與 OOB 越界風險。

### 3.2 第三方格式支援 (Garmin, UDDF, Suunto)
- **稽核結果：⚠️ 需修正 (Week 7 遺留問題)**
- **問題描述**：`GarminDescentParser` 對 `FitFileParser` 套件的 `valueUnit?.value` 有不當依賴，導致測試全滅（請參閱前一份 `AUDIT_WEEK7_FIT_PARSER.md`）。其餘 Subsurface XML, CSV, Suunto JSON 邏輯穩固且具有良好的容錯性。

---

## 4. 總結與核心修復方針 (Action Items)

| 模組 | 嚴重度 | 缺陷描述 | 修復要求 |
|------|--------|----------|----------|
| **DiveEngine** | 🚨 **Critical** | CNS 氧中毒計算無時間積分，違反 NOAA 醫學標準。 | **必須重構** `calculateCNS`。需引入 NOAA 查表或對應公式，利用 `deltaT` 與目前的 `PO2` 對 CNS 進行全域累積，且在水面需有半衰期衰減機制（通常為 90 分鐘）。 |
| **GarminParser** | 🚨 **High** | FIT 解析器取值崩潰 (W7 測試失敗主因)。 | 捨棄 `valueUnit` 依賴，落實 `interpretedFields()` 的 Debug 輸出後修正。 |

> **首席稽核員總評**：
> 專案在 ZHL-16C 減壓理論與狀態機的實作上達到了**極高的工業與學術水準**，邏輯嚴密且效能優異。然而，在 **CNS 氧中毒計算**上出現了致命的醫學邏輯誤判。請優先指令 Claude 重構 CNS 演算法，以符合潛水安全底線。
