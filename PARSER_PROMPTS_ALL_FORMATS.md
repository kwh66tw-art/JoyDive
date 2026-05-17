# 所有 6 種格式的 Prompt 範本
## 供 Week 3-8 直接使用

**說明**: 複製對應的 Prompt，貼到 Claude Code Agent 中執行

---

## 格式 1: SHEARWATER 解析器

### Prompt for Claude Code Agent

```markdown
# 任務：生成 SHEARWATER 解析器

## 背景
- 應用：JD2-Logbook（潛水日誌 iOS 應用）
- 格式：Shearwater Cloud XML 格式
- 目標：支援 SHEARWATER 潛水電腦匯入
- 目標模型：DiveLog (from JoyDiveCore)

## 格式規格
SHEARWATER 使用 XML 格式儲存潛水記錄。
- 編碼：UTF-8
- 副檔名：.xml 或 .shearwater
- 根元素：<logdata> 或 <dives>
- 核心元素：<dive>, <gases>, <computer>

## XML 範例
```xml
<?xml version="1.0" encoding="UTF-8"?>
<logdata>
  <dive>
    <datetime>2023-06-15T14:30:00</datetime>
    <location>Kenting</location>
    <depth_max>25.5</depth_max>
    <duration>2730</duration>
    <water_temp>28</water_temp>
    <gases>
      <gas>21</gas>
    </gases>
  </dive>
</logdata>
```

## 欄位映射表
| SHEARWATER 欄位 | DiveLog 欄位 | 轉換 | 備註 |
|---------------|------------|------|------|
| datetime | diveDate | ISO 8601 → Date | 必填 |
| location | location | String | 選擇，預設 "Unknown" |
| depth_max | maxDepth | Float → Double (m) | 公尺 |
| duration | diveTime | Int (秒) → TimeInterval | 秒 |
| water_temp | waterTemp | Int → Double | °C |
| gases | gasMix | 21 (O2%) → GasMix | 簡化 |

## 參考資源

**不造輪子原則** - 使用現成開源代碼作為參考：
- **Subsurface** (開源潛水日誌軟件): https://github.com/Subsurface-divelog/subsurface
  - 包含完整的 SHEARWATER 和 Shearwater Cloud XML 解析器
  - 檔案位置: `core/divelog_importer.cpp`, `core/importparsers.cpp`
- **建議做法**: 查看 Subsurface 的 SHEARWATER XML 欄位映射，改編至 Swift DiveLog 模型

## 需求

### 實現 SHEARWATERParser
```swift
class SHEARWATERParser: DiveLogImporter {
    func parse(fileURL: URL) throws -> [DiveLog]
    func validate(logs: [DiveLog]) -> ImportValidation
}
```

### 特殊邏輯
1. **XML 解析**
   - 使用 XMLParser (Swift 標準庫)
   - 支援多種根元素名稱 (<logdata>, <dives>)
   - 忽略命名空間

2. **氣體混合**
   - O2% 直接對應 gasMix
   - 缺失時使用預設 21% (Air)

3. **時間轉換**
   - SHEARWATER 使用 ISO 8601: 2023-06-15T14:30:00
   - 轉換為 Swift Date

4. **深度單位**
   - 默認公尺
   - 轉換為 Double

5. **錯誤情況**
   - 缺失 datetime → ImportError.parsingFailed
   - 缺失 location → 使用預設 "Unknown Location"
   - 無效 XML → ImportError.invalidFormat

### 單元測試 (> 85% 覆蓋率)
1. `testParseSimpleDive()` - 單次潛水
2. `testParseMultipleDives()` - 多次潛水
3. `testMissingLocation()` - 缺失選擇欄位
4. `testExtremeDeptValue()` - 極值測試
5. `testInvalidXML()` - 損壞 XML
6. `testGasHandling()` - 氣體混合處理

### 輸出物
1. `SHEARWATERParser.swift` - 完整解析器
2. `SHEARWATERParserTests.swift` - 單元測試
3. `SHEARWATER_Notes.md` - 實現說明

---

**時限**: 90 分鐘
**優先順序**: 正確性 > 完善邊界情況 > 性能
```

