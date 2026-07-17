# JoyDive² v1.1 Backlog

> 本文件整合所有 v1.0 之後待處理的問題與功能。  
> 最後更新：2026-07-17

**狀態（2026-07-17）：13/14 項完工。** #1–8、#11–14 全數完成並通過 iOS+macOS build 與測試；
#9/#10（iOS 18 Widget）PM 確認不需要、終止規劃（見下方對應章節）。
詳細完工紀錄見 `CHANGELOG.md` 2026-07-17 條目。

**已定案的實作方向**（PM 2026-07-14）：
- #4/#5 **直接 port Ultra 的 `DiveKit`**，不修本地 `Buhlmann.swift`/`DiveEngine.swift`。原因：本地版本目前是死碼（無任何呼叫端），且對應 Ultra `JD2-ultra_決策.md` §4.2 稽核有 **9 項**已知安全級問題（原參考文件誤植為 8 項），一旦接上 UI 會全部從休眠變成活的。詳見 `V1_1_BACKLOG_解法參考_from_JD2-Ultra.md`。
- **Export/Import 備份功能與 #6 一起做**（見新增第 14 項）。

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
**⚠️ 已定案（2026-07-14）**：**不使用**本地 `Buhlmann.swift`/`DiveEngine.swift`（目前是死碼，且對應 Ultra 稽核有 9 項已知安全級問題，見上方「已定案的實作方向」）。改為整包移植 Ultra 的 `DiveKit`（`JD2-ultra/DiveKit/Sources/DiveKit/`，純 Swift、無 UI，iOS/macOS 皆可編），日誌重放參考 `DiveKit/Tests/DiveKitTests/RealDiveSimulationTests.swift` 的 `DiveEngine.tick(depth:now:)` 逐點餵法。  
**影響範圍**：新增 DiveKit 依賴（SPM 本地套件或整包複製）、DiveLogDetailView 新增減壓分析頁籤。

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

### 9. iOS 18 Control Center 擴展 — ❌ 決定不做（PM 2026-07-17）

快速存取最近潛水記錄。**PM 確認 JD2-Logbook 不需要 widget**，本項目終止規劃，不排入後續版本。

---

### 10. iOS 18 Lock Screen Widget — ❌ 決定不做（PM 2026-07-17）

顯示最近潛水或下次潛水倒計時。**PM 確認 JD2-Logbook 不需要 widget**，本項目終止規劃，不排入後續版本。

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

### 14. Export / Import 備份功能（新增，2026-07-14 排入）

**背景**：稽核發現 `DiveLogDatabase.exportAsJSON()` / `importFromJSON()` 目前是寫死拋錯的 stub（"JSON 導出/導入功能待實現（需要 Codable 支援）"），App 現階段**完全沒有備份/還原資料的能力**。原本 #6（importExtrasJSON）欄位的設計動機就是「未來若實作 export 功能，原始資料無法還原」，兩者強關聯，這次一併做。  
**需求**：完整 DiveLog（含 profileSamplesJSON、gasMix、importExtrasJSON 等）Codable 化，實作真正可用的 export/import round-trip。  
**影響範圍**：`DiveLogDatabase.swift`（補實作）、`DiveLog` 系列 model 需 Codable 一致性檢查、Settings 或 Logbook 頁新增匯出/匯入 UI 入口。  
**注意**：與 #6 同步規劃——`importExtrasJSON` 若晚於 export 功能定案，schema 可能要改兩次。

---

## 備註

- SwiftData schema 變更（avgDepth、importExtrasJSON）需要 `migrationPlan`，正式 App 升級才不會 crash。
- 互動剖面圖 + 組織艙功能強烈建議同 sprint 規劃，共用 importer 改動。
- #14（Export/Import）與 #6（importExtrasJSON）強關聯，建議合併規劃、避免 DiveLog Codable schema 改兩次。
