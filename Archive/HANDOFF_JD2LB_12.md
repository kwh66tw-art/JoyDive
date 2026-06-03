# JD2-Logbook 交接手冊 #11（2026-06-01）

接續 HANDOFF_JD2LB_10。本輪由收尾階段完成大量修正並 git commit。

---

## 一、專案現況

- iOS + macOS（SwiftUI / SwiftData）潛水日誌 App，雙平台共用大部分 View。
- **可編譯、可執行**（FitFileParser 編譯阻塞早已解決＝Xcode 套件快取問題，非程式）。
- 部署目標：app target iOS 26.5；tests/uitests 為 iOS 17.6 / macOS 14.6（見下「待辦」不一致項）。
- 專案用 **fileSystemSynchronizedGroups**：新增/刪除 .swift 檔會自動進出 build，**不需手動改 pbxproj**（刪檔安全）。

## 二、本輪已完成並 commit（重點）

- **日期/時間**：新增/編輯改用單一 date+time picker（移除年+12宮格）；`dateTime` 以 `entryTime` 為準；出水＝入水＋時長；詳情/編輯/匯入時間皆顯示日期。時長一律顯示分鐘（XX min），列表總時間改 `Xh Ym`。
- **日曆**：macOS 也顯示當日清單，含 focus 框、方向鍵導覽、自動聚焦、右鍵選單選取游標項；iOS 當日清單用 List（左滑刪除）。
- **刪除潛水**：List 左滑＋context menu、詳情頁刪除鈕（含確認）、日曆當日清單；macOS 刪除同步清空右側詳情。
- **裝備欄位 Optional 化**：`wetsuitThickness/weightTotal/cylinderMaterial/cylinderSize/cylinderStartPressure` 改 Optional；匯入未提供則詳情頁隱藏該列；新增手動仍預填預設值。防寒衣顯示補回「mm」。
  - ⚠️ SwiftData schema 變更：既有「舊」匯入資料仍帶舊預設值，需重新匯入才會空白。首次執行若崩潰需重置模擬器資料庫。
- **移除匯出功能**：刪 `DiveExporter.swift`、`ActivityView.swift`；Settings/詳情頁移除所有匯出 UI/文案；IAP 改為「僅移除廣告」。
- **廣告版位**：日誌主畫面 + 設定頁底部新增 `PremiumAwareAdBanner`（非 Premium）。但 **AdMob 為空殼**（見待辦）。
- **WCAG**：macOS 卡片/日期格補 a11y action；對比改善（tertiary→secondary、新增 `Color.accessibleSecondary` 達標灰套用 StatsHeader/KeyStatCell/DetailRow/SheetStatCell）；FormatCard 可換行＋a11y label；裝飾圖示隱藏。詳見 `WCAG_2.1_AA_AUDIT_CHECKLIST.md` 附錄。
- **i18n**：匯入 **V6.8 → V7.2** 校訂（修韓文5筆誤填日文、zh-Hans 殘留英文、pt-PT 混荷蘭文、印尼文混中文字、Trimix 簡中誤繁體）；中文用詞統一（Nitrox/EANx/Enriched→高氧，Gas Mix/Trimix→混合氣體）。根治 `.navigationTitle("")` 造成的空字串 key 反覆被抽取（改 `Text(verbatim:"")`）。**最新 i18n 檔＝`JD2-Logbook_i18n_review_V7.2.csv`（其餘版本已由 PM 刪除）**。

## 三、#2 交叉 review 發現的死碼／待清（皆已確認未被引用）

1. **`ContentView.swift`**：Xcode 樣板殘留（`Text("Hello, world!")`），App 入口用 `MainTabView`，**未被引用** → 可刪。
2. **`Views/Settings/SettingsPlaceholderView.swift`、`Views/Map/MapPlaceholderView.swift`**：placeholder，未被引用 → 可刪（連帶可清 `Settings coming soon` / `Map view coming soon` / `future update` 等字串）。
3. **`JD2Core/Models/DiveLogTests.swift`**：被編進 app 正式 target 的自製測試 runner（死碼）→ 移除或移到測試 target。
4. **`DiveLog.buddy` 欄位**（model L117）：UI 已移除 Buddy，欄位與相關字串（`Buddy Name (optional)`、`No buddy recorded.`）殘留 → 評估移除。
5. **過時註解**：`MainTabView.swift` 一句 `Edit/Export 100% 渲染穩定`（Export 已移除）。

## 四、v1.0 待辦（尚未做）

- **部署目標不一致**：app target = iOS 26.5 且未設 `MACOSX_DEPLOYMENT_TARGET`；tests/uitests = iOS 17.6 / macOS 14.6 → 統一。
- **AdMob 正式接入**（PM 決定擱置，等有帳號）：目前 SDK 未加入、無 `GADMobileAds.start()`、無 `GADApplicationIdentifier`。啟用步驟見 `AdBannerView.swift` 開頭註解。
  - ⚠️ **release 風險**：未接 SDK 時佔位框（「Ad Banner · …」）在正式版也會顯示。建議把佔位框限定 `#if DEBUG`，避免上線露出假廣告框。（PM 尚未拍板是否現在做）
- **iOS 18 widgets**（PM 認定 v1.0 非必要 → 列 v1.1）：Control Center 擴展、Lock Screen Widget 未實作（需新增 Widget Extension target）。App Icon 的 light/dark/tinted 變體**已完成**。
- **測試覆蓋率 / 各格式匯入成功率驗證**（P0-3，未做）。
- **地圖「回到我的位置」recenter 按鈕**（PM 決定移到下一版）。
- **WCAG 殘餘**：屬 SwiftUI/Inspector 對 Dynamic Type 與 combine 節點對比的**已知誤報**＋系統元件＋框架雜訊，已документ化為已知限制；以實機 VoiceOver / 真實對比驗收，勿追 Inspector 絕對數字。
- **repo housekeeping**：`.gitignore`（排除 `*.lock`、`*.backup`、`build_*.log`、暫存 CSV、`.DS_Store`）；大量未追蹤暫存檔。
- **v1.0 上線前完整檢查清單**。

## 五、重要慣例／雷區

- **勿手動腳本編輯 pbxproj**（曾破壞檔案）。同步資料夾下純刪/增 .swift 檔安全。
- **git index.lock 反覆殘留**：commit 報 `Unable to create index.lock` 時，確認無 git 程序後 `rm -f .git/index.lock .git/HEAD.lock` 再試（Cowork 沙箱無權刪，需在 Mac 端）。
- **xcstrings 空 `""` key**：來源（`navigationTitle("")`、`TextField("")`）已改 verbatim 根治；若再出現，找新的空字面 localizable 來源。
- **回報慣例**：雙平台改動需明確標註涵蓋平台；改 code 後先停、等 PM build 確認再 commit。

## 六、最近 git 提交（節錄）

```
49abcc9 fix(i18n): navigationTitle("") 改 verbatim 根治空字串 key
84b7b47 i18n: 匯入 V7.2 校訂
682087c i18n: 匯入 V6.8 校訂 + 中文用詞統一
5c0a8dd a11y/feat: WCAG 修正 + 廣告版位 + 裝備Optional
cd3fac1 feat/refactor: 裝備Optional + 移除匯出 + 刪除功能 + i18n V6.7
ca2a77e fix/feat(logbook): 日期時間統一 + 日曆焦點/方向鍵 + 出入水顯示日期
```

**交接時間**：2026-06-01　**狀態**：可編譯可執行；i18n/WCAG/匯出移除/刪除功能/裝備Optional 已收尾並 commit。
