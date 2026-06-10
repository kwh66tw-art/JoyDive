# JoyDive² v1.1 Backlog

> 本文件整合所有 v1.0 之後待處理的問題與功能。  
> 最後更新：2026-06-08

---

## 🔴 技術債（程式碼問題，非功能）

### 1. 補齊 3 個 UI 字串的多語系翻譯

**影響**：非英文用戶在「編輯潛水」頁（DiveLogEditSheet）會看到英文 fallback。  
**檔案**：`Localizable.xcstrings`  
**缺漏 key（共 3 個，16 種語言均缺）**：

| Key | 使用位置 |
|-----|---------|
| `Not Recorded` | 氣體混合 / 水溫 / 能見度 picker 預設選項 |
| `Air Temperature: Not recorded` | 氣溫顯示 fallback |
| `Visibility: Not recorded` | 能見度顯示 fallback |

**範本翻譯**（繁中）：
- `Not Recorded` → `未記錄`
- `Air Temperature: Not recorded` → `氣溫：未記錄`
- `Visibility: Not recorded` → `能見度：未記錄`

需補齊：de / el / en-GB / es / fr / hr / id / it / ja / ko / ms / nl / pt-PT / th / vi / zh-Hans / zh-Hant

---

### 2. 清除殭屍 xcstrings key

**影響**：無功能影響，僅 xcstrings 垃圾。  
**檔案**：`Localizable.xcstrings`  
**處理**：刪除 key `JD2 Logbook`（已無任何 Swift 檔案使用此 key）

---

### 3. PremiumUpgradeSheet Restore 錯誤無回饋

**影響**：用戶點「Restore Purchase」失敗時，錯誤被 `try?` 吞掉，沒有 alert 顯示。  
**檔案**：`SettingsView.swift` — `PremiumUpgradeSheet.body`  
**修法**：改用 `do { try await AppStore.sync() } catch { showErrorAlert(error) }`，與 SettingsView 主視圖的 Restore 行為一致。

---

## 🟡 功能擴充

### 4. 互動式潛水剖面圖

**背景**：v1.0 剖面圖為靜態折線，無法在特定點查看深度 / 水溫。  
**需求**：點擊或懸停任一點，顯示當下深度、水溫、ceiling / NDT（若有 Bühlmann 計算）。  
**前置**：`profileSamplesJSON` 格式需從 `{t, d}` 擴充為 `{t, d, temp}`，各匯入器同步補 per-sample 水溫寫入。  
**影響範圍**：所有 importer、DiveLogDetailView  
**注意**：與「組織艙飽和度」功能同步規劃，避免 importer 改兩次。

---

### 5. 組織艙飽和度視覺化（Bühlmann ZHL-16C）

**背景**：技術潛水者需要 CNS / OTU / ceiling / NDT 資訊（類 Suunto DM5 風格）。  
**實作**：不匯入任何新欄位，從現有 `profileSamplesJSON`（深度時間序列）+ `gasMixJSON` 在 app 內重新計算。  
**影響範圍**：新增 `BuhlmannCalculator` 模組（獨立，可單獨開發測試）、DiveLogDetailView 新增減壓分析頁籤。

---

### 6. importExtrasJSON 通道欄位

**背景**：各格式含有大量無對應欄位的原始資料（rating / CNS / OTU / 裝置序號等），v1.0 全部丟棄。  
**設計**：`DiveLog` 新增 `var importExtrasJSON: String = "{}"`，匯入時將無對應欄位的資料以 key-value dump 進此 JSON。Detail view 加可折疊「原始資料」區塊。  
**影響範圍**：DiveLog.swift（+1 欄，需 SwiftData migration）、各 importer、DiveLogDetailView  
**注意**：migration 自動補空 `{}`，無需手動處理。

---

### 7. 裝置序號 / 韌體 — 專屬欄位

**背景**：v1.0 workaround 是附加在 Notes「— Import data —」區塊。  
**設計**：v1.1 遷移至 `importExtrasJSON`（見上方），或視需求新增獨立欄位。  
**影響範圍**：隨 importExtrasJSON 同步實作，不獨立排期。

---

### 8. 平均深度 — 專屬欄位

**背景**：v1.0 workaround 同上，存在 Notes 裡。  
**設計**：新增 `avgDepth: Double?` 欄位，需 SwiftData migration。  
**影響範圍**：DiveLog.swift（+1 欄）、各匯入器（補 avgDepth 寫入）、DiveLogDetailView（顯示）

---

### 9. iOS 18 Control Center 擴展

快速存取最近潛水記錄。

---

### 10. iOS 18 Lock Screen Widget

顯示最近潛水或下次潛水倒計時。

---

### 11. 地圖「回到我的位置」recenter 按鈕

目前地圖無 recenter 功能，使用者需手動縮放。

---

### 12. Garmin Connect API JSON（補充方案）

補充 FIT 二進位格式的替代路線，解析 Garmin Connect 匯出的 JSON 格式。

---

### 13. 解析器測試覆蓋率正式驗證（> 85%）

目前未量測，v1.1 跑 `swift test --enable-code-coverage` 確認數字。

---

## 備註

- SwiftData schema 變更（avgDepth、importExtrasJSON）需要 `migrationPlan`，正式 App 升級才不會 crash。
- 互動剖面圖 + 組織艙功能強烈建議同 sprint 規劃，共用 importer 改動。
