# JD2-Logbook v1.0 上線前檢查清單

**目標上線日**：2026 年 8 月 18 日  
**最後更新**：2026-06-03

---

## 🔴 必須完成（Block release）

### 編譯 & 測試
- [ ] 所有 target 編譯無誤（iOS + macOS）
- [ ] 解析器單元測試全部通過（`⌘U`）
- [ ] 解析器測試覆蓋率 > 85%

### 匯入功能
- [ ] UDDF 匯入成功（測試 3+ 檔案）
- [ ] Subsurface XML / .ssrf 匯入成功
- [ ] Subsurface CSV 匯入成功（含多行 notes、引號轉義）
- [ ] Suunto JSON 匯入成功
- [ ] 批量匯入 20+ 檔案，成功率 > 95%
- [ ] 匯入失敗時顯示正確錯誤訊息

### UI 核心功能
- [ ] 日誌列表正常顯示、可滑動
- [ ] 日誌詳情頁所有欄位顯示正確
- [ ] 新增潛水（手動輸入）可儲存
- [ ] 編輯潛水可儲存
- [ ] 刪除潛水有確認 dialog

### 廣告 & IAP（僅 iOS；macOS 無廣告、無 IAP，2026-07-14 起為純免費版）
- [ ] AdMob 廣告在真機上正常載入顯示（Logbook / Import / Settings）
- [ ] 廣告載入失敗時不留空白塊（自動收合）
- [ ] Premium 用戶廣告自動隱藏
- [ ] IAP「Remove Ads $1.99」購買流程完整
- [ ] Restore Purchase 可恢復購買記錄

### 本地化
- [ ] 繁體中文顯示正確（主要目標語言）
- [ ] 英文（en）顯示正確
- [ ] 簡體中文（zh-Hans）顯示正確
- [ ] 日文（ja）抽樣驗證
- [ ] 韓文（ko）抽樣驗證
- [ ] 主要歐洲語言（fr / de / es / it）抽樣驗證
- [ ] 東南亞語言（id / ms / vi / th）抽樣驗證
- [ ] 日期 / 時間格式隨語言本地化
- [ ] 數字單位（深度 m/ft、溫度 °C/°F）顯示正確

---

## 🟡 建議完成（強烈建議，影響審核通過率）

### GPS & 地圖
- [ ] 新增潛水可記錄 GPS 座標
- [ ] 地圖正確顯示潛點 pin
- [ ] 地圖空狀態顯示正常

### 可達性 WCAG 2.1 AA
- [ ] 色彩對比 ≥ 4.5:1（主要文字）
- [ ] 所有互動元素 VoiceOver label 正確
- [ ] 觸控目標 ≥ 44×44pt
- [ ] Dynamic Type 放大不破版
- [ ] 詳見 `WCAG_2.1_AA_AUDIT_CHECKLIST.md`

### 性能
- [ ] 日誌列表滑動流暢（60fps）
- [ ] 地圖載入 100+ 潛點 < 200ms
- [ ] 冷啟動時間合理（< 3 秒）

### 穩定性
- [ ] 模擬器連續操作 30 分鐘無閃退
- [ ] 真機測試無閃退
- [ ] 記憶體無明顯洩漏

---

## 🟢 App Store 提審準備

### 帳號 & 簽署
- [ ] Bundle ID 確認（App Store Connect 已建立）
- [ ] Signing Certificate & Provisioning Profile 正常
- [ ] Version 1.0 (1) 確認
- [ ] Archive 成功

### App Store Connect
- [ ] App 名稱、副標題填寫
- [ ] 描述（繁中 + 英文）
- [ ] 關鍵字填寫
- [ ] 截圖（iPhone 6.7"、iPad 可選）上傳
- [ ] App 圖示 1024×1024 上傳
- [ ] 隱私政策 URL 填寫
- [ ] 年齡分級填寫（4+）
- [ ] 廣告聲明勾選（含廣告）
- [ ] IAP 項目在 App Store Connect 建立並審核通過

---

## ✅ 已完成

- [x] 所有 target 部署目標統一 iOS 17.0 / macOS 14.0
- [x] 死碼清理（ContentView、placeholder views 等）
- [x] DiveLog.buddy 欄位移除
- [x] DiveLogEditSheet macOS O₂ 重複顯示 bug 修正
- [x] AdMob SDK v11 接入（App ID + 4 個 Ad Unit ID）
- [x] i18n 18 種語言實裝（xcstrings）

---

## 🟢 已列 v1.1（本次不需處理）

- iOS 18 Control Center 擴展
- iOS 18 Lock Screen Widget
- 地圖「回到我的位置」recenter 按鈕
- 測試覆蓋率 > 85% 驗證
