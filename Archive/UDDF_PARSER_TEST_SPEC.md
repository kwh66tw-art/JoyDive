# UDDF 解析器生成測試
## 測試時間：2026 年 5 月 17 日

**目標**：驗證 Claude Code Agent 能否在 90 分鐘內生成完整的 UDDF 解析器

---

## 測試設置

### 已準備的資源

#### 1. UDDF 格式規格（簡化版本）

```xml
<!-- UDDF 結構範例 -->
<?xml version="1.0" encoding="UTF-8"?>
<uddf version="3.2.0">
  <generator>
    <name>UDDF Example</name>
  </generator>
  
  <dives>
    <dive datetime="2023-06-15T14:30:00+08:00">
      <divenumber>42</divenumber>
      <location>Kenting, Taiwan</location>
      <greatestdepth>25.5</greatestdepth>
      <diveduration>00:45:30</diveduration>
      <surfacetemperature>28</surfacetemperature>
      <bottomtemperature>24</bottomtemperature>
      <samples>
        <sample time="0">
          <depth>0.0</depth>
          <temperature>28</temperature>
        </sample>
        <sample time="10">
          <depth>2.5</depth>
          <temperature>27.8</temperature>
        </sample>
        <!-- ... 更多採樣點 ... -->
        <sample time="2730">
          <depth>0.0</depth>
          <temperature>28</temperature>
        </sample>
      </samples>
    </dive>
  </dives>
</uddf>
```

**關鍵欄位**:
- `dive/@datetime` - ISO 8601 潛水時間
- `divenumber` - 潛水編號 (Integer)
- `location` - 潛水地點 (String, 選擇)
- `greatestdepth` - 最大深度 (Float, 米)
- `diveduration` - 潛水時長 (HH:MM:SS)
- `surfacetemperature` - 水溫 (Integer, °C)
- `bottomtemperature` - 底層溫度 (Integer, °C)
- `samples` - 深度採樣點列表

#### 2. 測試檔案集（應產生）

```
Tests/TestData/UDDF/
├── simple_dive.uddf        # 單次潛水，完整欄位
├── multiple_dives.uddf     # 3 次潛水
├── missing_location.uddf   # 缺 location (選擇欄位)
├── extreme_depth.uddf      # 深度 100m
├── extreme_duration.uddf   # 潛水時間 8h+
└── corrupted.uddf          # 損壞的 ZIP/XML
```

#### 3. DiveLog 模型參考

```swift
@Model
final class DiveLog {
    @Attribute(.unique) var id: UUID
    var diveNumber: Int
    var diveDate: Date                    // 來自 dive/@datetime
    var location: String?                 // 來自 location，預設 "Unknown"
    var maxDepth: Double                  // 來自 greatestdepth (米)
    var diveTime: TimeInterval            // 來自 diveduration (轉換為秒)
    var waterTemp: Double?                // 來自 surfacetemperature
    var notes: String?
    var lastModified: Date
}
```

---

## 測試任務

### 【Phase 1】格式分析 (10-15 分鐘)

**任務**：分析 UDDF 格式結構，生成欄位映射表

**產出**:
```markdown
# UDDF 格式分析

## 結構
- 根元素：`<uddf>`
- 潛水容器：`<dives>`
- 單筆潛水：`<dive>`
- 必填欄位：datetime, greatestdepth, diveduration
- 選擇欄位：location, bottomtemperature, notes

## 映射表
| UDDF | DiveLog | 轉換 |
|------|---------|------|
| dive/@datetime | diveDate | ISO 8601 → Date |
| divenumber | diveNumber | Int |
| location | location | String?（預設"Unknown"） |
| greatestdepth | maxDepth | Float → Double |
| diveduration | diveTime | HH:MM:SS → seconds |
| surfacetemperature | waterTemp | Int → Double? |

## 複雜性評估
- XML 結構複雜度：低
- 欄位轉換複雜度：中
- 預期編碼時間：30-40 分鐘
```

---

### 【Phase 2】代碼生成 (30-40 分鐘)

**任務**：生成 UDDFParser.swift

**期望檔案**：
```
UDDFParser.swift (~250-300 行)
├─ UDDFParser 類別 (符合 DiveLogImporter 協議)
├─ parse(fileURL:) 方法
│  ├─ ZIP 檔案處理
│  ├─ XML 解析
│  ├─ 欄位映射
│  └─ 錯誤處理
├─ validate(logs:) 方法
├─ 輔助方法 (時間轉換、單位轉換)
└─ MARK 段落註釋
```

