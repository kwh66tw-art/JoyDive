# JD2-Logbook 檔案格式技術調查評估
**版本**: 1.0  
**日期**: 2026 年 5 月 17 日  
**目的**: 評估 7 種潛水日誌格式的技術複雜度與實作工作量

---

## 1. 已確認支援的 4 種格式（v1.0 核心）

### 1.1 UDDF (Universal Dive Data Format)

**格式規範**
```
檔案類型：XML (zip 壓縮包)
副檔名：.uddf
編碼：UTF-8
標準：ISO 12639:2015
```

**技術特性**
- ✅ 開放標準，設計最完整
- ✅ 包含完整減壓資訊、溫度曲線、氣體切換
- ✅ 支援元數據（教練、認證、潛伴）
- ⚠️ 複雜的 XML 結構（需要 XPath 解析）
- ⚠️ 某些潛水電腦廠商實作不完整

**主要元素結構**
```xml
<uddf>
  <dives>
    <dive number="1">
      <datetime>2026-05-15T10:30:00</datetime>
      <site>...</site>
      <depth>
        <max>25.5</max>
        <avg>15.2</avg>
      </depth>
      <duration>3300</duration> <!-- 秒 -->
      <temperature>
        <water>18.5</water>
      </temperature>
      <samples> <!-- 深度曲線採樣 -->
        <sample>
          <time>0</time>
          <depth>0.0</depth>
          <temp>18.5</temp>
          <pressure>200</pressure>
        </sample>
        ...
      </samples>
      <gasmix>...</gasmix> <!-- 氣體配置 -->
    </dive>
  </dives>
</uddf>
```

**實作複雜度**：🔴 高
- 工作量：50h
- 難點：XML 解析、zip 檔案處理、數據驗證
- 測試檔案需求：5-10 個真實檔案

**支援的潛水電腦**
- Shearwater Teric、Peregrine
- Garmin Descent（部分）
- Cressi 部分型號
- Aqualung i750（部分）

---

### 1.2 SHEARWATER Cloud XML

**格式規範**
```
檔案類型：XML
副檔名：.xml（由 Shearwater Cloud 匯出）
編碼：UTF-8
廠商：Shearwater Research
```

**技術特性**
- ✅ 較 UDDF 簡潔，容易解析
- ✅ 包含深度曲線、溫度、壓力數據
- ✅ 時間戳精確到秒
- ⚠️ 不是開放標準，受廠商控制
- ⚠️ 版本更新可能改變結構

**主要元素結構**
```xml
<divelog>
  <dive>
    <number>1</number>
    <date>2026-05-15</date>
    <time>10:30:00</time>
    <location>...</location>
    <depth_max>25.5</depth_max>
    <duration>3300</duration>
    <temperature>18.5</temperature>
    <samples>
      <sample>
        <time>0</time>
        <depth>0.0</depth>
        <temperature>18.5</temperature>
        <alarm_flag>false</alarm_flag>
      </sample>
      ...
    </samples>
  </dive>
</divelog>
```

**實作複雜度**：🟠 中等
- 工作量：45h
- 難點：版本相容性、XPath 選擇
- 測試檔案需求：5 個（新版、舊版各 2-3 個）

**支援的潛水電腦**
- Shearwater Teric、Peregrine（主）
- 透過 Shearwater Cloud 匯出

---

### 1.3 Peregrine

**格式規範**
```
檔案類型：XML
副檔名：.xml（由 Peregrine 設備產生）
編碼：UTF-8
廠商：Shearwater Research（新品牌）
```

**技術特性**
- ✅ 新一代設備（2023+），市場成長快
- ✅ 結構清晰，基於 SHEARWATER
- ✅ 包含 AI 減壓演算參數
- ⚠️ 新格式，文檔可能不完整

**主要元素結構**
```xml
<peregrine_log>
  <dive>
    <dive_number>1</dive_number>
    <start_time>2026-05-15T10:30:00Z</start_time>
    <location>Reef 1</location>
    <max_depth>25.5</max_depth>
    <duration_seconds>3300</duration_seconds>
    <water_temperature>18.5</water_temperature>
    <samples>
      <sample>
        <elapsed_seconds>0</elapsed_seconds>
        <depth>0.0</depth>
        <temperature>18.5</temperature>
        <ppO2>0.21</ppO2> <!-- Nitrox 支援 -->
      </sample>
      ...
    </samples>
    <deco_stop> <!-- 減壓信息 -->
      <depth>5.0</depth>
      <duration>180</duration>
    </deco_stop>
  </dive>
</peregrine_log>
```

