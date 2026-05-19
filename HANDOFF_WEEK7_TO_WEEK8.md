# 交接文件 — Week 7 → Week 8
## JD2-Logbook 項目 | 2026-05-19

---

## 🎯 專案狀態摘要

**完成時間**: 2026-05-19  
**PM 累積投入**: ~44 小時（Week 1-7 估算）  
**計畫剩餘**: Week 8–12（約 36 小時）  
**編譯狀態**: ✅ Build Succeeded（Xcode，iPhone 16 模擬器）  
**最新 Git commit**: `55ac354` Week 7: GarminDescentParser 改用 roznet/FitFileParser SPM  
**分支**: main  
**測試狀態**: ✅ 31/31 GarminFITParserTests 全綠（+ 所有前週測試）

---

## ✅ Week 7 完成項目

### GarminDescentParser 重構（SPM 版）

**問題背景**：
- Week 7 初版為 224 行純 Swift FIT binary loop，PM 要求改用 SPM 套件
- 調查確認 `FitDataProtocol v2.1.2` 無 DiveSummaryMessage / DiveGasMessage，不適用
- 評估 `deepsealabs/fit-parser-swift`（3 stars，單一貢獻者，成熟度不足，否決）
- 選定 `roznet/FitFileParser`（40 stars，官方 Garmin C SDK 封裝，生產驗證）

**技術細節**：
- **SPM 套件**：`roznet/FitFileParser` v1.5.2（FitSDK 21.115）
- **解析模式**：`.generic`（`.fast` 模式不解析 dive_summary/dive_gas）
- **FitMessageType**：`UInt16` typealias，dive-specific 訊息用 raw mesg_num 查詢
  - `session`：`.session`（有具名常數）
  - `dive_summary`：`268`（GMN 直接傳入）
  - `dive_gas`：`269`（GMN 直接傳入）
- **欄位存取**：`interpretedField(key: "…")?.valueUnit?.value`（無 raw byte 運算）
- **diveTimeSeconds**：`Int(elapsedSecs)` 截斷（對應 FIT SDK integer division 語義）
  - total_elapsed_time 實際值：3514.748s → `Int(3514.748) = 3514` ✓
- **FIT epoch 轉換**：FitFileParser 自動處理（直接回傳 `Date`）
- **magic bytes 驗證**：保留 Data subscript 存取（4 bytes，非 parser 邏輯）

**欄位 mapping 驗證（debug 輸出確認）**：
```
Session key: start_time      → FitField(withTime: 2018-08-11 07:56:30 +0000) ✓
Session key: total_elapsed_time → FitField(withValue: 3514.748, andUnit: s) ✓
Summary key: max_depth       → FitField(withValue: 27.022, andUnit: m) ✓
diveSummaries.count          → 2（lap-level + session-level，index 0 正確）
diveGases.count              → 0（測試檔案無 GMN 269，預設 Air）
```

**bonus 發現（可 Week 8 強化）**：
- Session 含 GPS：`start_position`（lat/lng）和 `end_position` → 未來可填 location
- Session 含水溫：`avg_temperature = 29.0°C`、`min_temperature = 29.0°C` → 未來可取代預設 15.0°C

**測試**：
- 測試檔案：`JD2-LogbookTests/GarminFITParserTests.swift`（31 XCTests，新建）
- 測試資料：`TestFiles/Garmin/`（3 個 Garmin Descent MK1 .fit 檔，2018 地中海）
- 全部通過：canHandle / parse / maxDepth / diveTime / startTime / gasMixJSON / location / waterTemperature / 錯誤處理 / 工廠偵測

**Commit 紀錄**：
- `55ac354` Week 7: GarminDescentParser 改用 roznet/FitFileParser SPM

---

## ✅ Week 3–6 累積完成（延續自上一份交接文件）

