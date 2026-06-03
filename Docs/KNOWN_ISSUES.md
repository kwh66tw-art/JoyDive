# 已知問題 & v1.1 規劃

**最後更新**：2026-06-03

---

## v1.0 已知限制

| 項目 | 說明 | 影響 | 排定版本 |
|------|------|------|---------|
| iOS 18 Control Center 擴展 | 尚未實作 | 低，iOS 18 新功能 | v1.1 |
| iOS 18 Lock Screen Widget | 尚未實作 | 低，iOS 18 新功能 | v1.1 |
| 地圖 recenter 按鈕 | 地圖無「回到我的位置」按鈕 | 低，使用者仍可手動縮放 | v1.1 |
| 解析器測試覆蓋率 | 未正式量測是否 > 85% | 中 | v1.1 |
| 廣告在 macOS 無法顯示 | GoogleMobileAds SDK 不支援 macOS | 可接受，設計選擇 | 不排入 |

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

---

## v1.0 修復的舊問題（供參考）

| 問題 | 修復 commit |
|------|------------|
| macOS DiveLogEditSheet O₂ 重複顯示 | `56dc1a3` |
| navigationTitle("") 產生空字串 key | `49abcc9` |
| 部署目標不統一（17.6 / 26.5 混雜） | `deda6ca` |
| AdMob SDK v11 API 不相容 | `656a246` |
| PremiumAwareAdBanner 壓縮上方內容 | `656a246` |