**實作複雜度**：🟠 中等
- 工作量：40h
- 難點：ppO2 計算驗證、減壓資訊解析
- 測試檔案需求：5 個（不同潛水模式）

**支援的潛水電腦**
- Shearwater Peregrine（專用）

---

### 1.4 Cressi/Mares CSV

**格式規範**
```
檔案類型：CSV (逗號分隔)
副檔名：.csv
編碼：UTF-8 或 ISO-8859-1
分隔符：, (逗號)
```

**技術特性**
- ✅ 最簡單的格式，純文本
- ✅ 容易手動編輯與驗證
- ✅ 廣泛使用（Cressi、Mares、Aqualung 部分）
- ⚠️ 無標準化，廠商實作差異大
- ⚠️ 無深度曲線數據

**主要欄位結構**
```
Date,Time,Location,Depth(m),Duration(min),Temperature(C),Notes
2026-05-15,10:30,Reef 1,25.5,55,18.5,Good visibility
2026-05-14,14:00,Wreck 2,22.0,48,19.0,Strong current
```

**實作複雜度**：🟡 低
- 工作量：35h
- 難點：欄位對應、數據驗證、錯誤處理
- 測試檔案需求：10 個（不同廠商、編碼）

**支援的潛水電腦**
- Cressi (EDY 系列)
- Mares (SmartCom)
- Aqualung i450

---

## 2. 新增支援的 3 種格式（v1.0 擴展）

### 2.1 Garmin Descent XML

**格式規範**
```
檔案類型：XML
副檔名：.xml（由 Garmin Connect 或 Descent 應用匯出）
編碼：UTF-8
廠商：Garmin
標準：Garmin FIT 的 XML 轉換
```

**技術特性**
- ✅ Garmin 手錶（fenix、Descent、Enduro）的官方格式
- ✅ 市場佔有率高（運動手錶生態）
- ✅ 支援多種運動數據（潛水、游泳、登山）
- ⚠️ 元素繁雜，非潛水專屬
- ⚠️ 有多個版本與變體

**主要元素結構**
```xml
<TrainingCenterDatabase>
  <Courses>
    <Course>
      <Name>Dive 001</Name>
      <Lap StartTime="2026-05-15T10:30:00Z">
        <TotalTimeSeconds>3300</TotalTimeSeconds>
        <DistanceMeters>0</DistanceMeters> <!-- 無距離概念 -->
        <MaximumSpeed>0</MaximumSpeed>
        <Track>
          <Trackpoint>
            <Time>2026-05-15T10:30:00Z</Time>
            <Position>
              <LatitudeDegrees>25.3456</LatitudeDegrees>
              <LongitudeDegrees>121.5678</LongitudeDegrees>
            </Position>
            <AltitudeMeters>-25.5</AltitudeMeters> <!-- 負數表示深度 -->
            <HeartRateBpm>
              <Value>65</Value>
            </HeartRateBpm>
            <Extensions>
              <ns2:TPX>
                <ns2:Speed>0</ns2:Speed>
                <ns2:Core>
                  <!-- 深度、溫度等擴展欄位 -->
                </ns2:Core>
              </ns2:TPX>
            </Extensions>
          </Trackpoint>
          ...
        </Track>
      </Lap>
    </Course>
  </Courses>
</TrainingCenterDatabase>
```

**實作複雜度**：🔴 高
- 工作量：55h
- 難點：
  - 巨大的 XML 結構（需要選擇性解析）
  - 深度儲存在 `AltitudeMeters` 負數中
  - 支援心率、溫度等非深度數據的混淆
  - 多個 namespace 和擴展欄位
  - 相容多個 Garmin 設備變體
- 測試檔案需求：8 個（Descent Mk1/Mk2、fenix 不同版本）

**支援的潛水電腦**
- Garmin Descent Mk1、Mk2、Mk3
- Garmin fenix 6X/7X/8（部分）
- Garmin Enduro（部分）

---

### 2.2 Suunto SDE/XML/SDP

**格式規範**
```
檔案類型：多種
- SDE (binary) - Suunto Dive Engine 專屬二進位
- XML - Suunto Mobile 匯出
- SDP - Suunto Dive Profile 文本
副檔名：.sde, .xml, .sdp
廠商：Suunto
標準：廠商專屬（無開放規範）
```