**代碼品質檢查**:
- ✅ 無編譯警告
- ✅ 遵循 Swift 命名規範 (camelCase)
- ✅ 關鍵邏輯有註釋
- ✅ 錯誤處理完善

---

### 【Phase 3】單元測試編寫 (20-30 分鐘)

**任務**：生成 UDDFParserTests.swift

**測試用例** (~80-100 行):
```swift
class UDDFParserTests: XCTestCase {
    
    // 基本測試
    func testParseSimpleDive() -> Void { ... }
    func testParseMultipleDives() -> Void { ... }
    
    // 邊界情況測試
    func testMissingOptionalLocation() -> Void { ... }
    func testExtremeDepthand Duration() -> Void { ... }
    
    // 錯誤情況測試
    func testInvalidXMLFormat() -> Void { ... }
    func testMissingUddfFile() -> Void { ... }
    func testCorruptedZip() -> Void { ... }
    
    // 性能測試
    func testParsingPerformance() -> Void { ... }
}
```

**測試覆蓋率目標**: > 85%

---

### 【Phase 4】編譯驗證 (10-15 分鐘)

**任務**：驗證代碼可編譯、測試可運行

**檢查清單**:
```bash
$ swift build
# ✅ 編譯成功，無警告

$ swift test UDDFParserTests
# ✅ 所有測試通過 (7/7)

$ swiftformat UDDFParser.swift UDDFParserTests.swift
# ✅ 代碼格式化檢查
```

---

## 測試時間軸

```
【0:00】測試開始
【0:10】Phase 1 完成 - 格式分析 + 映射表
【0:45】Phase 2 完成 - UDDFParser.swift 生成
【1:15】Phase 3 完成 - UDDFParserTests.swift 生成
【1:30】Phase 4 完成 - 編譯驗證
【1:45】PM 驗證 (複製、執行、檢查)
【2:00】完成 ✅
```

---

## 成功標準

### ✅ 測試通過條件

1. **代碼生成**
   - [ ] UDDFParser.swift 生成，行數 250-350
   - [ ] UDDFParserTests.swift 生成，行數 80-120
   - [ ] 編譯無誤 (0 errors, 0 warnings)

2. **測試覆蓋**
   - [ ] 單元測試 7+ 個
   - [ ] 覆蓋率 > 85%
   - [ ] 所有測試通過 (7/7 ✅)

3. **功能驗證**
   - [ ] 能解析簡單 UDDF 檔案
   - [ ] 正確映射所有欄位
   - [ ] 正確處理缺失選擇欄位
   - [ ] 正確拋出異常 (invalid format, corrupted)

4. **效率驗證**
   - [ ] 總時間 < 90 分鐘? 
   - [ ] 代碼品質高? (註釋清晰、命名規範)
   - [ ] 可直接用於生產?

### ❌ 測試失敗條件

- 編譯失敗 (errors 或過多 warnings)
- 單元測試覆蓋率 < 80%
- 邊界情況處理不當 (例如缺 location 時 crash)
- 總時間 > 2 小時

---

## 測試記錄

### 時間戳

```
開始時間：[待填]
─────────────────────────────

【Phase 1 - 格式分析】
開始：[待填]
完成：[待填]
耗時：[待填]
狀態：[ ] ✅ 完成

【Phase 2 - 代碼生成】
開始：[待填]
完成：[待填]
耗時：[待填]
行數：[待填]
狀態：[ ] ✅ 完成

【Phase 3 - 單元測試】
開始：[待填]
完成：[待填]
耗時：[待填]
覆蓋率：[待填]
狀態：[ ] ✅ 完成

【Phase 4 - 編譯驗證】
開始：[待填]
完成：[待填]
耗時：[待填]
編譯結果：[ ] 0 errors, 0 warnings
測試結果：[ ] 7/7 通過
狀態：[ ] ✅ 完成

─────────────────────────────
結束時間：[待填]
總耗時：[待填]
最終評估：[ ] ✅ 通過 / [ ] ❌ 失敗

評估說明：
[待填]
```

---

## 後續步驟

### 若 ✅ 測試通過
→ UDDF 解析器可投入生產  
→ 確認 2 小時時程可行性  
→ 其他 6 種格式可套用同樣流程  
→ 12 週計劃 **強烈確認可行**

### 若 ❌ 測試失敗
→ 分析瓶頸（代碼複雜度？測試困難？）  
→ 調整流程或時程  
→ 重新測試其他簡單格式

---

**測試目標**: 驗證「PM 6 小時/週 + Claude Code Agent」模式的可行性

**預期結果**: 若此測試在 2 小時內通過，則 12 週計劃有 95% 機率成功 ✅
