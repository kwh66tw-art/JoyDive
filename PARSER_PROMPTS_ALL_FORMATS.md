# 解析器實現 Prompt — 所有 7 種格式
## JD2-Logbook | Week 3-8

---

## 📌 通用驗證框架

每個解析器實現必須遵循此框架：

### 1. 格式驗證
```swift
protocol DiveLogImporter {
    func canHandle(filePath: String) -> Bool      // 檔案副檔名檢查
    func validateContent(_ data: Data) -> Bool    // 內容有效性檢查
    func parse(from filePath: String) throws -> [DiveLog]
}
```

### 2. 數據邊界檢查
```swift
// 必須驗證所有邊界
guard dive.maxDepth >= 0 && dive.maxDepth <= 40 else { throw error }
guard dive.diveTimeSeconds > 0 && dive.diveTimeSeconds <= 14400 else { throw error }
guard !dive.location.isEmpty else { throw error }
// 溫度、GPS、氣體配置等
```

### 3. 單位轉換
- **深度**: feet → meter (÷ 3.28084)
- **溫度**: Fahrenheit → Celsius ((F-32) × 5/9)
- **壓力**: psi → bar (÷ 14.5038)
- **時間**: 毫秒 → 秒

### 4. 錯誤處理
```swift
enum DiveLogImportError: Error, LocalizedError {
    case fileNotFound(String)
    case invalidFormat(String)
    case parsingFailed(String, underlyingError: Error? = nil)
    case unsupportedFormat(String)
    case corruptedData(String)
    case emptyFile
}
```

---

## 🔷 Week 3: UDDF 解析器

### UDDF 格式背景
- **標準**: ISO 12639:2015
- **結構**: ZIP 檔案包含 XML 檔案
- **複雜度**: ⭐⭐⭐⭐⭐ (高)
- **測試檔案**:
  - `test42.uddf` (42 次潛水)
  - `test-apd-inspiration.uddf` (APD Inspiration 電腦)

### 實現要點

#### 1. ZIP 解壓與 XML 解析
必須使用 Foundation 提供的工具，或第三方庫。

#### 2. UDDF XML 結構解析
UDDF 是 ISO 標準，包含完整的潛水數據。

#### 3. 關鍵解析邏輯
- 日期時間組合
- 氣體配置提取
- GPS 座標解析
- 邊界檢查

#### 4. 測試檔案驗證
對兩個測試檔案進行完整驗證。

---

## 🟩 Week 4: SHEARWATER & Peregrine 解析器

### SHEARWATER 格式背景
- **標準**: Shearwater Peregrine (XML)
- **複雜度**: ⭐⭐⭐⭐ (中高)
- **結構**: XML，單檔案，無 ZIP

### Peregrine 特性
Peregrine 是 Shearwater 升級版，新增 PPO2 記錄。

---

## 🟥 Week 5: Cressi/Mares 解析器

### Cressi/Mares 格式背景
- **標準**: CSV (逗號分隔值)
- **複雜度**: ⭐⭐ (低)
- **結構**: 純文本，行導向

### CSV 解析要點
- CSV 標題行識別
- 各欄位映射
- 缺失值處理

---

## 🟨 Week 6: 預留 (彈性週)

根據前幾週進度，可能需要額外時間進行跨格式驗證和效能優化。

---

## 🟦 Week 7: Garmin Descent & Suunto 解析器

### Garmin Descent 格式背景
- **標準**: TCX (複雜多命名空間 XML)
- **複雜度**: ⭐⭐⭐⭐⭐ (最高)
- **特性**: 多層結構、多命名空間、PPO2 記錄

### Suunto 格式背景
- **標準**: SDE (二進制) + XML + SDP
- **複雜度**: ⭐⭐⭐⭐ (中高)
- **特性**: 混合二進制與文本格式

---

## 🟪 Week 8: Oceanic 解析器

### Oceanic 格式背景
- **標準**: OCF (二進制) + XML 包裝 + 壓縮
- **複雜度**: ⭐⭐⭐⭐⭐ (最高)
- **特性**: GZIP 壓縮、多檔案結構

---

## ✅ 通用測試框架

每個解析器都必須通過以下測試：

### Unit Tests
- 格式檢測測試
- 基本解析測試
- 邊界驗證測試
- 計算屬性測試
- 數據庫存儲測試

### Integration Tests
- 單檔案匯入測試
- 統計驗證測試
- 實檔案驗證

---

## 📋 實現檢查清單

對每個解析器，完成以下檢查：

- [ ] 格式驗證
- [ ] XML/文本解析
- [ ] 單位轉換
- [ ] 邊界檢查
- [ ] 日期時間解析
- [ ] 氣體配置
- [ ] 環境類型
- [ ] GPS 座標
- [ ] 錯誤處理
- [ ] 單元測試 (>90%)
- [ ] 實檔案驗證
- [ ] 性能測試
- [ ] Git 提交

---

## 🔗 參考資源

| 格式 | 標準文檔 | 複雜度 | 優先級 |
|------|---------|--------|--------|
| UDDF | ISO 12639:2015 | ⭐⭐⭐⭐⭐ | P0 |
| SHEARWATER | Peregrine XML | ⭐⭐⭐⭐ | P0 |
| Peregrine | Shearwater variant | ⭐⭐⭐⭐ | P0 |
| Cressi/Mares | CSV standard | ⭐⭐ | P1 |
| Garmin | TCX with namespaces | ⭐⭐⭐⭐⭐ | P1 |
| Suunto | Mixed binary/XML | ⭐⭐⭐⭐ | P2 |
| Oceanic | GZIP + ZIP + XML | ⭐⭐⭐⭐⭐ | P2 |

---

**文檔更新**: 2026-05-18  
**下一步**: Week 3 Day 1 實現 UDDF 解析器