---

## 格式 2: Peregrine 解析器

### Prompt for Claude Code Agent

```markdown
# 任務：生成 Peregrine 解析器

## 背景
- 應用：JD2-Logbook
- 格式：Peregrine XML（新一代 Shearwater 格式）
- 特性：包含 ppO2 (氧分壓) 支援
- 目標模型：DiveLog

## 格式特點
Peregrine 是 SHEARWATER 的新版本，增加了進階資訊。
- 編碼：UTF-8
- 根元素：<dive_log>
- 新增欄位：ppO2, cns%, gf%, deco_info

## 欄位映射表
| Peregrine 欄位 | DiveLog 欄位 | 備註 |
|---------------|------------|------|
| dive_time | diveDate | ISO 8601 |
| location | location | 位置 |
| max_depth | maxDepth | 公尺 |
| dive_duration | diveTime | 秒 |
| temp_water | waterTemp | °C |
| ppO2 | - | 忽略（超出 DiveLog） |
| cns_percentage | - | 忽略 |

## 參考資源

**不造輪子原則**：
- **Shearwater 官方文檔**: Peregrine 是 SHEARWATER 的延伸，格式相似
- **Subsurface**: 已支持 Peregrine 格式，參考其實現
- **建議做法**: 基於 SHEARWATER 解析器擴展，添加 ppO2 欄位支援

## 需求
1. 支援 Peregrine XML 格式
2. 向下相容 SHEARWATER（若無新欄位）
3. ppO2 欄位解析但不存儲（記錄為 notes）
4. 其他邏輯同 SHEARWATER

### 單元測試
1. 基本 Peregrine 檔案解析
2. ppO2 處理
3. 向下相容舊格式

### 輸出物
1. `PeregrineParser.swift` - 完整解析器
2. `PeregrineParserTests.swift` - 單元測試

---

**時限**: 75 分鐘
**說明**: 可參考 SHEARWATER 解析器進行改進
```

---

## 格式 3: Cressi/Mares CSV 解析器

### Prompt for Claude Code Agent

```markdown
# 任務：生成 Cressi/Mares CSV 解析器

## 背景
- 應用：JD2-Logbook
- 格式：Cressi Mares CSV (簡單逗號分隔)
- 特點：輕量級，適合入門級潛水電腦
- 目標模型：DiveLog

## CSV 結構
```
Date,Time,Location,MaxDepth(m),Duration(min),WaterTemp(°C),Gas
2023-06-15,14:30,Kenting,25.5,45,28,Air
2023-06-16,10:00,Green Island,18.0,50,27,Air
```

## 欄位映射表
| CSV 欄位 | DiveLog 欄位 | 轉換 |
|---------|------------|------|
| Date+Time | diveDate | YYYY-MM-DD HH:MM → Date |
| Location | location | String |
| MaxDepth | maxDepth | Float → Double |
| Duration | diveTime | Int (分) → Int (秒) |
| WaterTemp | waterTemp | Int → Double |
| Gas | gasMix | "Air" → 21% O2 |

## 參考資源

**不造輪子原則**：
- **Subsurface**: 支持 Cressi/Mares CSV 解析
  - 檔案: `core/importparsers.cpp` 中的 CSV 分析器
- **建議做法**: CSV 格式相對簡單，參考 Subsurface 的欄位映射即可

## 需求
1. **CSV 解析**
   - 使用 String split 或簡單 CSV 庫（Swift 內建即可）
   - 支援有無 BOM (byte order mark)
   - 忽略空白行和註釋行

2. **資料轉換**
   - Date+Time 合併為 diveDate
   - Duration 分鐘轉秒
   - Gas 字符串對應 GasMix

3. **錯誤處理**
   - 欄位數不足 → 跳過該行
   - 日期無效 → 拋出異常
   - 數值無效 → 使用預設值

### 單元測試
1. 基本 CSV 解析
2. 多行潛水記錄
3. 缺失欄位處理
4. 無效日期格式

### 輸出物
1. `CreassiMaResParser.swift` - CSV 解析器
2. `CreassiMaResParserTests.swift` - 單元測試

---

**時限**: 75 分鐘
**複雜度**: 低（CSV 最簡單）
```

