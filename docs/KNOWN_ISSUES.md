# 已知問題 & v1.1 規劃

**最後更新請見 `git log -- docs/KNOWN_ISSUES.md`**（不手動維護日期戳，理由見 `V1_2_BACKLOG.md`「使用方式」）

---

## ✅ 已解決（原「待決策事項」，2026-07-25 解決）

| 項目 | 說明 | 解決方式 |
|------|------|---------|
| macOS/iOS `LSApplicationCategoryType` 誤觸發遊戲模式 | `Info.plist` 原設為 `public.app-category.sports-games`（Apple 分類體系裡「運動類電玩遊戲」子分類，非「運動」本身），會讓 iOS 18+/macOS 系統把 App 誤判為遊戲，觸發 Game Mode／Game Center 相關行為（iOS 端曾出現「遊戲模式：已開啟」橫幅）。已改為 `public.app-category.healthcare-fitness`；App Store Connect 的 Category 欄位同步改為 Health & Fitness。iOS + macOS 皆已用真機／直接雙擊安裝版驗證修復生效（不需要等這次送審核准）。詳見 `V1_2_BACKLOG.md` #1b |
| Trimix 潛水 Edit 後 Save 會靜默把氣體資料降級成 Air（資料損毀） | `DiveLogEditSheet` 的 Gas picker 不支援編輯 trimix，但 `save()` 原本無條件用 picker 顯示值覆寫 `dive.gasMixJSON`。已修：記住原始 JSON，trimix 潛水 save() 時維持不動；picker 對 trimix 加 `.disabled()`。詳見 `V1_2_BACKLOG.md` #18 |
| 配重／氣瓶壓力英制單位未換算 + 剖面圖多語系版面截斷 | `DiveLogEditSheet`／`DiveLogDetailView`／`DiveLogListView` 三處各自獨立寫死 kg/bar/m；`DiveAnalysisView` 剖面圖互動列的 Ceiling/No Deco/Temp 標籤在德/法/泰/越/克羅埃西亞等語言下過長被截斷。已修復單位換算與版面保底（`.minimumScaleFactor`），部分翻譯內容縮短。詳見 `V1_2_BACKLOG.md` #18/#20/#22/#23 |
| `ImportWizardView` 進度/結果畫面完全未走在地化 | `"File X of Y"`／匯入結果訊息原本是純字串插值，不管 App 語言設定永遠顯示英文；旁邊早有 18 語言翻譯的 key 閒置沒被呼叫。已重新接回既有 key。詳見 `V1_2_BACKLOG.md` #21 |
| 3 處統計卡片在 Dynamic Type AX5 極限字級下視覺重疊 | `DiveLogListView`/`DiveLogDetailView`/`DiveSiteSheetView` 的「圖示＋數值＋單位＋標籤」3 欄橫排卡片，共用元件 `DiveKitUI.DiveStatCell` 內建的 `minimumScaleFactor` 只保護單一欄位不溢出，擋不住 3 欄硬擠一列的整體重疊；純程式碼審查沒抓到，模擬器實測（`xcrun simctl ui content_size accessibility-extra-extra-extra-large`）才發現。`DiveStatCell` 是 DiveKit 共用元件不在本 App 改，改為 App 層 3 處呼叫端各自判斷 `dynamicTypeSize.isAccessibilitySize` 切換直式排列。詳見 `WCAG_2.1_AA_AUDIT_CHECKLIST.md` 附錄 2 |
| 真機 VoiceOver 走查抓到 4 個問題（2026-07-27） | ①`DiveLogDetailView.DetailRow` 的 `.accessibilityLabel("\(label): \(value)")` 直接內插未本地化的英文 key（畫面顯示正確中文，VoiceOver 卻唸英文，日文版同樣受影響），改用 `languageManager.localized(label)`；②`DiveLogEditSheet` 的 Entry Time `DatePicker` VoiceOver 朗讀值不吃 `\.environment(\.locale)`（Apple 元件內部行為，畫面顯示正確），改用 `.accessibilityValue()` 蓋掉系統算出來的朗讀值；③「新增潛水」Save 鈕在 `maxDepth == 0` 時靜默停用、無任何視覺/VoiceOver 提示，回報成「無法儲存」，已加可見 footer 提示＋對應 accessibilityLabel/Hint；④「潛水剖面圖」被 2026-07-26 一次翻譯縮短 commit 誤改成語意不同的「潛水曲線」，已改回。詳見 `WCAG_2.1_AA_AUDIT_CHECKLIST.md` 附錄 3 |

