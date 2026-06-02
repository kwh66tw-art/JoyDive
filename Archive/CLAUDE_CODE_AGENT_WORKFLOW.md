# Claude Code Agent 工作流程與 Prompt 範本

**目的**: 建立 PM + Claude Code Agent 的標準協作流程  
**目標效率**: 1 個解析器 2 小時內完成（生成 + 測試 + 驗證）

---

## 第一部分：工作流程（標準 2 小時循環）

### 總流程圖

```
【0:00-0:10】 PM 準備 + 溝通
├─ PM 確認需求、提供參考資料
├─ PM 準備測試檔案 (5+ 個)
└─ PM 發出 Claude Code Agent Prompt

【0:10-1:30】 Claude Code Agent 執行
├─ 格式分析 (10-15 分鐘)
├─ 代碼生成 (20-30 分鐘)
├─ 單元測試編寫 (15-20 分鐘)
├─ 編譯驗證 (10-15 分鐘)
└─ 返回可運行產物

【1:30-2:00】 PM 驗證 + Commit
├─ 複製代碼至 Xcode 專案
├─ 在模擬器中運行驗證
├─ 邊界情況測試 (1-2 個)
├─ Git commit + PR 提交
└─ 反饋給 Claude (若需要)

【迭代】(若 PM 發現問題)
└─ Claude 根據反饋修改 → PM 重新驗證
```

---

## 第二部分：PM 準備清單

### 每個解析器開始前（提前準備）

```
□ 格式規格
  ├─ XSD / 文檔 / RFC 連結
  ├─ 範例檔案 (3-5 個）
  └─ 邊界情況說明 (缺失欄位、錯誤格式等)

□ 測試檔案準備
  ├─ 有效檔案 (正常潛水記錄)
  ├─ 邊界情況檔案 (缺失欄位、極值)
  ├─ 錯誤格式檔案 (損壞、編碼問題)
  └─ 儲存在 `Tests/TestData/{FormatName}/` 資料夾

□ 映射參考
  ├─ 格式欄位 → DiveLog 模型的對應表
  ├─ 單位轉換規則 (例如：bar → meter)
  └─ 特殊欄位處理 (例如：多氣體、SPO2)

□ 已知限制或文件
  ├─ 該格式是否有官方 SDK?
  ├─ 是否有開源實現可參考?
  └─ 有哪些已知的邊界情況?
```

---

## 第三部分：Claude Code Agent Prompt 範本

### 【模板 A】- 簡單格式（CSV、JSON）

```markdown
# 任務：生成 {FormatName} 解析器

## 背景
- 應用：JD2-Logbook（潛水日誌 iOS 應用）
- 目標：支援 {FormatName} 檔案格式的潛水數據匯入
- 目標模型：JoyDiveCore 的 DiveLog 結構

## 格式規格
{貼上格式文檔或規格說明}

## 欄位映射表
| {FormatName} 欄位 | DiveLog 欄位 | 單位 | 備註 |
|------------------|------------|------|------|
| {例如：MaxDepth_m} | maxDepth | Double (米) | 1m 精度 |
| {例如：Duration_sec} | diveTime | TimeInterval | 秒轉換 |
| ... | ... | ... | ... |

## 測試檔案
已在 `Tests/TestData/DiveFormat/{FormatName}/` 提供以下測試檔案：
- `normal_dive.{ext}` - 正常潛水記錄
- `edge_case_missing_fields.{ext}` - 缺失選擇欄位
- `edge_case_extreme_values.{ext}` - 極值測試
- `error_format.{ext}` - 損壞格式

## 需求

### 核心功能
```swift
// 應生成的 Parser 類別簽章
class {FormatName}Parser: DiveLogImporter {
    func parse(fileURL: URL) throws -> [DiveLog]
    func validate(logs: [DiveLog]) -> ImportValidation
}
```

### 詳細要求
1. **解析器實現**
   - 讀取 {FormatName} 檔案內容
   - 映射到 DiveLog 模型
   - 處理編碼（UTF-8, Big5 等）
   - 單位轉換
   - 處理缺失欄位（使用合理預設）

2. **錯誤處理**
   - 檔案不存在：拋出 ImportError.fileNotFound
   - 格式錯誤：拋出 ImportError.invalidFormat
   - 解析失敗：拋出 ImportError.parsingFailed(reason)
   - 邊界情況：記錄警告，但不中斷流程

3. **單元測試** (使用 XCTest)
   - 每個測試檔案一個測試函數
   - 驗證欄位映射的正確性
   - 驗證邊界情況處理
   - 驗證錯誤情況拋出正確異常
   - 目標覆蓋率 > 85%

4. **性能要求**
   - 解析單個檔案 < 1 秒
   - 編譯無警告
   - 無記憶體洩漏

## 輸出物
1. `{FormatName}Parser.swift` - 完整解析器代碼
2. `{FormatName}ParserTests.swift` - 完整單元測試
3. 簡短說明文件 (特殊處理邏輯、邊界情況)

## 額外建議
- 使用 Swift 標準庫，避免外部依賴
- 代碼盡量簡潔，優先可讀性
- 註釋重點：複雜映射邏輯、邊界情況處理
- 如遇到格式模糊之處，列出假設並詢問 PM

---

**優先順序**: 正確性 > 性能 > 代碼簡潔性
**時限**: 90 分鐘內完成核心代碼 + 測試
```