---

## 格式 4: Garmin Descent XML 解析器

### Prompt for Claude Code Agent

```markdown
# 任務：生成 Garmin Descent XML 解析器

## 背景
- 應用：JD2-Logbook
- 格式：Garmin Descent XML（來自潛水錶）
- 特點：複雜多命名空間 XML，包含多種資訊
- 目標模型：DiveLog

## 格式特點
- 編碼：UTF-8
- 根元素：<Dive>
- 多命名空間 (NS0, NS1, NS2 等)
- 深層嵌套結構
- 時間戳為 Unix timestamp

## XML 結構簡化
```xml
<?xml version="1.0"?>
<Dive xmlns="http://www.garmin.com/xmlschemas/DiveLog/v1">
  <Time>1686825000</Time>  <!-- Unix timestamp -->
  <Location>Kenting</Location>
  <MaxDepth>2550</MaxDepth>  <!-- cm, 需轉換 -->
  <Duration>2730</Duration>  <!-- 秒 -->
  <WaterTemperature>28</WaterTemperature>  <!-- °C -->
  <GasConsumption>
    <Gas O2="21">...</Gas>
  </GasConsumption>
  <Samples>
    <Sample Time="0" Depth="0"/>
    <Sample Time="10" Depth="250"/>  <!-- cm -->
  </Samples>
</Dive>
```

## 欄位映射表
| Garmin 欄位 | DiveLog 欄位 | 轉換 |
|-----------|------------|------|
| Time | diveDate | Unix timestamp → Date |
| Location | location | String |
| MaxDepth | maxDepth | Int (cm) → Double (m) |
| Duration | diveTime | Int (秒) → TimeInterval |
| WaterTemperature | waterTemp | Int → Double |
| Gas O2 | gasMix | O2% value |

## 參考資源

**不造輪子原則**：
- **Garmin Connect 官方 API 文檔**: Garmin Descent XML 格式已公開
  - 檔案規格在 Garmin SDK 中提供
- **Subsurface**: 已支持 Garmin Descent 解析
  - 檔案: `core/importparsers.cpp`
- **建議做法**: 參考 Subsurface 的命名空間處理和深度轉換邏輯

## 需求
1. **XML 解析**
   - 支援命名空間
   - 使用 XMLDecoder 或 XMLParser
   - 處理多層嵌套元素

2. **單位轉換**
   - 深度：cm → m (÷100)
   - 時間：Unix timestamp → Date

3. **複雜邏輯**
   - 多氣體支援（若有多個 Gas）
   - 樣本點解析（用於深度曲線）
   - 缺失欄位使用預設

4. **錯誤處理**
   - 命名空間錯誤 → 容錯處理
   - 時間戳無效 → 拋出異常
   - XML 結構異常 → 清晰錯誤訊息

### 單元測試
1. 基本 Garmin XML 解析
2. 命名空間處理
3. 深度單位轉換
4. Unix timestamp 轉換
5. 多氣體處理
6. 樣本點解析

### 輸出物
1. `GarminParser.swift` - Garmin 解析器
2. `GarminParserTests.swift` - 單元測試
3. `Garmin_Implementation.md` - 複雜邏輯說明

---

**時限**: 120 分鐘
**複雜度**: 高（多命名空間、單位轉換、深層嵌套）
**參考**: 可使用 XMLDecoder (Swift 標準庫)
```

---

## 格式 5: Suunto 解析器（SDE + XML + SDP）

