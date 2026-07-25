# 已知問題 & v1.1 規劃

**最後更新**：2026-07-25

---

## ✅ 已解決（原「待決策事項」，2026-07-25 解決）

| 項目 | 說明 | 解決方式 |
|------|------|---------|
| macOS/iOS `LSApplicationCategoryType` 誤觸發遊戲模式 | `Info.plist` 原設為 `public.app-category.sports-games`（Apple 分類體系裡「運動類電玩遊戲」子分類，非「運動」本身），會讓 iOS 18+/macOS 系統把 App 誤判為遊戲，觸發 Game Mode／Game Center 相關行為（iOS 端曾出現「遊戲模式：已開啟」橫幅）。已改為 `public.app-category.healthcare-fitness`；App Store Connect 的 Category 欄位同步改為 Health & Fitness。iOS + macOS 皆已用真機／直接雙擊安裝版驗證修復生效（不需要等這次送審核准）。詳見 `V1_2_BACKLOG.md` #1b |

---

## v1.0 已知限制

| 項目 | 說明 | 影響 | 排定版本 |
|------|------|------|---------|
| 廣告在 macOS 無法顯示 | GoogleMobileAds SDK 不支援 macOS | 可接受，設計選擇 | 不排入 |
| macOS 無 Premium／IAP 購買選項 | 2026-07-14 移除：macOS 本來就無廣告可移除，且未確認 iOS/macOS 是否為 Universal Purchase（同一 App Store Connect app 記錄），保留購買選項對 macOS-only 用戶形同賣一個沒有效果的商品。`SettingsView.swift` 的 Premium Section、`PremiumUpgradeSheet` 呼叫、`restorePurchases()` 均已 `#if os(iOS)` 包住，macOS 直接當免費版上架 | 已修復，macOS 現在是純免費版 | 已解決 |
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

### xcodebuild test / TEST_HOST（2026-07-17 修復）
- App 產品從 `JD2-Logbook` 改名為 `JoyDive²` 時，`project.pbxproj` 的 `JD2-LogbookTests` target `TEST_HOST` 未同步更新（殘留 `JD2-Logbook.app`），且 9 個測試檔案的 `@testable import JD2_Logbook` 也未同步（實際模組名為 `JoyDive_`，由 `JoyDive²` 消毒特殊字元而來）
- 兩者皆已修復；未來若再變更 `PRODUCT_NAME`，記得同步檢查這兩處，否則 `xcodebuild test` 會直接建置失敗

### Supabase 專案（非本專案技術棧，勿誤認為有整合）
- `AlgorithmConstants.swift` 有一個常數 `supabaseSampleIntervalSec`（取樣間隔用途），純屬巧合命名，**與 Supabase 服務無關**，全專案無任何 Supabase SDK / API 串接
- 2026-07-13：收到 Supabase 通知，帳號下有一個閒置專案 `joydive`（ID `vumixtjvsyudmwnbpvyz`）暫停 85 天、即將永久凍結。查證程式碼確認無串接，判斷為早期評估階段殘留；PM 決定還原保留（非棄用），但**目前與未來都不計劃整合**
- 確認 [JD2-ultra](../../JD2-ultra) 的同步架構也不需要 Supabase：companion ↔ Logbook 走 Apple **CloudKit**（container `iCloud.com.joydive.divelog`），watch ↔ companion 走 WatchConnectivity，兩專案皆與 Supabase 無關
- 若未來要規劃雲端同步，請先查閱 `JD2-ultra/JD2-ultra_決策.md` §4.1.1 的 CloudKit 方案，避免重複造輪子或誤用閒置的 Supabase 專案

---

## v1.1 功能規劃

> ⚠️ **本節僅列清單，完整設計說明與最新決策一律以 `V1_1_BACKLOG.md` 為準**（此檔案曾在 2026-06-07～07-14 間漏未同步 3 項技術債，避免重蹈覆轍，此後不在兩處維護同一份細節）。

**狀態（2026-07-17）：13/14 項完工**，僅 #9/#10 因 PM 確認不需要而終止規劃。

**技術債**（`V1_1_BACKLOG.md` #1–3）：
- [x] 補齊 3 個 UI 字串多語系翻譯（`Not Recorded` 等，16 種語言）
- [x] 清除殭屍 xcstrings key（`JD2 Logbook`）
- [x] PremiumUpgradeSheet Restore 錯誤無回饋（`try?` 吞錯誤）

**功能擴充**（`V1_1_BACKLOG.md` #4–14）：
- [x] 互動式潛水剖面圖 + 組織艙飽和度視覺化（#4/#5，port Ultra `DiveKit`，取代本地死碼 `Buhlmann.swift`/`DiveEngine.swift`）
- [x] importExtrasJSON / 裝置序號韌體 / 平均深度欄位（#6/#7/#8）
- [x] ~~iOS 18 Control Center 擴展、Lock Screen Widget（#9/#10）~~ — PM 2026-07-17 確認不需要，終止規劃
- [x] 地圖「回到我的位置」recenter 按鈕（#11）
- [x] Garmin Connect API JSON（#12）
- [x] 解析器測試覆蓋率 > 85% 正式驗證（#13：`DiveLogImporter.swift` 89.1%）
- [x] Export/Import 備份功能（#14）

---

## v1.0 修復的舊問題（供參考）

| 問題 | 修復 commit |
|------|------------|
| macOS DiveLogEditSheet O₂ 重複顯示 | `56dc1a3` |
| navigationTitle("") 產生空字串 key | `49abcc9` |
| 部署目標不統一（17.6 / 26.5 混雜） | `deda6ca` |
| AdMob SDK v11 API 不相容 | `656a246` |
| PremiumAwareAdBanner 壓縮上方內容 | `656a246` |