---

## v1.0 已知限制

| 項目 | 說明 | 影響 | 排定版本 |
|------|------|------|---------|
| 廣告在 macOS 無法顯示 | GoogleMobileAds SDK 不支援 macOS | 可接受，設計選擇 | 不排入 |
| macOS 無 Premium／IAP 購買選項 | 2026-07-14 移除：macOS 本來就無廣告可移除，且未確認 iOS/macOS 是否為 Universal Purchase（同一 App Store Connect app 記錄），保留購買選項對 macOS-only 用戶形同賣一個沒有效果的商品。`SettingsView.swift` 的 Premium Section、`PremiumUpgradeSheet` 呼叫、`restorePurchases()` 均已 `#if os(iOS)` 包住，macOS 直接當免費版上架 | 已修復，macOS 現在是純免費版 | 已解決 |
| ATMOS UDDF 假預設氣瓶資料 | ATMOS 匯出 UDDF 時，若無實際記錄，仍填入預設值（200/50 bar、110L）。JD2 只負責單位換算，值的正確性由使用者自行確認，匯入後可手動清除。 | 低，使用者知情即可 | 不排入（資料來源問題） |
| 地圖在 VoiceOver 下無法縮放/平移/展開聚合/選其他 pin | 2026-07-27 真機 VoiceOver 完整走查發現（`WCAG_2.1_AA_AUDIT_CHECKLIST.md` 附錄 4/5）。查過 `DiveMapRepresentable.swift`/`DiveSiteAnnotation.swift` 沒有設定錯誤或手勢衝突，判斷為 MapKit 在 VoiceOver 下的固有限制（雙指縮放手勢被 VoiceOver 自己接管）。需要獨立的縮放按鈕＋逐一切換 pin 機制才能解，範圍明確但工程量中等，非小修。 | 中，視障使用者無法用地圖瀏覽潛點，但日誌列表可完全 VoiceOver 操作作為替代路徑 | 排入下一版 backlog（地圖無障礙改造） |
| `DiveRowView.dateBlock` 月/年標籤 Dark Mode 對比不足（已修） | 2026-07-27 用模擬器截圖＋Python/PIL 實測 WCAG 對比公式（非目測）掃過 Dark Mode 主要畫面，抓到日誌列表卡片的「7月/2026」用系統 `.secondary` 只有 3.91:1（低於 4.5:1 門檻），是 2026-06-01 稽核修 `DetailRow`/`StatsHeader` 等處時漏掉的同款元件。已改用 `Color.accessibleSecondary`，複測 9.25:1 通過。同一行的「26°C」水溫標籤有一併複查，實測 5.20:1 本來就過，沒有動。 | 已解決 | 已解決 |
| `DiveReplayEngine.replay()` 整趟潛水只吃單一 `GasMix`，不支援依時間切換氣體 | 家族總指揮 2026-08-16 查證回報：技術潛水常見操作（底部背氣、上升到減壓停留切換高氧氣體如 EAN50）會讓重放引擎在換氣後繼續用底氣組成計算——Interactive Tissue Loading／Ceiling／NDL 在換氣後那段顯示的數字是用錯誤氣體算出來的，不是精細度不足，是答案錯誤。DiveImportKit v0.4.2 新增的 `gasSwitches`（換氣序列，存在 `importExtras`）目前沒有消費端讀取，正是因為這個限制。`docs/APPSTORE_COPY.md` 第25/34/138/147行宣稱支援「advanced technical diving」與 Trimix，未註明此限制，對技術潛水使用者（多氣體換氣是常態操作）現況宣稱不夠準確。 | 高（顯示錯誤的減壓分析數字，非邊緣案例），但屬既有架構限制非本輪改動引入 | 待 PM 排優先序：(a) 若要修，需 Logbook 自行讀取 `gasSwitches` 並讓分析路徑依時間軸切換氣體（新功能，工程量不小）；(b) 若暫不修，行銷文案應加註但書或調整措辭範圍；(c) 短期可比照舊 trimix 免責聲明模式，偵測到 `gasSwitches` 非空時顯示提示 |

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