### Prompt for Claude Code Agent

```markdown
# 任務：生成 Suunto 解析器（三種格式合一）

## 背景
- 應用：JD2-Logbook
- 格式：Suunto SDE (二進制) / XML / SDP (文本)
- 複雜度：★★★★★ (極高)
- 目標：統一支援三種格式，自動檢測

## 三種格式概述

### 1. Suunto SDE (二進制)
- 編碼：專有二進制格式
- 解析困難：需要逆向工程
- 資源：Subsurface 開源實現有參考

### 2. Suunto XML
- 編碼：UTF-8 XML
- 結構：與 SHEARWATER 類似
- 易度：中等

### 3. Suunto SDP (文本)
- 編碼：特殊文本格式
- 易度：簡單（可作為後備）

## 実装策略

### 推薦方案（完整）
1. 優先完成 XML 和 SDP 解析
2. 針對 SDE，參考 Subsurface 開源代碼
3. 若 SDE 困難，降級為 XML+SDP 支援

### 最小可用方案
- 僅支援 SDE + XML，暫不支援 SDP
- v1.0.1 補充 SDP

## 欄位映射（共通）
| Suunto 欄位 | DiveLog 欄位 | 備註 |
|-----------|------------|------|
| DiveTime | diveDate | ISO 8601 或 Unix timestamp |
| Location | location | 位置 |
| MaximumDepth | maxDepth | 公尺或英尺 |
| DurationInSeconds | diveTime | 秒 |
| WaterTemperature | waterTemp | °C |

## 需求
1. **格式檢測**
   ```swift
   // 根據副檔名和文件頭判斷格式
   let format = detectSuuntoFormat(fileURL)
   // 返回 .sde, .xml, 或 .sdp
   ```

2. **三個獨立解析器**
   - SuuntoSDEParser
   - SuuntoXMLParser
   - SuuntoSDPParser
   - 統一介面：都實現 DiveLogImporter

3. **Subsurface 參考**
   - 開源項目：https://github.com/Subsurface-divelog/subsurface
   - SDE 逆向工程資訊在其代碼中
   - 可參考其 qt-models/diveimportedmodel.cpp

4. **風險應對**
   - 若 SDE 複雜度過高 → 先實現 XML+SDP
   - 計劃 v1.0 支援 XML+SDP，v1.1 追加 SDE
   - 記錄 Release Notes：「SDE 支援計劃中」

### 單元測試
1. XML 格式完整測試
2. SDP 格式完整測試
3. SDE 基本測試（若時間允許）
4. 格式自動檢測測試
5. 多筆記錄測試

### 輸出物
1. `SuuntoParser.swift` - 統一入口
2. `SuuntoXMLParser.swift` - XML 實現
3. `SuuntoSDPParser.swift` - SDP 實現
4. `SuuntoSDEParser.swift` - SDE 實現（或降級方案）
5. `SuuntoParserTests.swift` - 單元測試
6. `Suunto_Implementation.md` - 複雜邏輯說明

---

**時限**: 150 分鐘
**複雜度**: ★★★★★ 極高
**決策點**: 若時間不足，優先 XML+SDP，SDE 延至 v1.1
**參考資源**: Subsurface 開源項目
```

---

## 格式 6: Oceanic 解析器（OCF + XML）

### Prompt for Claude Code Agent