| Week | 解析器 | Commit | 測試數 |
|------|--------|--------|--------|
| W3 | UDDFParser | 31d37d8 + 76033ef | 27 |
| W4 | SubsurfaceXMLParser | 41f867a + dfcc4af | 42 |
| W5 | ShearwaterParser + PeregrineParser | （見 W6 to W7） | 各若干 |
| W6 | SubsurfaceCSVParser + SuuntoJSONParser + OceanicParser | dc5b826 | 累計 |
| W7 | GarminDescentParser | 55ac354 | 31 |

---

## 📁 關鍵檔案位置

```
JD2-Logbook/
├── JD2-Logbook/
│   └── JD2Core/
│       └── Importers/
│           └── DiveLogImporter.swift          ← 所有解析器（含 GarminDescentParser）
├── JD2-LogbookTests/
│   ├── GarminFITParserTests.swift             ← Week 7 新增（31 tests）
│   └── TestFiles/
│       └── Garmin/
│           ├── 2018-08-11-09-56-30.fit        ← maxDepth=27.022m, 3514s
│           ├── 2018-08-11-14-11-36.fit        ← maxDepth=20.628m, 3929s
│           └── 2018-08-13-13-48-26.fit        ← maxDepth=15.230m, 4145s
└── JD2_12WEEK_FINAL_PLAN.md
```

---

## 🔧 Week 8 任務（Tech Debt + 第二格式）

### 必做
1. **Tech Debt — deduplicateDives 整合**（Week 6 TODO）
   - 目前各解析器未呼叫去重邏輯
   - 需在 import pipeline 加入 `deduplicateDives()`

2. **Tech Debt — N+1 Save 優化**
   - 目前逐筆 save，需改為批次

3. **Performance Tests**
   - 大量 import 的效能基線測試

### 建議強化（bonus，若時間允許）
4. **GarminDescentParser 水溫**：從 session `avg_temperature` 取代預設 15.0°C
   - 注意：測試 `testParseFile1_WaterTemperature_IsDefault` 目前期望 15.0，需同步更新測試
5. **GarminDescentParser GPS**：從 session `start_position` 填入 location 欄位

### 第二個新格式（Week 8 本週任務）
- 依 `JD2_12WEEK_FINAL_PLAN.md` 指定格式執行
- 請 PM 提供測試樣本檔案

---

## ⚠️ 已知問題與注意事項

1. **DiveEngine.swift 警告**（2 個 ⚠️，Week 7 前已存在）：
   - `Call to main actor-isolated initializer 'init(environment:)' in a synchronous nonisolated context`
   - `Main actor-isolated static property 'seaLevel' can not be referenced from a nonisolated`
   - 非 Week 7 引入，Week 8 可選擇性處理

2. **git lock 衝突**：Xcode Source Control 與 sandbox git 同時操作時會產生 lock 衝突
   - 解法：從 Mac Terminal 刪除 `.git/index.lock` 和 `.git/HEAD.lock` 後重新 commit

3. **FitFileParser .generic 模式**：解析速度略慢於 .fast，但資料完整性要求下無法避免

---

## 🏗️ GarminDescentParser 架構摘要（給接手工程師）

```swift
// 依賴：import FitFileParser（roznet/FitFileParser SPM）
struct GarminDescentParser: DiveLogImporter {
    // canHandle：.fit 副檔名 + magic bytes [8..11] = ".FIT"
    // validateContent：同上，對 Data 驗證
    // parse：
    //   1. fileNotFound → 2. corruptedData（<14 bytes）→ 3. invalidFormat（magic 不符）
    //   4. FitFile(data: rawData, parsingType: .generic)
    //   5. messages(forMessageType: .session)        → sessions
    //      messages(forMessageType: 268)             → diveSummaries
    //      messages(forMessageType: 269)             → diveGases
    //   6. per session：start_time / total_elapsed_time / max_depth / gasMixJSON
    //   7. waterTemperature = 15.0（預設，session.avg_temperature 可替換）
    //   8. location = ""（session.start_position 可替換）
}
```