**技術特性**
- ✅ Suunto Zoop/D4/EON 等系列覆蓋廣
- ✅ 市場佔有率高（尤其歐洲與南美）
- ⚠️ 格式複雜且多變，無官方文檔
- ⚠️ SDE 二進位格式需逆向工程
- ⚠️ 版本眾多，相容性問題多

**三種子格式詳解**

#### 2.2.1 Suunto SDE (Binary)
```
檔案結構（逆向工程結果）：
├─ Header (固定)
│  ├─ Magic bytes: "SDE" + version
│  ├─ Device model ID
│  └─ Checksum
├─ Dive table
│  └─ Dive #1-N (variable length records)
│     ├─ Timestamp
│     ├─ Location string
│     ├─ Duration
│     ├─ Max depth
│     ├─ Sample count
│     └─ Temperature min/max
└─ Sample pool
   └─ Individual sample records (深度、溫度採樣)

難點：
- 無官方規範，需透過社群資源逆向
- 字節序（big-endian vs little-endian）
- 壓縮算法（某些版本使用 zlib 壓縮）
- 版本相容性（SDE v1-v4+ 結構不同）
```

實作複雜度：🔴 極高
- 工作量：25-30h（若有逆向工程文檔）
- 工作量：50-60h（若需自行逆向工程）
- 難點：
  - 無官方文檔，需依賴開源社群（如 Subsurface）
  - 多版本相容性
  - 二進位解析（Swift 中對齊、字節序處理）
  - 檢查和驗證困難

#### 2.2.2 Suunto XML
```xml
<suunto_log>
  <dive>
    <dive_id>1</dive_id>
    <start_time>2026-05-15 10:30:00</start_time>
    <location>Reef</location>
    <duration_seconds>3300</duration_seconds>
    <max_depth>25.5</max_depth>
    <water_temp>18.5</water_temp>
    <dive_computer_model>D4i Novo</dive_computer_model>
    <depth_profile>
      <sample>
        <time_offset>0</time_offset>
        <depth>0.0</depth>
        <temperature>18.5</temperature>
      </sample>
      ...
    </depth_profile>
  </dive>
</suunto_log>
```

實作複雜度：🟠 中等
- 工作量：15-18h
- 難點：版本變化、非標準 XML 屬性

#### 2.2.3 Suunto SDP (Text)
```
格式（文本，逗號分隔）：
Dive,Date,Time,Location,Depth,Duration,Temperature,Deco,Notes
1,2026-05-15,10:30,Reef,25.5,55,18.5,No,Good
```

實作複雜度：🟡 低
- 工作量：8-10h
- 難點：最少

**綜合工作量評估**
```
Suunto 總支援（三種格式並行）：
├─ SDE (Binary) - 若使用開源資源：25-30h
├─ XML - 15-18h
├─ SDP (Text) - 8-10h
└─ 測試與相容性：10-12h
─────────────────────────
總計：58-70h（平均 64h）

風險：SDE 格式缺乏官方支援，高度依賴逆向工程。
若逆向工程遇阻，可能延期 1-2 週。
```

**支援的潛水電腦**
- Suunto Zoop Novo、D4、D4i Novo
- Suunto EON Core
- Suunto EON Steel (舊)

---

### 2.3 Oceanic OCF/XML

**格式規範**
```
檔案類型：XML 與 OCF (Oceanic Custom Format)
副檔名：.ocf, .xml（Oceanic+ 應用匯出）
編碼：UTF-8
廠商：Oceanic WorldWide
標準：廠商專屬
```

**技術特性**
- ✅ Oceanic Pro Plus、Geo 等系列廣泛
- ✅ Oceanic+ 應用 (2020+) 支援現代界面
- ⚠️ OCF 二進位格式複雜度中等
- ⚠️ DiverLog（Oceanic 官方日誌應用）有變體
- ⚠️ 相容性不如 SHEARWATER

**主要格式**

#### 2.3.1 Oceanic OCF (Binary)
```
檔案結構（部分逆向工程）：
├─ Header
│  ├─ Magic: "OCNC" (Oceanic)
│  ├─ Version
│  └─ Device model
├─ Dive records
│  ├─ DateTime
│  ├─ Location
│  ├─ Depth profile (compressed)
│  └─ Metadata
└─ Footer (checksum)

特性：
- Zlib 壓縮的深度曲線
- 變長記錄格式
- 不同機型有不同版本
```

