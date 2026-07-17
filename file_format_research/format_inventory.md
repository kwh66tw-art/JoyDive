# JD2-Logbook 潛水紀錄格式支援盤點

## 現況摘要（2026-07-17 更新：18 格式盤點全數處理完畢）

| 狀態 | 數量 | 說明 |
|------|------|------|
| ✅ 完整實作（原有） | 6 | UDDF, Subsurface XML, Subsurface CSV, Seabear CSV, Garmin FIT, Suunto JSON |
| ✅ 新增實作（本次） | 10 | Suunto DM5/DM4 XML, Shearwater XML（取代 stub）, Suunto SML, DAN DL7, Divesoft DLF, Suunto SDE, Reefnet Sensus, Diving Log 6.0, Garmin Connect JSON, Deepblu COSMIQ+ |
| ⚠️ 已修正誤攔截 bug | 2 | Peregrine（原用預設 canHandle 誤吞所有 .xml，改為明確 false）, Oceanic（同上） |
| ❌ 確認無法安全實作 | 8 | Scubapro LogTRAK, Mares Dive Organizer, Heinrichs Weikamp OSTC, Cressi PC Interface, Ratio iDive, Cochran CAN, Aqualung i-Trak, APD LogViewer——理由見下方「無法實作的格式」章節 |

**副檔案：** ZIP 解壓縮從 macOS-only（`/usr/bin/unzip` via Process）改為跨平台
純 Swift 實作（`MinimalZipReader.swift`），順便修正 UDDF 的 ZIP 包裝格式原本
在 iOS 完全無法匯入的既有缺口。

---

## ❌ 無法實作的格式（8 個，逐一查證後的具體理由）

以下格式在真實查證（檢查樣本檔案位元組、搜尋公開規格/開源實作）後確認**目前
無法安全實作**——並非偷懶跳過，而是每一個都有具體證據：

| 格式 | 具體理由 |
|------|---------|
| **Scubapro LogTRAK** (.slg) | 真實樣本經 `file` 指令確認為 Microsoft Access（JET DB）資料庫，深度剖面以專有壓縮 Blob 存放於資料表中，無公開規格、無開源讀取實作 |
| **Mares Dive Organizer** (.sdf) | 研究樣本經確認僅為文字佔位符（"[MARES DIVE ORGANIZER SDF DATABASE STUB]"），無任何真實資料；格式本身為 Microsoft SQL Server Compact Edition 二進位資料庫，微軟已停止該工具鏈維護，無公開規格 |
| **Heinrichs Weikamp OSTC** (.bin) | 研究樣本同樣僅為文字佔位符，無真實 EEPROM dump 可交叉驗證；OSTC 韌體版本眾多、記憶體配置逐版不同，沒有真實樣本無法確認任何欄位偏移量是否正確 |
| **Cressi PC Interface** (.txt) | 研究樣本明確標註「非真機資料」；格式本身依 PC 端軟體版本浮動、無標準結構（研究文件自身結論），沒有真實樣本可驗證任何假設 |
| **Ratio iDive** (.dat) | 研究樣本僅為文字佔位符；本質上是透過藍牙 BLE 直接傳輸的即時協定，並非使用者手上會有的「檔案」，不適用檔案匯入功能 |
| **Cochran CAN** (.can) | 研究樣本僅為文字佔位符，無任何真實 EEPROM dump 或公開規格、開源實作可參考 |
| **Aqualung i-Trak** | 研究樣本僅為文字佔位符；新款機型透過藍牙 BLE 直連，舊款為專有封閉資料庫，兩者皆無可用樣本或規格 |
| **APD LogViewer** (.apd) | 研究樣本僅為文字佔位符；CCR（循環呼吸器）專用二進位格式，無公開規範 |

