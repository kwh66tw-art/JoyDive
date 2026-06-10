# 已知問題 & v1.1 規劃

**最後更新**：2026-06-07

---

## v1.0 已知限制

| 項目 | 說明 | 影響 | 排定版本 |
|------|------|------|---------|
| iOS 18 Control Center 擴展 | 尚未實作 | 低，iOS 18 新功能 | v1.1 |
| iOS 18 Lock Screen Widget | 尚未實作 | 低，iOS 18 新功能 | v1.1 |
| 地圖 recenter 按鈕 | 地圖無「回到我的位置」按鈕 | 低，使用者仍可手動縮放 | v1.1 |
| 解析器測試覆蓋率 | 未正式量測是否 > 85% | 中 | v1.1 |
| 廣告在 macOS 無法顯示 | GoogleMobileAds SDK 不支援 macOS | 可接受，設計選擇 | 不排入 |
| ATMOS UDDF 假預設氣瓶資料 | ATMOS 匯出 UDDF 時，若無實際記錄，仍填入預設值（200/50 bar、110L）。JD2 只負責單位換算，值的正確性由使用者自行確認，匯入後可手動清除。 | 低，使用者知情即可 | 不排入（資料來源問題） |

---

## 技術雷區（維護時注意）

### SwiftData Schema 變更
- `buddy` 欄位已於 commit `56dc1a3` 移除（v1.0）
- 未來若再次修改 schema，模擬器舊資料需 Erase All Content and Settings
- 正式 App 升級需處理 migration（SwiftData `migrationPlan`）

### git 操作
- **勿手動腳本編輯 `project.pbxproj`**（曾破壞專案）
- `git index.lock` 殘留時在 Mac 端執行：`rm -f .git/index.lock .git/HEAD.lock`

### `xcstrings` 空 key
- 根治方式：`Text(verbatim: "")` 取代 `Text("")`
- 若新出現空 key，找程式碼中新的空字串 literal

### AdMob SDK v11 API 改名
- `GADBannerView` → `BannerView`
- `GADAdSizeBanner` → `AdSizeBanner`
- `GADRequest` → `Request`
- `GADBannerViewDelegate` → `BannerViewDelegate`
- `GADMobileAds.sharedInstance()` → `MobileAds.shared`（property，非 function）

---

## v1.1 功能規劃

- [ ] iOS 18 Control Center 擴展（快速存取最近潛水）
- [ ] iOS 18 Lock Screen Widget（顯示最近潛水或倒計時）
- [ ] 地圖「回到我的位置」recenter 按鈕
- [ ] 解析器測試覆蓋率 > 85% 正式驗證
- [ ] Garmin Connect API JSON（補充 FIT 格式替代方案）
- [ ] **importExtrasJSON passthrough 欄位**（詳見下方設計說明）
- [ ] **互動式潛水剖面圖**（詳見下方設計說明）
- [ ] **組織艙飽和度視覺化**（詳見下方設計說明）
- [ ] **裝置序號/韌體欄位**（UDDF/FIT 匯入後可顯示潛水電腦型號與韌體版本，需新增 model 欄位）
- [ ] **平均深度欄位**（部分格式提供 mean depth，需新增 model 欄位；或由剖面樣本計算）

### importExtrasJSON — 設計說明

**背景**：各格式（UDDF、Subsurface XML 等）含有大量 app 沒有對應欄位的資料（如 rating、CNS/OTU、裝置序號、平均深度、減壓 ceiling 等）。v1.0 這些資料在匯入時全部丟棄，未來若實作 export 功能，原始資料無法還原。

**設計方案**：在 `DiveLog` 加入一個欄位：
```swift
var importExtrasJSON: String = "{}"
```

- 匯入時，所有「沒有對應 model 欄位」的原始資料以 key-value 形式 dump 進此 JSON
- Detail view 加一個可折疊的「原始資料」區塊（預設收合），顯示此 JSON 的內容
- Export 功能可從此欄位還原完整原始資料
- notes 欄位維持乾淨，不混入 import 結構化資料

**影響範圍**：DiveLog.swift（+1 欄）、各 importer（新增 extras 寫入）、DiveLogDetailView（新增折疊區塊）

**注意**：此改動需 SwiftData migration（現有用戶升級時自動補空 JSON `{}`，無需手動處理）。

---

### 互動式潛水剖面圖 — 設計說明

**背景**：v1.0 剖面圖為靜態折線，無法在特定時間/深度點查看詳細數據。

**需求**：點擊或懸停剖面圖上任一點，顯示該時刻的深度、水溫、及（若有 Bühlmann 計算）ceiling / NDT。

**前置工作**：
- `profileSamplesJSON` 目前每筆只存 `{t, d}`，需擴充為 `{t, d, temp}` 以支援溫度曲線疊加
- 此擴充不影響 DiveLog model schema（純 JSON string），但各 importer 需補充 per-sample 溫度寫入

**影響範圍**：各 importer（per-sample temp 寫入）、DiveLogDetailView（剖面圖互動層）

**注意**：per-sample 溫度擴充應與組織艙功能同步規劃，避免兩次改 importer。

---

### 組織艙飽和度視覺化 — 設計說明

**背景**：技術潛水者（CCR、Trimix）重視減壓資訊，類似 Suunto DM5 的 16 艙室氮/氦飽和度柱狀圖。

**實作方式**：不從匯入取值，而是在 app 內以 Bühlmann ZHL-16 演算法重新計算。

**所需輸入（現有資料已足夠）**：
- `profileSamplesJSON`（時間 + 深度）
- `gasMixJSON`（O₂/He 比例）

**輸出**：每個樣本點的 16 個組織艙 N₂/He 飽和度 → 可渲染飽和度柱狀圖、ceiling 曲線、CNS/OTU 累積曲線

**影響範圍**：新增 `BuhlmannCalculator` 獨立模組（不依賴 importer）、DiveLogDetailView（新增減壓分析頁籤）

**注意**：Bühlmann 為獨立計算模組，與匯入器完全解耦，可單獨開發測試。

---

## v1.0 修復的舊問題（供參考）

| 問題 | 修復 commit |
|------|------------|
| macOS DiveLogEditSheet O₂ 重複顯示 | `56dc1a3` |
| navigationTitle("") 產生空字串 key | `49abcc9` |
| 部署目標不統一（17.6 / 26.5 混雜） | `deda6ca` |
| AdMob SDK v11 API 不相容 | `656a246` |
| PremiumAwareAdBanner 壓縮上方內容 | `656a246` |