實作複雜度：🔴 高
- 工作量：20-25h
- 難點：壓縮處理、多版本相容性

#### 2.3.2 Oceanic XML / DiverLog
```xml
<oceanic_divelog>
  <dive number="1">
    <date>2026-05-15</date>
    <time>10:30:00</time>
    <location>Reef</location>
    <bottom_time>3300</bottom_time> <!-- 秒 -->
    <max_depth>25.5</max_depth>
    <avg_depth>15.2</avg_depth>
    <water_temp>18.5</water_temp>
    <dive_computer>Pro Plus 3.0</dive_computer>
    <profile>
      <point>
        <time>0</time>
        <depth>0.0</depth>
        <temp>18.5</temp>
      </point>
      ...
    </profile>
  </dive>
</oceanic_divelog>
```

實作複雜度：🟠 中等
- 工作量：15-18h
- 難點：多版本變體

**綜合工作量評估**
```
Oceanic 總支援（OCF + XML）：
├─ OCF (Binary) - 20-25h
├─ XML/DiverLog - 15-18h
└─ 測試與相容性：8-10h
─────────────────────────
總計：43-53h（平均 48h）

風險：OCF 二進位格式文檔不足，可能需要逆向。
```

**支援的潛水電腦**
- Oceanic Pro Plus、Geo
- Oceanic Geo 2.0
- Oceanic+ 應用（所有型號）

---

## 3. 工作量總結與時間表

### 3.1 格式支援工作量對比

| 格式 | 複雜度 | 工作量(h) | 難度等級 | 測試檔案需求 |
|------|--------|---------|---------|-----------|
| **UDDF** | 🔴 高 | 50 | ⭐⭐⭐⭐ | 10 |
| **SHEARWATER** | 🟠 中 | 45 | ⭐⭐⭐ | 5 |
| **Peregrine** | 🟠 中 | 40 | ⭐⭐⭐ | 5 |
| **Cressi/Mares** | 🟡 低 | 35 | ⭐⭐ | 10 |
| **---** | | | | |
| **Garmin Descent** | 🔴 高 | 55 | ⭐⭐⭐⭐ | 8 |
| **Suunto** | 🔴 極高 | 64 | ⭐⭐⭐⭐⭐ | 15 |
| **Oceanic** | 🔴 高 | 48 | ⭐⭐⭐⭐ | 12 |

### 3.2 v1.0 版本時間表重新計算

#### **原計劃（4 種格式）**
```
Week 1-2：基礎搭建（24h）
Week 3-5：4 種解析器（170h）
  ├─ UDDF: 50h
  ├─ SHEARWATER: 45h
  ├─ Peregrine: 40h
  └─ Cressi: 35h
Week 6-8：日誌管理 + GPS（163h）
Week 9-10：廣告 + IAP（96h）
Week 11-13：測試 + 上線（133h）
─────────────────────────
總計：13-14 週，586h
```

#### **新計劃（7 種格式）**
```
Week 1-2：基礎搭建（24h）
Week 3-8：7 種解析器（380h） ← 擴展 3 週
  ├─ UDDF: 50h
  ├─ SHEARWATER: 45h
  ├─ Peregrine: 40h
  ├─ Cressi: 35h
  ├─ Garmin Descent: 55h ⭐ 新增
  ├─ Suunto: 64h ⭐ 新增
  └─ Oceanic: 48h ⭐ 新增
Week 9-11：日誌管理 + GPS（163h）
Week 12-13：廣告 + IAP（96h）
Week 14-17：測試 + 上線（150h） ← 延長測試時間
─────────────────────────
總計：17-18 週，813h

新增工作量：+227h (+39%)
時間延期：+3-4 週（從 14 週 → 17-18 週）
```

### 3.3 團隊配置建議

**假設 2-3 人開發團隊**

```
配置 A：2 人團隊（sequential）
├─ Dev 1：負責 UDDF, Shearwater, Peregrine (135h)
├─ Dev 2：負責 Cressi, Garmin, Oceanic (131h)
└─ Lead：Suunto + 整合 + Code Review (64h)
─────────────────────────
時間表：18 週（假設週 40 小時，加班/重疊）

配置 B：3 人團隊（parallel）
├─ Dev 1：UDDF, Shearwater, Peregrine (135h)
├─ Dev 2：Cressi, Garmin, Oceanic (131h)
├─ Dev 3：Suunto SDE + XML + SDP (64h)
└─ Lead：整合、Code Review、風險管理
─────────────────────────
時間表：12-14 週（更可行）
推薦：此配置
```

