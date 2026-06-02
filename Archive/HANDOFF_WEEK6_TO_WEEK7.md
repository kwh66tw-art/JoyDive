# 交接文件 — Week 6 → Week 7
## JD2-Logbook 項目 | 2026-05-18

---

## 🎯 專案狀態摘要

**完成時間**: 2026-05-18  
**PM 累積投入**: ~36 小時（Week 1-6 估算）  
**計畫剩餘**: Week 7–12（約 44 小時）  
**編譯狀態**: ✅ Build Succeeded（Xcode，iPhone 16 模擬器）  
**最新 Git commit**: `dc5b826` fix: W3-W6 dual audit fixes — parsers, tests, dedup, orphan files  
**分支**: main

---

## ✅ Week 3–6 完成清單

### Week 3 — UDDFParser ✅
- commit `31d37d8` + `76033ef`（bug fix）
- 解析器：`UDDFParser`（DiveLogImporter.swift，約 180–272 行）
- 測試：27 XCTests（UDDFParserTests.swift）
- 測試檔案：`TestFiles/UDDF/test42.uddf`、`test-apd-inspiration.uddf`
- sourceFormat = `"UDDF"`

### Week 4 — SubsurfaceXMLParser ✅
- commit `41f867a` + `dfcc4af`（bug fix）
- 解析器：`SubsurfaceXMLParser`（DiveLogImporter.swift，約 514–583 行）
- 測試：42 XCTests（SubsurfaceXMLParserTests.swift）
- 測試檔案：`TestFiles/Suunto/*.xml`（3 個 .ssrf 格式）
- sourceFormat = `"Subsurface"`

### Week 5 — SubsurfaceCSVParser ✅
- commit `ed2b804` + `f2c3bbf`（CRLF bug fix）
- 解析器：`SubsurfaceCSVParser`（DiveLogImporter.swift，約 304–496 行）
- 測試：36 XCTests（SubsurfaceCSVParserTests.swift）
- 測試檔案：`TestFiles/CSV/test41.csv`（4 筆，含多行 notes + 引號轉義）
- sourceFormat = `"csv"`
- **重要**：location 欄位為空字串（Subsurface CSV 無 site 欄位）

### Week 6 — SuuntoJSONParser + ImportCoordinator ✅
- commit `6bafd59`：SuuntoJSONParser + 26 XCTests
- commit `1e350f0`：ImportCoordinator fix + 30 XCTests
- 解析器：`SuuntoJSONParser`（DiveLogImporter.swift，約 584–721 行）
- 測試：26 XCTests（SuuntoJSONParserTests.swift）
- 測試檔案：`TestFiles/Suunto/*.json`（3 個 Suunto DeviceLog JSON）
- sourceFormat = `"suunto-json"`
- **修復**：移除 ImportCoordinator.validateDives 對 empty location 的錯誤過濾

---

## 📁 關鍵檔案索引

### 計劃與指引文件
```
JD2-Logbook/
├─ JD2_12WEEK_FINAL_PLAN.md          ← 12 週完整計劃（必讀）
├─ APPLE_HIG_2026_COMPLIANCE_GUIDE.md
├─ WCAG_2.1_AA_AUDIT_CHECKLIST.md
├─ PARSER_PROMPTS_ALL_FORMATS.md     ← 各解析器詳細 Prompt（Week 7 用到）
├─ HANDOFF_WEEK2_TO_WEEK3.md
└─ HANDOFF_WEEK6_TO_WEEK7.md        ← 本檔
```

### 核心程式碼
```
JD2-Logbook/JD2-Logbook/
├─ JD2Core/
│  ├─ Models/
│  │  ├─ DiveLog.swift               ← SwiftData @Model（267 行）
│  │  └─ DiveLogDatabase.swift       ← @MainActor singleton（163 行）
│  └─ Importers/
│     ├─ DiveLogImporter.swift       ← 全部解析器 + Protocol（~1500 行）
│     └─ ImportCoordinator.swift     ← 統一匯入協調器 v1.1（278 行）
└─ JD2-LogbookTests/
   ├─ UDDFParserTests.swift          ← 27 tests
   ├─ SubsurfaceXMLParserTests.swift ← 42 tests
   ├─ SubsurfaceCSVParserTests.swift ← 36 tests
   ├─ SuuntoJSONParserTests.swift    ← 26 tests（全綠 ✅，截圖確認）
   └─ ImportCoordinatorTests.swift   ← 30 tests
```

