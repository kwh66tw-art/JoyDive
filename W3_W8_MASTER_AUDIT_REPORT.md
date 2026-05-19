# JD2-Logbook 全域深度稽核總結報告 (W3-W8 Master Audit Report)

**日期**：2026-05-19
**稽核等級**：P0 (最高級別：涉及生命安全與核心邏輯破壞)
**稽核員**：首席技術架構師與品質稽核專家 (Agent)
**涵蓋範圍**：`DiveEngine.swift`, `Buhlmann.swift`, `AlgorithmConstants.swift`, 及其解析器

---

## 🛑 執行摘要 (Executive Summary)

經過針對系統核心的「地毯式語意與邏輯交叉比對」，確認目前 JD2-Logbook 的減壓與狀態機核心 **「無法安全上線」**。雖然 Bühlmann 數學公式（如組織半衰期與 NDL 解析解）本身的實作完全正確，但在將這些醫學理論拼裝為「即時狀態機 (State Machine)」與「商業邏輯」的過程中，產生了多處**互相矛盾、單位錯亂與死結**。

若不修正這些問題，潛水員將面臨：**無效的減壓指示、錯誤的氧中毒數據、以及隨時當機的介面狀態。**

---

## 🚨 核心邏輯矛盾與致死風險清單 (Critical Findings)

### 1. 單位錯亂導致 GF (梯度因子) 插值徹底崩潰
*   **出處**：`DiveEngine.swift` 與 `Buhlmann.swift`
*   **問題描述**：在觸發上升時，狀態機試圖鎖定第一天花板壓力：`buhlmann.firstCeilingBar = buhlmann.rawCeiling()`。
*   **矛盾點**：`firstCeilingBar` 預期接收「絕對壓力 (Bar)」，但 `rawCeiling()` 函式設計的回傳值卻是「深度 (Meters)」。
*   **醫學後果**：當 GF 公式 `(currentP - firstCeil)` 試圖將水壓 (例如 1.5 Bar) 減去水深 (例如 3.0 Meters) 時，數學邏輯崩壞，系統會給出完全錯誤的減壓停留時間或直接 Crash。

### 2. 40m 深度限制導致氮氣運算「強制停擺」 (N2 Loading Paused)
*   **出處**：`DiveEngine.swift` -> `tick()`
*   **問題描述**：使用了阻斷式條件 `if !hasDataGap && depth < HARD_DEPTH_LIMIT { buhlmann.update(...) }`。
*   **矛盾點**：40m 是「休閒潛水深度極限 (UI 警告極限)」，**絕對不是「物理運算極限」**。
*   **醫學後果**：潛水員超過 40m 後的所有時間，演算法會「停止更新組織壓力」。當潛水員回到 39m 時，演算法會無視剛才在深海吸收的大量高壓氮氣，給出致死級的樂觀 NDL。

### 3. CNS (中樞神經氧中毒) 公式違反 NOAA 醫學標準
*   **出處**：`DiveEngine.swift` -> `calculateCNS()`
*   **問題描述**：將 CNS 算式寫為瞬時比例 `(po2 - 0.5) / po2Threshold * 50.0`。
*   **醫學後果**：真正的 CNS 是**「時間與 PO2 的累積積分 (Oxygen Clock)」**。目前的寫法導致潛水員只要稍微上升（PO2 降低），CNS 就會瞬間歸零，完全忽略了過去累積的氧毒素，這是嚴重的醫學知識誤用。

### 4. 狀態機「單向死結」 (State Machine Deadlocks)
*   **出處**：`DiveEngine.swift` -> `determineState()`
*   **矛盾點 4.1 (Ascent 死結)**：一旦進入 `.ascent` 狀態，如果潛水員再度下潛，狀態機**沒有設定回到 `.diving` 的路徑**，永遠卡在上升狀態。
*   **矛盾點 4.2 (Decompression 死結)**：離開 `.decompression` 的條件是 `ceilingDepth <= 0 && depth < 1.0`。如果潛水員在 3m 解除了減壓天花板，他依然會被卡在 `.decompression` 狀態中，直到他浮出水面為止。這會導致 UI 呈現錯亂。

### 5. 安全停留 (Safety Stop) 觸發標準自相矛盾
*   **出處**：`AlgorithmConstants.swift` vs `DiveEngine.swift`
*   **問題描述**：常數定義 `safetyStopTriggerDepth = 6.0`。但在 `DiveEngine` 的 `.ascent` 分支中，卻檢查 `depth <= AlgorithmConstants.safetyStopValidMax` (值為 5.0m) 來觸發。
*   **後果**：造成「平游進入 6m」與「上升進入 6m」的行為分裂，令使用者困惑。

### 6. 上升與下潛警報誤判
*   **出處**：`DiveEngine.swift` -> `updateAscentWarnings()`
*   **問題描述**：使用了絕對值 `abs(ascentRateMpm) > ascentRateThreshold`。
*   **後果**：快速下潛（深度正向增加率高）時，`abs()` 也會大於閾值，導致潛水員明明在下沉，卻收到「上升過快」的瘋狂警報。

### 7. 潛水時間 (Dive Time) 計算提前凍結
*   **出處**：`DiveEngine.swift` -> `tick()` 結尾
*   **問題描述**：`if state == .diving { accumulatedDiveTime += deltaT }`
*   **後果**：只要潛水員不在 `.diving` 狀態（例如：安全停留、上升中、減壓中），他的總潛水時間就會**停止計時**！這會讓 Logbook 紀錄的時間遠低於真實下水時間。

---

## 🛠️ 重構與修復指南 (Action Items for Claude)

請將這份報告直接提交給實作工程師 (Claude)，並下達 **P0 優先級的重構指令**，執行以下修補：

1. **統一 GF 單位**：請修改 `Buhlmann.swift`，新增一個 `rawCeilingBar()` 函式回傳絕對壓力，或在 `DiveEngine` 中明確將 Meters 轉回 Bar。
2. **移除 40m 阻斷**：`buhlmann.update` 必須「無條件執行」，無論深度多少，組織壓力都必須持續吸收與代謝；40m 僅用於 UI Alert 的控制。
3. **實作真正的 Oxygen Clock**：重寫 `calculateCNS`。需加入 `accumulatedCNS` 變數，依據 NOAA 表格或對應公式，透過 `deltaT` 將每秒的 CNS 暴露百分比累加進去。
4. **修補狀態機漏洞**：在 `determineState` 補充所有反向轉移條件（例如從 `.ascent` 檢查若 `depth > prevDepth` 回到 `.diving`）。移除 `.decompression` 和 `.safetyStop` 必須小於 1.0m 才能退出的死胡同。
5. **移除 `abs()` 警報**：嚴格限制 `ascentRateMpm < -10.0` (依正負號定義) 才能觸發上升警告。
6. **全域時間累積**：只要狀態機不為 `.surface` 與 `.postDive`，`accumulatedDiveTime` 就必須推進。

> **結語**：本次全面稽核成功攔截了將導致 App 崩潰與潛水醫療事故的核心錯誤。演算法底子非常紮實，修復這些「管線與狀態機的接縫」後，系統即可達到世界級的安全水準。