---

## 4. 風險評估與緩解策略

### 4.1 技術風險

| 風險 | 概率 | 影響 | 緩解策略 |
|------|------|------|--------|
| **Suunto SDE 逆向工程失敗** | 25% | 🔴 高 | ① 優先依賴 Subsurface 開源代碼 ② 若不可行，降級為僅支援 XML+SDP ③ 時間預留 2 週 |
| **Garmin XML 解析複雜度超期** | 20% | 🟠 中 | ① 使用第三方 XML 庫（Swift XMLDecoder）簡化 ② 預留 1 週彈性 |
| **Oceanic OCF 二進位相容性** | 30% | 🟠 中 | ① 需要真實設備測試 ② 若無硬體，預留文獻研究 2-3 天 |
| **測試檔案不足** | 40% | 🟡 低 | ① 透過社群論壇、GitHub 尋找範例檔案 ② 聯繫設備製造商（PADI dive shops 可能有） |
| **版本相容性爆炸** | 35% | 🟠 中 | ① 採用 defensive parsing（非標準格式不中斷） ② 文件列舉每個支援版本 |

### 4.2 管理風險

| 風險 | 概率 | 影響 | 緩解策略 |
|------|------|------|--------|
| **工期延期至 18-20 週** | 45% | 🔴 高 | ① 每週 checkpoint，監控進度 ② 若超期 >1 週，考慮延遲次要格式 ③ 預留 Week 18 決策窗口 |
| **團隊人力不足** | 30% | 🟠 中 | ① 3 人配置更可行（vs 2 人） ② 聯繫自由職業者支援複雜格式 |
| **品質下降（缺陷率上升）** | 50% | 🟠 中 | ① 每個格式至少 3+ 單元測試 ② 延長 integration testing ③ Beta 階段擴大用戶群（100+ vs 50） |
| **App Store 審核延遲** | 15% | 🟡 低 | ① 提前提審（Week 16），預留 2 週重審 |

---

## 5. 技術實作建議

### 5.1 解析器架構

```swift
// 統一的解析器協議
protocol DiveLogParser {
    associatedtype Output = [DiveLog]
    func parse(fileURL: URL) throws -> Output
    func validate(logs: [DiveLog]) -> ParsingValidation
}

// 廠商實作
final class UDDFParser: DiveLogParser { ... }
final class SHEARWATERParser: DiveLogParser { ... }
final class PeregrineParser: DiveLogParser { ... }
final class CressiMaResParser: DiveLogParser { ... }
final class GarminDescentParser: DiveLogParser { ... }
final class SuuntoParser: DiveLogParser { ... }       // SDE + XML + SDP 統一
final class OceanicParser: DiveLogParser { ... }     // OCF + XML 統一

// 協調器（單一進入點）
class MultiFormatDiveLogImporter {
    func importFromFile(_ url: URL) async throws -> [DiveLog] {
        let fileExt = url.pathExtension.lowercased()
        
        // 檔案副檔名 → 解析器對應
        let parser: DiveLogParser = switch fileExt {
        case "uddf":
            UDDFParser()
        case "xml":
            // 偵測 XML 類型 (Shearwater/Peregrine/Garmin/Suunto/Oceanic)
            try detectXMLParser(url)
        case "csv":
            // CSV → Cressi/Mares/Suunto SDP
            try detectCSVParser(url)
        case "sde":
            // Suunto 二進位
            SuuntoParser(format: .sde)
        case "ocf":
            // Oceanic 二進位
            OceanicParser(format: .ocf)
        default:
            throw ImportError.unsupportedFormat
        }
        
        let logs = try parser.parse(fileURL: url)
        let validation = parser.validate(logs: logs)
        return logs
    }
}
```

### 5.2 第三方依賴

```
新增依賴建議：
├─ XMLDecoder (Swift stdlib) - 用於 XML 解析
├─ ZipFoundation (SPM) - 用於 UDDF zip 處理
├─ Checksum libraries (custom) - Suunto/Oceanic 驗證
└─ 可選：Alamofire (若需下載範例)

不需 CocoaPods，保持輕量化。
```