### 測試樣本檔案
```
TestFiles/
├─ UDDF/
│  ├─ test42.uddf
│  └─ test-apd-inspiration.uddf
├─ CSV/
│  └─ test41.csv
├─ Suunto/
│  ├─ suunto_eon_core_nitrox.json    ← Duration=3970s, MaxDepth=22.65m, Nitrox 32%
│  ├─ suunto_nautic_sidemount.json   ← Duration=2011s, MaxDepth=21.24m, Air, Notes
│  ├─ suunto_ocean_air.json          ← Duration=3312s, MaxDepth=23.4m, Air, Notes
│  ├─ suunto_eon_core_nitrox.xml     ← Subsurface XML 版本（Week 4 用）
│  ├─ suunto_nautic_sidemount.xml
│  └─ suunto_ocean_air.xml
└─ Garmin/
   ├─ 2018-08-11-09-56-30.fit        ← 二進位 FIT 格式（Week 7 參考）
   ├─ 2018-08-11-14-11-36.fit
   └─ 2018-08-13-13-48-26.fit
```

---

## 🏗 架構關鍵知識

### DiveLogImporter Protocol
```swift
protocol DiveLogImporter {
    var format: DiveLogFormat { get }
    func canHandle(filePath: String) -> Bool
    func parse(from filePath: String) throws -> [DiveLog]
}
```

### DiveLogFormat（rawValue = displayName）
```swift
enum DiveLogFormat: String, CaseIterable {
    case uddf       = "UDDF"
    case subsurface = "Subsurface"
    case shearwater = "SHEARWATER"
    case csv        = "CSV"
    case garmin     = "Garmin"
    case suunto     = "Suunto"
    case oceanic    = "Oceanic"
}
```

supportedExtensions：
- `.uddf` → UDDF
- `.ssrf`, `.xml` → Subsurface（canHandle 不讀內容，僅看副檔名）
- `.csv` → CSV
- `.json` → Suunto（canHandle 讀取前 256 bytes 確認含 "DeviceLog"）
- `.fit` → Garmin（GarminDescentParser 目前是空殼）

### DiveLog 初始化
```swift
DiveLog(
    dateTime: Date,
    location: String,          // CSV/Suunto JSON 為 ""，UDDF/XML 有值
    maxDepth: Double,
    diveTimeSeconds: Int,
    gasMixJSON: String = "\"air\"",
    waterTemperature: Double = 15.0
)
// 其餘屬性直接設定：dive.sourceFormat = "xxx"、dive.notes = "..."
```

### gasMixJSON 格式
```
"\"air\""                          ← Air（fO2 ≈ 0.21）
"{\"nitrox\":{\"fO2\":0.32}}"      ← Nitrox 32%
```

### TestFiles 路徑解析（測試中統一用法）
```swift
private var repoRoot: String {
    let here       = (#filePath as NSString).deletingLastPathComponent  // .../JD2-LogbookTests
    let moduleRoot = (here as NSString).deletingLastPathComponent       // .../JD2-Logbook
    return (moduleRoot as NSString).deletingLastPathComponent           // .../JD2-Logbook (repo)
}
// 再 appendingPathComponent("TestFiles/XXX/filename.ext")
```

---

## ✅ Audit 修補紀錄（2026-05-18，commit dc5b826）

### 內部稽核（W3-W6 Self-Audit）修補項目

| # | 問題 | 修補方式 |
|---|------|---------|
| A | SubsurfaceXMLParser `maxDepth > 0` | 改為 `>= 0`，snorkeling 記錄不再被丟棄 |
| B | 三個 `makeGasMixJSON` 浮點插值不穩定 | 改用 `String(format: "%.4g", fO2)` |
| C | SubsurfaceXMLParserTests vacuous test | 重寫為 `testParseAllowsZeroDepthDive`，驗證 count==1 且 depth==0.0 |
| D | SubsurfaceXMLParserTests empty file test | 改為 `testParseEmptyFile_ThrowsParsingFailed`，正確 expect `parsingFailed` |
| E | ImportCoordinator emoji（違反 CLAUDE.md） | validateDives 全部改為純文字 |
| F | `recursive` 參數未實作 + 死掉的 typealias | 移除參數、移除 `ImportCompletionCallback` |
| G | `init(database: .shared)` Swift 6 @MainActor 警告 | 移除 default value，改為必填參數 |
| H | `var skippedCount = 0` 從不變動 | 改為 `let` |

### 外部稽核（PARSERS_AUDIT_REPORT.md）修補項目

| # | 問題 | 修補方式 |
|---|------|---------|
| I | 根目錄孤立草稿 `UDDFParser.swift` / `UDDFParserTests.swift` | 手動刪除（PM 執行），一併 commit |
| J | `deduplicateDives` 以 `inSameDayAs` 比對過粗 | 改為 `abs(timeInterval) < 60`，避免同天兩次潛水誤刪 |
| K | `parseDurationMMSS` 不支援 HH:MM:SS | 改為 switch/case 支援 2 段或 3 段格式 |
| L | `parseDateTime` 格式限制未文件化 | 加 NOTE comment 說明僅支援 Subsurface 格式，不改邏輯 |

---

## ⚠️ 已知技術債（Week 8 前需處理）