```markdown
# 任務：生成 Oceanic 解析器

## 背景
- 應用：JD2-Logbook
- 格式：Oceanic OCF (二進制) + XML
- 特點：二進制與 XML 混合，可能包含壓縮
- 複雜度：高

## 格式特點
- OCF (Oceanic Computer Format)：二進制格式，可能 ZIP 容器
- XML：可能也包含 XML 版本
- 壓縮：可能使用 gzip 或自定義壓縮

## 文件結構
```
oceanic_dive.ocf
├─ [Binary Header] - 格式識別
├─ [Compressed Data] - 或明文 XML
└─ [Metadata]
```

## 欄位映射表
| Oceanic 欄位 | DiveLog 欄位 | 轉換 |
|-----------|------------|------|
| DiveDateTime | diveDate | Unix timestamp 或 Date |
| Location | location | String |
| MaxDepth | maxDepth | 公尺 |
| DiveTime | diveTime | 秒 |
| BottomTemperature | waterTemp | °C |

## 參考資源

**不造輪子原則**：
- **Subsurface**: 支持 Oceanic 解析
  - 檔案: `core/importparsers.cpp` 中的 Oceanic 分析器
  - 注意：Oceanic 資源相對稀少，Subsurface 參考最完整
- **建議做法**: 優先參考 Subsurface 的二進制頭識別邏輯和壓縮處理
- **備用**: 若 OCF 二進制困難，優先實現 XML 版本，二進制延至 v1.1

## 需求

### 解析策略
1. **檔案頭檢測**
   - 識別 Oceanic 二進制簽名
   - 檢測壓縮標記（gzip magic: 0x1f 0x8b）

2. **壓縮處理**
   - 若為 gzip → 解壓
   - 解壓後可能為 XML 或二進制

3. **二進制解析**
   - 定義結構化欄位（二進制偏移）
   - 處理字節序 (endianness)

4. **備份方案**
   - 若包含 XML → 優先使用 XML
   - 若只有二進制 → 使用二進制解析

5. **錯誤處理**
   - 無效簽名 → ImportError.invalidFormat
   - 解壓失敗 → ImportError.parsingFailed
   - 格式未知 → 嘗試備用方案

### 單元測試
1. 基本 Oceanic 檔案解析
2. gzip 壓縮處理
3. 二進制欄位提取
4. 多筆記錄解析
5. 錯誤格式處理
6. XML 備用方案測試

### 輸出物
1. `OceanicParser.swift` - 統一解析器
2. `OceanicBinaryReader.swift` - 二進制讀取（若需要）
3. `OceanicParserTests.swift` - 單元測試
4. `Oceanic_Implementation.md` - 複雜邏輯說明

---

**時限**: 120 分鐘
**複雜度**: 高（二進制 + 壓縮）
**備用方案**: 若二進制困難，可先實現 XML 版本
**說明**: Oceanic 資源較少，可能需要試錯
```

---

## 使用指南

### 按時間安排

```
Week 3: SHEARWATER + Peregrine (45分鐘 × 2)
Week 4: Cressi + 跨格式測試 (75分鐘 + 30分鐘)
Week 5-6: Garmin + Suunto (150分鐘)
Week 7: Oceanic + 最終驗證 (120分鐘)
```

### Prompt 使用步驟

1. **複製對應格式的 Prompt**
2. **根據實際情況調整** (若有新資訊)
3. **貼到 Claude Code Agent**
4. **執行代碼生成**
5. **PM 驗證並 Commit**

### 若遇到困難

- **複雜度過高**：降級功能 (e.g., Suunto SDE → 先跳過)
- **時間不足**：簡化測試 (優先正確性)
- **格式資源缺乏**：搜索 GitHub/StackOverflow 參考實現

---

## 預期時間表

| 格式 | 時間估計 | 實際可調整 | 優先順序 |
|------|---------|---------|---------|
| SHEARWATER | 90 分鐘 | 75-105 | 🔴 高 |
| Peregrine | 75 分鐘 | 60-90 | 🔴 高 |
| Cressi | 75 分鐘 | 60-90 | 🔴 高 |
| Garmin | 120 分鐘 | 100-150 | 🟠 中 |
| Suunto | 150 分鐘 | 120-180 | 🟠 中 |
| Oceanic | 120 分鐘 | 100-150 | 🟡 低 |

---

**記錄方式**：複製此檔案到工作目錄，完成後在 Prompt 下方註記 ✅ 日期

**最後更新**: 2026-05-17