---

## 6. 版本與上線策略

### 6.1 新提議的版本計劃

```
v1.0 "完全支援" (7 種格式)
├─ 上線時間：Week 18 (2026 年 10 月底)
├─ 格式：UDDF + SHEARWATER + Peregrine + Cressi + Garmin + Suunto + Oceanic
├─ 核心功能：GPS 地圖 + 日誌管理 + 廣告 + IAP
├─ 特點：一次性完整支援，無後續格式升級壓力
└─ 工作量：813h

v1.1 "進階功能" (Month 6-12 後開發)
├─ 照片管理 + 進階統計
├─ 潛點標籤 & 搜尋篩選
├─ HealthKit 整合
└─ 次要格式：Aqualung, Deepblu, PADI/SSI
```

### 6.2 商業影響評估

```
正面：
├─ 市場覆蓋 99%+（幾乎所有主流潛水電腦）
├─ 一次性完全格式支援，競爭力強（vs Currents 的漸進支援）
├─ 用戶遷移障礙最低（一次批量匯入所有舊日誌）
└─ 少於 App Store 更新頻率（更少干擾用戶）

挑戰：
├─ 上線延期 4-5 個月（Oct 2026 vs Aug 2026）
├─ 被 Currents、MacDive 搶佔暑期市場
├─ 競爭對手在此期間可能增加功能
└─ 3 人團隊成本增加，時程管理風險

折衷評估：
├─ 若要 Aug 上線 → 維持原 4 種格式方案
├─ 若要完整 7 種 → 接受 Oct 上線
└─ 若要 Sep 上線 → 選擇 5-6 種格式（延遲 Suunto 或 Oceanic）
```

---

## 7. 建議決策方案

### 方案 A：「完整一次性」(推薦給 3 人以上團隊)
```
v1.0 包含所有 7 種格式
├─ 上線時間：Oct 2026（Week 18）
├─ 工作量：813h（3 人團隊 ÷ 18 週）
├─ 優勢：完整市場覆蓋、無後續格式升級、用戶體驗完善
└─ 風險：延期、品質控制、人力成本
```

### 方案 B：「核心優先，漸進擴展」(推薦給 2 人團隊)
```
v1.0：4 種核心格式 (Aug 2026, Week 14) - 70% 市場
├─ UDDF, SHEARWATER, Peregrine, Cressi
├─ GPS 地圖、廣告、IAP
└─ 充足測試時間 (3 週)

v1.0.1：Garmin + Suunto (Sep 2026) - 追加 15%
v1.0.2：Oceanic (Sep 底) - 追加 5%
v2.0+：次要格式 + 進階功能 (Dec 2026+)
```

### 方案 C：「優化折衷」(推薦給 2.5 人團隊)
```
v1.0：5 種格式 (Sep 2026, Week 16) - 85% 市場
├─ 核心 4 種 (UDDF + SHEARWATER + Peregrine + Cressi)
├─ + Garmin (最高需求)
└─ Suunto/Oceanic 延至 v1.0.1

v1.0.1：Suunto + Oceanic (Sep 底，+1-2 週)
```

---

## 8. 推薦行動方案

✅ **建議採用方案 C（優化折衷）**

**理由**：
1. 時間表可控（Sep 2026 上線仍可趕上秋季市場）
2. 品質與速度平衡（5 種格式 ≈ 16 週可達成）
3. Garmin 優先支援（高市場需求）
4. Suunto/Oceanic 快速跟進（2-3 週）
5. 2-3 人團隊都可執行

**實施步驟**：
```
Week 0 (籌備)：
  ✅ 確認團隊配置（2 人 or 3 人）
  ✅ 獲取測試檔案（聯繫社群、PADI 店家）
  ✅ 研究第三方庫（ZipFoundation、XMLDecoder）

Week 1-2：基礎搭建 (不變)
Week 3-6：核心 4 種 + Garmin 解析器 (266h)
Week 7-9：日誌管理 + GPS + Garmin 整合
Week 10-11：廣告 + IAP + 本地化
Week 12-14：測試 + 品質控制
Week 15-16：Bug 修復 + App Store 提審

v1.0 上線：Week 16 (Sep 2026) ✅

Week 17-18：Suunto + Oceanic (130h) 平行開發
v1.0.1 上線：Week 19 (Sep 底 / Oct 初) ✅
```