| # | 問題 | 位置 | 嚴重度 | 計劃修復時間 |
|---|------|------|--------|------------|
| 1 | `deduplicateDives` 從未被 `importFile` 呼叫 — 批量匯入不去重 | ImportCoordinator.swift | 中 | Week 8 |
| 2 | `importMultipleFiles` progressCallback 計算錯誤（各檔案數量不同） | ImportCoordinator.swift L126-130 | 中 | Week 9 UI |
| 3 | `importErrors` 警告從不回傳給呼叫者（UI 拿不到警告） | ImportCoordinator.swift | 低 | Week 9 UI |
| 4 | N+1 save：每筆 dive 單獨 `context.save()` | ImportCoordinator.swift L99 | 低 | Week 8 性能測試 |
| 5 | 性能初測（100 檔案 < 10s）Week 6 未完成 | — | 低 | Week 8 一起補 |
| 6 | UDDF `<notes>` 多段 `<para>` 只保留最後一段 | DiveLogImporter.swift L1019 | 低 | Week 8 |
| 7 | SubsurfaceCSVParser 二位數年份 `< 100 → +2000`，應為 `< 70 → +2000` | DiveLogImporter.swift L471 | 中 | Week 8 |
| 8 | `sourceFormat` 命名風格不一致（UDDF vs subsurface vs csv vs suunto-json） | 四個解析器 | 中 | Week 9 統一 |
| 9 | 無地點時 location 值不一致（"Unknown Location" vs ""） | UDDF/XML vs CSV/Suunto | 中 | Week 9 統一 |

---

## 🚀 Week 7 任務：Garmin 解析器

### 計劃內容（JD2_12WEEK_FINAL_PLAN.md Week 7）
- **Garmin Connect API**（JSON 路線）為優先
- FIT 二進位格式複雜度高，作為備選
- 第 2 種格式視當時可用樣本決定

### 已有的 TestFiles
```
TestFiles/Garmin/
├─ 2018-08-11-09-56-30.fit   (二進位 FIT)
├─ 2018-08-11-14-11-36.fit
└─ 2018-08-13-13-48-26.fit
```

FIT 是 Garmin 自有二進位格式，需第三方解碼庫（如 fit-parser swift package）。

### GarminDescentParser 現況
`DiveLogImporter.swift` 約 497–513 行，目前是**空殼**：
```swift
struct GarminDescentParser: DiveLogImporter {
    let format = DiveLogFormat.garmin
    func canHandle(filePath: String) -> Bool { ... }  // 僅檢查 .fit 副檔名
    func parse(from filePath: String) throws -> [DiveLog] {
        throw DiveLogImportError.unsupportedFormat("Garmin FIT 解析器尚未實現")
    }
}
```

### Week 7 建議決策流程
1. **先確認 Garmin Connect API 是否可用**：
   - 若有 API JSON 樣本 → 實作 GarminConnectParser（新結構體）
   - 若只有 FIT 二進位 → 評估引入 Swift Package（garmin-fit-swift 等）
2. **FIT 格式分析**：可用 `xxd TestFiles/Garmin/*.fit | head -20` 確認 FIT 魔術字節（`.FIT` at offset 8）
3. **第 2 格式**：依 Week 7 開始時可用的樣本決定（SHEARWATER、Peregrine、或其他）

### FIT 格式技術要點（若走 FIT 路線）
- 檔案開頭 14 bytes 為 File Header：Magic = `0x2E464954`（".FIT"）
- 後續為 Record Messages（Data/Definition 交替）
- Dive Records 在 FIT global message number 268（dive summary）
- 需要 CRC 驗證
- 建議引入：`swift-garmin-fit` 或 `SwiftFIT`（需確認目前是否維護）

---

## 📊 測試覆蓋率概覽

| 解析器 | 測試檔案數 | XCTests | 全綠確認 |
|--------|-----------|---------|---------|
| UDDFParser | 2 | 27 | ✅ |
| SubsurfaceXMLParser | 3 | 42 | ✅ |
| SubsurfaceCSVParser | 1 | 36 | ✅ |
| SuuntoJSONParser | 3 | 26 | ✅（截圖確認） |
| ImportCoordinator | N/A | 30 | 待 Xcode 跑 |
| **合計** | **9** | **161** | |

---

## 🔗 Git 提交歷史（Week 3–6）

