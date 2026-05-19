# JD2-Logbook 稽核報告：Week 7 Garmin FIT Parser (FitFileParser)

**日期**：2026-05-19
**稽核員**：首席技術架構師與品質稽核專家 (Agent)
**目標模組**：`JD2Core/Importers/DiveLogImporter.swift` -> `GarminDescentParser`
**測試狀態**：❌ 失敗 (20 個 XCTest failures)

---

## 1. 稽核目標與範圍
本次稽核針對 Week 7 引入的 Garmin `.fit` 檔案解析器進行邏輯與安全性審查。專案已放棄自行撰寫二進位解析，改為使用成熟的 `roznet/FitFileParser` 套件。
目前的實作程式碼已完成編譯，但在單元測試階段遭遇全數失敗，主要錯誤為：`parsingFailed("session[0] 找不到 max_depth")`。

## 2. 程式碼優點與通過項目 (Passed)
- ✅ **解析模式安全**：使用了 `parsingType: .generic` 初始化 `FitFileParser`，這能確保底層 C SDK 正確抓取非預設的擴充訊息（如 GMN 268 `dive_summary` 與 GMN 269 `dive_gas`），避免因為 SDK 版本落差導致資料被忽略。
- ✅ **記憶體安全 (Memory Safety)**：`hasFITMagic` 採用了原生的 `Data` 下標讀取（例如 `data[8] == 0x2E`），並且在存取前已明確實作 `guard data.count >= Self.fitMinHeaderSize` 防護，完美避免了 OOB (Out-of-Bounds) 崩潰風險。
- ✅ **介面實作合規**：完整遵循 `DiveLogImporter` 的協議規範，針對異常狀態（如 `isEmpty`、不合法的 magic bytes）有明確且具體的 Error 拋出。

## 3. 嚴重風險與邏輯缺陷 (Critical Risks)
經過深度稽核，確認導致 20 個測試案例全滅的核心原因為「對第三方套件 API 的取值假設錯誤」。

### 3.1 致命缺陷：過度依賴 `valueUnit`
```swift
// 錯誤範例
if let d = summary?.interpretedField(key: "max_depth")?.valueUnit?.value { ... }
```
**分析**：
`FitFileParser` 的 `valueUnit` 屬性，只有在該欄位「具備明確度量單位（例如 'm', 's', '%' 等字串）」時才會被賦值。在大部分 Garmin FIT 檔案中，深度 (`max_depth`) 或時間可能只是一個純數字（浮點或整數），此時 `valueUnit` 會回傳 `nil`。
Claude 目前的寫法導致可選鏈 (Optional Chaining) 直接斷裂，使得原本應該取得到的數據被判定為 `nil`，進而觸發 `throw` 中斷解析流程。

### 3.2 潛在的 Key 命名不匹配
雖然 FIT SDK 定義 `max_depth`，但套件在映射到字典時，字串 Key 可能是 `"max_depth_m"`、`"depth_max"` 等其他變體。直接寫死 `"max_depth"` 存在極高風險。

## 4. 修復建議與 Action Items

為了確保解析器的穩定性與 App 的安全性，必須採取以下重構與除錯步驟：

### 階段一：強制診斷 (Diagnostic Bypass)
不可憑空猜測套件的行為。必須在 `GarminDescentParser` 內部加入 Debug 程式碼：
1. **印出真實結構**：在 `sessions` 的迴圈開頭，加入 `print` 將 `session.interpretedFields()` 與 `summary.interpretedFields()` 的所有 Key 與 Value 印出。
2. **繞過崩潰**：暫時註解掉 `throw DiveLogImportError.parsingFailed`，並給予假數值（如 `let maxDepth = 0.0`），確保測試檔案能順利跑完全程，讓開發團隊（PM）能在 Xcode Console 獲取所有真實的 Keys。

### 階段二：實作安全取值邏輯 (Safe Extraction Refactor)
取得真實的 Key 之後：
1. **捨棄 `valueUnit` 依賴**：改用更安全的型別轉換。若套件無提供 `.doubleValue` 等安全屬性，可將 `FitFieldValue` 轉為字串後，再透過 `Double()` 解析。
2. **補強氣體回退邏輯 (Gas Fallback)**：`oxygen_content` 若為標準空氣 (Air)，FIT 可能不紀錄（為 `nil`），回退至 `21.0` 是正確的，但要確保型別匹配。
3. **單位驗證**：根據 Debug 日誌確認 `total_elapsed_time` 是否已被套件除以 1000 轉為秒數。若是毫秒，則需手動 ` / 1000.0`。

---
**總結**：整體架構方向正確，依賴 SPM 套件是明智之舉。修正上述「取值邏輯」後，即可達到生產環境要求的穩定度。