### 語言切換不生效（`String(localized:)` vs `languageManager.localized(_:)`）— 反覆發生，寫新 View 時注意
- **根因**：`String(localized:)` 讀系統 `Locale.current`，`AppLanguageManager` 切換
  App 內語言時只有「下次啟動」才會反映到系統層；`Text(LocalizedStringKey)` 與
  `languageManager.localized(_:)` 才會跟著 root 的 `.environment(\.locale)` 即時切換。
  只要一個 View 裡有 `String(localized:)`，切換語言後不重開 App 就會殘留舊語言。
- **已發生過 3 次**：v1.1 #8（Import tab）、v1.2 #7（Import tab 另一批）、
  2026-07-26 全專案掃除（10 個檔案、約 90 處，詳見 `V1_2_BACKLOG.md` #17）。
- **寫新 View 時**：一般文字用 `Text("字面量")` 或 `languageManager.localized(_:)`
  皆可（兩者都正確跟隨），但**組 `String`／`accessibilityLabel`／`TextField` placeholder
  等場合絕對不要用 `String(localized:)`**，一律改用 `languageManager.localized(_:)`。
  非 View 型別（`class`/`struct` 不是 SwiftUI View，沒有 Environment 可用，例如
  `DiveSiteAnnotation`）要嘛把已解析好的字串從呼叫端（View）傳進去，要嘛整個型別
  改吃 `AppLanguageManager` 當參數。
- **同病灶的第 5 個變種（2026-07-26 新發現）：`DateFormatter()`／`Calendar.current`／
  `Locale.current`／裸 `.formatted()` 一樣不吃 `\.environment(\.locale)`**——這些是
  Foundation 型別，不是 SwiftUI environment-aware，沒設 `.locale` 一律用系統語言。
  真機測 en/vi/hr 抓到 7 處（Exit Time、月曆星期標題列、12 月網格、列表卡片月份邏輯等），
  已修復並**集中化**：`AppLanguageManager` 新增 `dateFormatter(dateStyle:timeStyle:)`／
  `calendar` 兩個 helper，之後日期/月曆格式化一律經這裡拿，不要再手動
  `DateFormatter()`/`Calendar.current`。已 read-only 查證 JD2-ultra 有同款未修破口
  （`SettingsStore` 跟本專案 `AppLanguageManager` 同一套架構），見
  `_JD2-family/reports/R-2026-07-26-App內語言切換未涵蓋DateFormatter與Calendar.md`。
- **同一天追加發現 2 個相關問題（皆已用 Swift 腳本逐一測過全部 18 語言，非只查
  發現來源語言）**：
  1. **泰文年份顯示佛曆（2569）不是西元年（2026）**——`Locale(identifier: "th")` 的
     CLDR 預設曆法是 `buddhist`，`DateFormatter`/`Calendar` 沒明確指定 `.calendar` 就會
     用佛曆年份。逐一測過全部 18 語言，**只有泰文受影響**。已在
     `dateFormatter(dateStyle:timeStyle:)`／`calendar` 兩個 helper 內強制
     `Calendar(identifier: .gregorian)` 修復（連帶修掉月曆年份 stepper 同一顆雷）。
  2. **越南文日期文字過長導致 UI 換行**——`.medium` dateStyle 產出「ngày 4 thg 6, 2026」，
     18 語言裡最長（24 字元，含「日/月」語意字詞），`DiveLogDetailView` 的 Entry/Exit
     Time 卡片寬度不夠會裁到換行斷字。改用
     `setLocalizedDateFormatFromTemplate("yMdjm")`（純數字日期＋4 位數西元年＋各語系
     自然 12/24 小時制慣例），新增 `AppLanguageManager.numericDateTimeFormatter()`，
     18 語言全部變成純數字、無語意月份字詞，長度也全面縮短（越南文 24→14 字元）。

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