---

### 【模板 B】- 複雜格式（XML、二進制）

```markdown
# 任務：生成 {FormatName} 解析器（複雜格式）

## 格式特性
- **格式類型**: XML / Binary / Compressed
- **複雜度**: {高/極高}
- **典型檔案大小**: {例如：1-10 MB}
- **已知困難**: {例如：多版本格式、非標準 XML 命名空間}

## XSD / 二進制規格
{貼上 XSD、BNF、或二進制規格說明}

## 複雜映射邏輯

### 案例 1：多版本支援
{描述如何處理不同版本的格式差異}

### 案例 2：嵌套結構
{描述如何映射嵌套 XML 或二進制結構}

### 案例 3：特殊欄位轉換
{描述複雜的單位轉換或資料變換邏輯}

## 參考實現
- 開源實現: {URL}
- 官方 SDK: {URL}
- 論文/規格: {URL}

## 測試策略
由於複雜性，採用分層測試：

1. **格式解析層** - 確保能正確讀取格式結構
2. **欄位映射層** - 確保映射到 DiveLog 無誤
3. **邊界情況層** - 處理格式變異、缺失資料
4. **性能層** - 大檔案解析速度

## 輸出物
1. `{FormatName}Parser.swift` - 分模組實現
   - `{FormatName}FormatReader` - 格式讀取
   - `{FormatName}ModelMapper` - 模型映射
   - `{FormatName}Parser` - 統一介面
2. `{FormatName}ParserTests.swift` - 分層測試
3. 詳細說明文件 - 特殊邏輯解釋

---

**時限**: 150 分鐘內完成（複雜度需要更多時間）
```

---

## 第四部分：Prompt 範本使用範例

### 【實際案例】- UDDF 解析器

```markdown
# 任務：生成 UDDF 解析器

## 背景
- 應用：JD2-Logbook（潛水日誌 iOS 應用）
- 格式：Universal Dive Data Format (UDDF, ISO 12639:2015)
- 目標：支援 UDDF 檔案匯入，映射到 DiveLog 模型

## 格式規格
UDDF 是 XML 格式（在 ZIP 內），包含潛水記錄。
- 主檔案：`uddf.xml`
- 位置：ZIP 內根目錄
- 編碼：UTF-8
- 核心元素：`<dives><dive><samples>...</samples></dive></dives>`

## 欄位映射表
| UDDF 欄位 | DiveLog 欄位 | 轉換 | 備註 |
|----------|------------|------|------|
| `dive/@datetime` | diveDate | ISO 8601 → Date | 必填 |
| `dive/location` | location | String | 選擇 |
| `dive/greatestdepth` | maxDepth | String → Double (m) | 以米為單位 |
| `dive/diveduration` | diveTime | String → TimeInterval (秒) | HH:MM:SS → 秒 |
| `dive/surfaceintervalafter` | - | 忽略 | 不用 |
| `samples/sample[@time]` | 深度曲線點 | 每秒一次採樣 | 用於 DepthChart |

## 測試檔案
已準備在 `Tests/TestData/UDDF/`：
- `simple_dive.uddf` - 單次潛水
- `multiple_dives.uddf` - 多次潛水
- `missing_optional.uddf` - 缺失選擇欄位（location）
- `extreme_values.uddf` - 深度 100m+、時長 8h+
- `corrupted.uddf` - 損壞的 ZIP

## 需求

### 實現 UDDFParser
```swift
class UDDFParser: DiveLogImporter {
    func parse(fileURL: URL) throws -> [DiveLog]
    // 返回 UDDF 檔案中的所有 <dive> 元素
    