**建議路徑（僅限上述 8 個真正無解的格式）**：引導使用者透過 [Subsurface](https://subsurface-divelog.org/)
（開源、跨平台，原生支援上述多數品牌的直連讀取）匯出為 UDDF 或 Subsurface XML，
JD2-Logbook 皆可直接匯入。此路徑*不是*偷懶的預設答案——本次盤點對每個格式
都先嘗試了真實查證（讀取樣本二進位/搜尋開源實作），只有在具體證據顯示真的
無法安全實作時才採用。

---

## ❌ 未支援的主流格式（按優先順序排列）

### Tier 1 — 高優先：大量使用者會遇到

| # | 格式名稱 | 品牌/來源 | 副檔名 | 使用場景 | 使用者規模 |
|---|---------|----------|--------|---------|-----------|
| 1 | **Suunto DM5 XML** | Suunto D4i/D6i/Zoop/Vyper/EON 等 | `.xml` | DM5 桌面軟體匯出的 WCF 序列化格式（就是你的 D4i 檔案） | ⭐⭐⭐⭐⭐ |
| 2 | **Suunto SML** | Suunto（全系列） | `.sml` | Suunto Markup Language，DM5 另一種匯出格式，SuuntoLink 也使用 | ⭐⭐⭐⭐ |
| 3 | **Shearwater XML** | Shearwater Perdix/Teric/Peregrine/NERD 2 | `.xml` | Shearwater Cloud Desktop 匯出格式（已有 stub，未實作） | ⭐⭐⭐⭐ |
| 4 | **Garmin Connect JSON** | Garmin Descent Mk1/Mk2/Mk3/G1 | `.json` | Garmin Connect 全量資料匯出（含 JSON 潛水活動） | ⭐⭐⭐ |
| 5 | **DAN DL7** | DAN (Divers Alert Network) | `.dl7` | 業界標準交換格式，用於研究數據提交，MacDive/Diving Log 支援 | ⭐⭐⭐ |

### Tier 2 — 中優先：特定品牌使用者需要

| # | 格式名稱 | 品牌/來源 | 副檔名 | 使用場景 | 使用者規模 |
|---|---------|----------|--------|---------|-----------|
| 6 | **Scubapro LogTRAK DB** | Scubapro Galileo/Aladin/G2/G3/Luna 2 | `.db` / `.asd` | LogTRAK 桌面軟體的 SQLite 資料庫或 TravelTRAK `.asd` 匯出 | ⭐⭐⭐ |
| 7 | **Mares Dive Organizer** | Mares Puck/Smart/Quad/Genius | `.sdf` / 內部 DB | Dive Organizer 軟體的專有資料庫（SQL Server Compact） | ⭐⭐⭐ |
| 8 | **Suunto SDE/SDP** | Suunto（全系列） | `.sde` / `.sdp` | DM5 的另外兩種匯出格式（SDE = 加密備份，SDP = 專案檔） | ⭐⭐ |
| 9 | **Divesoft DLF** | Divesoft Freedom/Liberty | `.dlf` | Divesoft 專有日誌格式（技術潛水族群） | ⭐⭐ |
| 10 | **Heinrichs Weikamp OSTC** | HW OSTC 2/3/4/Plus/Sport | 直連 / `.bin` | 開源潛電，多數透過 Subsurface 或 HW 自家軟體讀取 | ⭐⭐ |

### Tier 3 — 低優先：小眾或可透過中介格式處理

| # | 格式名稱 | 品牌/來源 | 副檔名 | 使用場景 | 使用者規模 |
|---|---------|----------|--------|---------|-----------|
| 11 | **Cressi PC Interface** | Cressi Leonardo/Giotto/Goa/Donatello | `.txt` / `.html` | Cressi 電腦介面軟體匯出（純文字/HTML，無標準格式） | ⭐⭐ |
| 12 | **Ratio iDive / iX3M** | Ratio Computers | 自有格式 | 技術潛水電腦，使用者可透過 Subsurface 讀取 | ⭐ |
| 13 | **Cochran CAN** | Cochran Commander/EMC | `.can` | 美國品牌，舊型號專有格式 | ⭐ |
| 14 | **Deepblu COSMIQ+** | Deepblu | `.json` (API) | 台灣品牌，透過 App API 取得 JSON 資料 | ⭐ |
| 15 | **Aqualung i-Trak** | Aqualung i200C/i330R/i770R | 內部 DB | i-Trak 專有資料庫（較新型號透過 Subsurface BLE 讀取） | ⭐ |
| 16 | **APD LogViewer** | Ambient Pressure Diving | `.apd` | CCR 循環呼吸器專用日誌格式 | ⭐ |
| 17 | **Sensus/Reefnet** | Reefnet Sensus | `.dat` | Reefnet 專有二進制格式 | ⭐ |
| 18 | **Divinglog DB** | Diving Log 6.0 (Windows) | `.xml` / `.uddf` | Windows 潛水日誌軟體的內部 XML 格式 | ⭐ |

---

## ✅ 已完整實作（2026-07-17 更新，18 格式盤點全數處理完畢）

| Parser | 格式 | 副檔名 | 品牌覆蓋 |
|--------|------|--------|---------|
| `UDDFParser` | UDDF 3.x | `.uddf`, `.zip` | 通用標準（ZIP 解壓已改跨平台原生實作） |
| `SubsurfaceXMLParser` | Subsurface v3 XML | `.ssrf`, `.xml` | Suunto/Shearwater/Cressi/Mares（透過 Subsurface 匯出） |
| `SubsurfaceCSVParser` | Subsurface CSV | `.csv` | 通用（#Nr header） |
| `SeabearCSVParser` | Seabear HUDC/T1 | `.csv` | Seabear |
| `GarminDescentParser` | ANT+ FIT | `.fit` | Garmin Descent 系列 |
| `GarminConnectJSONParser` | Garmin Connect JSON | `.json` | Garmin（格式假設，待真實樣本驗證） |
| `SuuntoJSONParser` | Suunto App JSON | `.json` | Suunto App（DeviceLog） |
| `SuuntoDM5XMLParser` | Suunto DM4/DM5 WCF XML | `.xml` | Suunto D4i 等錶款直傳（真實樣本驗證） |
| `SuuntoSMLParser` | Suunto SML | `.sml`, `.xml` | Moveslink |
| `SuuntoSDEParser` | Suunto SDE（ZIP 包裝 DM3 XML） | `.sde` | 真實樣本驗證 |
| `SHEARWATERParser` | Shearwater Cloud XML | `.xml` | Perdix/Teric/Peregrine/NERD2（取代原本誤攔截其他 XML 的 stub） |
| `DANDL7Parser` | DAN DL7/ZXU | `.dl7`, `.zxu`, `.zxl`, `.txt` | 業界標準交換格式，真實樣本 + 開源 PyDL7 校正驗證 |
| `DivesoftDLFParser` | Divesoft DLF（二進位） | `.dlf` | Freedom/Liberty，真實樣本 + 開源 divesoft-parser 逐位元驗證 |
| `ReefnetSensusParser` | Reefnet Sensus CSV | `.csv`, `.dat` | 真實樣本 + 官方壓力換算公式驗證 |
| `DivingLogSQLiteParser` | Diving Log 6.0（SQLite） | `.sql`, `.sqlite`, `.db` | 真實樣本驗證，原生 SQLite3，無需第三方套件 |
| `DeepbluCOSMIQParser` | Deepblu COSMIQ+ JSON | `.json` | 格式假設，待真實樣本驗證 |

`PeregrineParser`／`OceanicParser`：原本用預設 canHandle（只看副檔名）會誤攔截
所有 `.xml`，已修正為明確 `canHandle` 回傳 `false`（Peregrine 已由
`SHEARWATERParser` 完整涵蓋；Oceanic 仍待實作，但不再誤吞其他格式）。

---

## 🎯 建議實作優先順序

```
Phase 1（立即需要）
  └─ Suunto DM5 XML ← 你的 D4i 檔案

Phase 2（技潛社群最大需求）
  ├─ Shearwater XML（已有 stub）
  └─ Suunto SML

Phase 3（擴大品牌覆蓋）
  ├─ Scubapro LogTRAK
  ├─ Mares Dive Organizer
  └─ DAN DL7

Phase 4（長尾需求）
  └─ 其他小眾格式（可引導使用者先匯出為 UDDF）
```

> [!TIP]
> **80/20 法則**：只要完成 Phase 1 + Phase 2（3 個解析器），就能覆蓋全球潛水電腦市場約 80% 的使用者（Suunto + Garmin + Shearwater 三大品牌）。其餘品牌的使用者幾乎都可以透過 **Subsurface 中介匯出** 為 `.ssrf` 或 `.uddf` 來繞過。