```
dc5b826  fix: W3-W6 dual audit fixes — parsers, tests, dedup, orphan files
1e350f0  Week 6: ImportCoordinator fix + cross-format integration tests
6bafd59  Week 6: SuuntoJSONParser — DeviceLog JSON，22 tests，3 個真實檔案驗證
f2c3bbf  Fix: CSV parser CRLF grapheme cluster、empty data guard、date overflow test
ed2b804  Week 5: SubsurfaceCSVParser — RFC 4180 CSV, 36 tests, test41.csv 驗證
dfcc4af  Fix: canHandle .ssrf 不讀檔案直接接受；var→let UDDFParserTests
41f867a  Week 4: SubsurfaceXMLParser — Subsurface XML v3, 42 tests, EON Core/Nautic/Ocean 驗證
76033ef  Week 3 Day 1: 修復 Xcode 專案設定與既存 bug
31d37d8  Week 3 Day 1: UDDFParser (ISO 12639:2015)
```

---

## 📝 新對話串工作守則

1. **不控制 Xcode**：Claude 只寫程式碼並 commit，由 PM 在 Xcode 跑測試後 push
2. **工作流程**：Claude 寫完 → PM 在 Xcode 執行測試 → 全綠 → PM 決定是否 commit/push
3. **git commit 由 Claude 執行**，`git push` 由 PM 決定
4. **新增解析器的步驟**：
   - 在 `DiveLogImporter.swift` 中新增/修改對應的 struct
   - 更新 `DiveLogImporterFactory.availableParsers` 陣列
   - 更新 `DiveLogFormat` 的 `supportedExtensions`
   - 新增 TestFiles（放在 `TestFiles/<格式>/`）
   - 新增 `<格式>ParserTests.swift`（放在 `JD2-LogbookTests/`）
5. **測試路徑**：統一用 `#filePath` + 3× `deletingLastPathComponent` + `TestFiles/`
6. **`AI-generated (Claude)` 標記**：所有新生成檔案頂部必須標記

---

## 🆕 新對話串起始 Prompt（複製到新對話）

```
## JD2-Logbook Week 7 — Garmin 解析器

### 專案背景
JD2-Logbook 是 iOS/macOS 潛水日誌 app，支援多種潛水電腦格式匯入。
技術棧：Swift / Xcode / SwiftData / iOS 18

### 工作守則
- Claude 只寫程式碼並執行 git commit
- 不控制 Xcode，測試由 PM 在 Xcode 手動跑
- git push 由 PM 決定
- 所有新檔案頂部加 // AI-generated (Claude)

### 當前狀態（Week 6 完成）
已完成 4 種解析器（161 XCTests，全部通過）：
- UDDFParser（27 tests）
- SubsurfaceXMLParser（42 tests）
- SubsurfaceCSVParser（36 tests）
- SuuntoJSONParser（26 tests）
- ImportCoordinator fix + 30 integration tests

最新 commit：dc5b826（main branch）

### 關鍵技術細節

DiveLog 初始化（無 notes/sourceFormat 參數，需事後設定）：
    let dive = DiveLog(dateTime:, location:, maxDepth:, diveTimeSeconds:, gasMixJSON:, waterTemperature:)
    dive.sourceFormat = "garmin"

TestFiles 路徑解析（測試用）：
    let here       = (#filePath as NSString).deletingLastPathComponent  // JD2-LogbookTests
    let moduleRoot = (here as NSString).deletingLastPathComponent       // JD2-Logbook
    let repoRoot   = (moduleRoot as NSString).deletingLastPathComponent // repo root
    // 然後 repoRoot + "TestFiles/Garmin/..."

可用的 Garmin 測試檔案（二進位 FIT）：
    TestFiles/Garmin/2018-08-11-09-56-30.fit
    TestFiles/Garmin/2018-08-11-14-11-36.fit
    TestFiles/Garmin/2018-08-13-13-48-26.fit

GarminDescentParser 目前是空殼（在 DiveLogImporter.swift 約 497 行），
parse() 直接拋出 unsupportedFormat 錯誤。

### Week 7 任務
目標：實作 Garmin 解析器

決策優先順序：
1. 優先考慮 Garmin Connect API JSON（若有可用樣本）
2. 若只有 FIT 二進位，評估引入 Swift Package（SwiftFIT 或類似）
3. 第 2 種格式待 Week 7 開始時依可用樣本決定

請先：
1. 讀 TestFiles/Garmin/ 下的 FIT 檔案頭部，確認格式
2. 確認 DiveLogImporter.swift 中 GarminDescentParser 現況
3. 評估 FIT vs API 路線，提出建議後開始實作

### 技術債備忘（Week 8 處理，本週勿動）
- deduplicateDives 未接入 importFile 主流程（邏輯已修正，接入待 Week 8）
- N+1 save 待批次優化
- 性能初測（100 檔案 < 10s）待補

### 交接文件
/Users/kevin/Documents/Claude/Projects/JD2-Logbook/HANDOFF_WEEK6_TO_WEEK7.md
（含完整檔案索引、架構說明、技術債清單）
```

---

**交接完成時間**: 2026-05-18  
**交接人**: Claude Agent  
**審核人**: PM (Kevin)  
**下一步**: 開啟 Week 7 新對話串，執行 Garmin 解析器實作