    func validate(logs: [DiveLog]) -> ImportValidation
    // 驗證數據完整性
}
```

### 特殊邏輯
1. **ZIP 檔案處理**
   - 使用 `ZipFoundation` (SPM)
   - 解壓後找 `uddf.xml`
   - 若不存在，拋出 ImportError.invalidFormat

2. **XML 解析**
   - 使用 `XMLParser` (Swift 標準庫)
   - 解析 `<dive>` 和 `<samples>` 元素

3. **時間轉換**
   - UDDF 使用 ISO 8601: `2023-06-15T14:30:00+08:00`
   - 轉換為 Swift `Date`
   - 使用 `ISO8601DateFormatter`

4. **深度單位**
   - UDDF 通常使用公尺
   - 轉換為 Double（米）
   - 處理 `"0.0"` 或 `"100.5"` 字符串格式

5. **錯誤情況**
   - 缺失 datetime → ImportError.parsingFailed("Missing dive date")
   - 缺失 location → 使用預設 "Unknown Location"
   - 無 samples → 使用預設深度曲線

### 單元測試 (> 85% 覆蓋率)
1. `testParseSimpleDive()` - 解析單次潛水
2. `testParseMultipleDives()` - 解析多次潛水
3. `testMissingOptionalFields()` - 處理缺失欄位
4. `testExtremeValues()` - 極值測試
5. `testInvalidFormat()` - 拋出正確異常
6. `testMissingUddfFile()` - ZIP 內無 uddf.xml
7. `testCorruptedZip()` - 損壞 ZIP 檔案

### 性能要求
- 解析 `simple_dive.uddf` < 0.5 秒
- 解析 `multiple_dives.uddf` (100 dives) < 2 秒
- 編譯無警告

## 輸出物
1. `UDDFParser.swift` - 完整解析器
2. `UDDFParserTests.swift` - 單元測試
3. `UDDF_Implementation_Notes.md` - 特殊邏輯說明

---

**時限**: 90 分鐘
**優先順序**: 正確性 > 完善邊界情況 > 性能

---

🚀 **開始前檢查清單**:
- [ ] ZipFoundation 已在 Package.swift 中註冊?
- [ ] Tests/TestData/UDDF/ 中有 5 個測試檔案?
- [ ] DiveLog 模型結構明確?
```

---

## 第五部分：PM 驗證清單（交付物檢查）

### 代碼驗證（PM 檢查）

```swift
// ✅ 檢查項目

□ 編譯檢查
  └─ $ swift build  // 無誤？

□ 測試通過
  └─ $ swift test UDDFParserTests  // 所有測試綠燈？

□ 代碼品質
  ├─ 無編譯警告?
  ├─ 註釋清晰 (特別是複雜邏輯)?
  └─ 遵循 Swift 命名規範?

□ 功能驗證
  ├─ 能解析 5 個測試檔案?
  ├─ 邊界情況處理合理?
  └─ 錯誤訊息清晰?

□ 性能驗證
  ├─ 單檔案解析 < 預期時間?
  ├─ 無明顯記憶體洩漏?
  └─ 編譯後檔案大小合理?

□ Git 準備
  ├─ 改動已 stage?
  ├─ Commit message 清晰?
  └─ 無不該提交的檔案?
```

### 邊界情況驗證

```
【缺失欄位】
└─ 若 location 缺失，是否使用預設值?

【極值】
└─ depth=100m, time=8h 是否處理正確?

【編碼】
└─ UTF-8 + Big5 字符是否顯示正確?

【多筆記錄】
└─ 100+ 潛水記錄是否全部解析?

【格式變異】
└─ 舊版 UDDF vs 新版是否都支援?
```

---

## 第六部分：範本使用建議

### 根據複雜度選擇範本

```
┌─ 簡單格式 (CSV, JSON) → 用【模板 A】
│  └─ 代碼生成時間：30-40 分鐘
│  └─ 測試編寫時間：15-20 分鐘
│  └─ PM 驗證時間：10-15 分鐘
│
├─ 中等複雜 (XML 簡單結構) → 用【模板 A】+ 細化
│  └─ 代碼生成時間：40-50 分鐘
│  └─ 測試編寫時間：20-25 分鐘
│  └─ PM 驗證時間：15-20 分鐘
│
└─ 高複雜 (多版本 XML、二進制、嵌套) → 用【模板 B】
   └─ 代碼生成時間：60-80 分鐘
   └─ 測試編寫時間：30-40 分鐘
   └─ PM 驗證時間：20-30 分鐘
```

### 迭代流程

若 Claude 生成的代碼有問題：

```
【PM 反饋】(5-10 分鐘)
"UDDFParser 解析 edge_case_missing_fields.uddf 時拋出異常。
應該使用預設值而非中斷。
詳見錯誤訊息：{複製 Xcode 中的異常堆棧}"

【Claude 修正】(10-15 分鐘)
"我看到了。問題在於缺失 location 時用了 force unwrap。
已改為使用 ?? 操作符提供預設值。
更新後的代碼在下方..."

【PM 重新驗證】(5 分鐘)
"✅ 已驗證，邊界情況現在正確處理。Commit!"
```

---

## 第七部分：每週進度追蹤

### 週進度檢查清單

```
【每週五 - 進度回顧】

□ 本週完成的解析器
  ├─ 編譯無誤 ✅
  ├─ 測試通過率 100% ✅
  ├─ 單元測試覆蓋率 > 85% ✅
  └─ Git commit 完成 ✅

□ 累積進度
  ├─ 已完成: {X}/{7} 種格式
  ├─ 計畫延期風險: {是/否}
  └─ 下週優先順序: {格式列表}

□ 遇到的問題
  ├─ 技術阻礙: {描述或無}
  ├─ PM 時間不足: {是/否}
  └─ Claude 效率問題: {是/否}
```

---

**總結**：此工作流程確保每個解析器都在 2 小時內完成代碼生成、測試、驗證。PM 投入最小化，Claude Code Agent 負責代碼重工作。
