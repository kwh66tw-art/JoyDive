# Changelog

All notable changes to JD2-Logbook will be documented in this file.

Format: `[vX.Y.Z] — YYYY-MM-DD`

---

## [v1.0.0] — 2026-08-18 (目標)

### Added
- 潛水日誌 CRUD（新增、編輯、刪除、列表、詳情）
- 日曆視圖（DiveCalendarView）
- 多格式匯入：UDDF / Subsurface XML / Subsurface CSV / Suunto JSON / Garmin FIT / Shearwater / Seabear CSV / Oceanic
- ImportCoordinator 自動格式偵測與批量匯入
- GPS 座標記錄 + MapKit 地圖顯示（潛點聚類）
- AdMob Banner 廣告（Logbook / Import / Settings / Map 空狀態）
- StoreKit IAP「Remove Ads $1.99」
- 18 種語言本地化（繁中、簡中、英文、日文、韓文、法文、德文、西班牙文、義大利文、荷蘭文、葡萄牙文、印尼文、馬來文、越南文、泰文、希臘文、克羅埃西亞文、英國英文）
- iOS + macOS 雙平台支援
- Bühlmann ZHL-16C 減壓演算法
- WCAG 2.1 AA 可達性合規

### Technical
- SwiftUI + SwiftData，iOS 17+ / macOS 14+
- Swift 6 strict concurrency
- GoogleMobileAds SDK v11 接入
- FitFileParser SPM 套件（Garmin FIT 解析）

---

## [開發階段紀錄]

### 2026-08-16 — 升版 DiveKit v1.8.0 + DiveImportKit v0.4.2

家族總指揮（`JD2-Fami_01`）跨 session 通知兩個獨立修復，PM 同意升版驗證：

- **DiveKit v1.8.0**（`c433427`，隔室1 N2/He 配對一致性修正，"1"→"1b" 變體）：
  影響範圍窄（30-45m 深度轉折的短暫瞬態窗口），穩態最大差異 ceiling +0.65m／
  NDL -46s／ASC TIME -66s，52 筆真實剖面裡 41 筆完全零差異、其餘方向皆為安全
  方向、零反例。額外釐清一個既有的 GF 階梯跳躍時機位移現象（非本次改動引入，
  是既有 `currentGF()` clamp 邏輯對常數微調的通用敏感特徵）。
- **DiveImportKit v0.4.2**（`781a2b7`）：`SubsurfaceXMLParser` 修復一個安全攸關
  的靜默資料錯誤——先前完全不解析 `<cylinder he='...'>` 屬性與
  `<event name='gaschange'>` 換氣事件，代表用 Subsurface XML 格式匯入的 trimix
  潛水，氦氣分率會被靜默丟棄、誤判為 nitrox/air，不會報錯。**這個 bug 對
  Logbook 影響直接**：F5 trimix 繞過已於 2026-07-30 解除、使用者現在會看到
  完整減壓分析，若氦氣從匯入階段就被丟棄，DiveKit 本體修好的雙氣體計算會
  拿到錯的輸入，且方向不安全（氦氣被忽略會讓減壓計算顯示得比實際更寬鬆）。

**驗證**：清 DerivedData 後完整重新 build+test。iOS 測試套件 **81 passed／
5 skipped／0 failed**（86 total，含新增的一項端到端測試）；macOS App build（CLI）
綠；macOS CLI `xcodebuild test` 仍是既有 infra 缺口（`@testable import JoyDive_`
模組解析失敗），沿用先前記錄，非本次改動引入。

新增 `F5DiveKitMigrationE2ETests.testRealSubsurfaceXMLSample_TrimixHeliumSurvivesToAnalysis`：
走 Logbook 自己的完整鏈路（`DiveLogImporterFactory` → `SubsurfaceXMLParser` 本地
薄包裝 → `makeDiveLog` → `JSONDecoder` 解碼 `GasMix` → `DiveReplayEngine.replay`），
用真實 Subsurface 官方測試資料集樣本 dive333（Trimix 18/28→EAN46，
`_JD2-family/dive-log-samples/Subsurface/abitofeverything.ssrf`）驗證：解碼出的
`GasMix.fHe == 0.28`（修復前會是 0），且驅動出非零 He 組織隔室負荷——證明
v0.4.2 的修復真的從真實檔案一路傳到 Logbook 的分析結果，不只是 DiveImportKit
repo 自己的單元測試通過。

`_JD2-family/F-02-COMPAT_MATRIX.md` 已同步更新 Logbook 列（DiveKit v1.8.0／
DiveImportKit v0.4.2／測試數字）。

### 2026-07-30 — 解除 trimix 減壓分析繞過（F5 暫時方案正式結束）

- **背景**：F5 遷移期間（2026-07-18）因 DiveKit 的 `Buhlmann` 尚未支援氦氣，
  `DiveReplayEngine.replay()` 對 trimix 潛水繞過整個減壓生理計算，只顯示
  深度剖面；`DiveAnalysisView` 隱藏 Ceiling/No-Deco/組織艙 UI。前置條件
  （DiveKit v1.5.0 雙氣體 Buhlmann、v1.6.0 DecoCalculator ASC TIME 正式修復、
  v1.7.0 N2 隔室常數修正）皆已完成並經黑盒交叉驗證，家族總指揮正式派工解除
  繞過，詳見 `_JD2-family/decisions/2026-07-18_trimix減壓計算缺口.md`。
- **`DiveReplayEngine.replay()`**：移除 trimix 短路分支，trimix 與 air/nitrox
  走完全相同的 Buhlmann 重放路徑；`ReplayPoint` 新增 `tissueHePressures`
  欄位（air/nitrox 全程為 0，回歸不受影響）；移除已不再需要的
  `ReplayResult.decoDataUnavailable` 旗標。
- **`tissueLoadPercent`（組織艙飽和度視覺化）**：新增 `pHe` 參數，M-value
  改用 N2/He 依分壓比例加權合併（沿用 DiveKit `Buhlmann.combinedAB()`
  同一套規則），避免 trimix 潛水顯示忽略氦氣貢獻、誤導性偏低的組織負荷
  百分比；`pHe` 為 0 時公式退化為原本的純 N2 版本，air/nitrox 逐位元不變。
- **`DiveAnalysisView`**：移除「trimix 尚不支援」的隱藏邏輯與免責聲明文字，
  Ceiling/No-Deco/組織艙長條對所有氣體（含 trimix）皆正常顯示真實計算值。
- **`F5DiveKitMigrationE2ETests.swift`**：原本鎖定「trimix 走短路路徑」的
  測試改為驗證「trimix 走完整路徑、不崩潰、產出合理數字」——用真實 trimix
  樣本（TMx 16/45，Lake Coleridge，max depth 38.97m／時長 83min）端到端
  驗證，健全性檢查（不得 NaN/負值/Infinite）＋確認組織隔室出現非零 He 分壓
  （證明真的有算氦氣，不是繞過殘留）。實測數字：全程 maxCeiling ≈6.16m，
  末端 ceiling ≈1.11m（對應 NDL=0，已進入減壓義務），16 隔室 He 分壓
  0.24–0.84 bar 有意義分布，量級與決策文件記錄的 DiveKit 自有黑盒交叉驗證
  （OVM Dive Planner）范圍一致，未發現失控數值。
- **驗證**：`xcodebuild test`（iOS Simulator，iPhone 17）JD2-LogbookTests
  全套件 78 測試全綠，含新的 trimix E2E 測試；`xcodebuild build`（macOS
  arm64）成功。⚠️ macOS *測試* target 透過 CLI（`xcodebuild test`/
  `build-for-testing`）目前無法執行——`@testable import JoyDive_` 在 macOS
  destination 下回報 "unable to resolve module dependency"，經 `git stash`
  比對確認**此問題在本次改動之前就存在**（未改任何程式碼一樣重現），非
  trimix 改動引入的回歸。`DiveReplayEngine`／`DiveAnalysisView` 皆為無
  `#if os()` 平台分支的共用檔案，iOS 測試套件已完整覆蓋其邏輯；macOS CLI
  測試 infra 缺口記錄為獨立待辦，不阻塞本次任務。
- **家族層待辦**：確認 ultra／immersion 的即時/計劃路徑是否受影響——依決策
  文件記錄，ultra 目前無法建構 `fHe>0` 的 GasMix（已查證結案），immersion
  結構性不用 trimix（已查證結案），本次解除繞過僅影響 Logbook。

### 2026-07-29 — v1.2 (Build 3) 審核通過上架、發現關鍵字策略失敗

- **iOS + macOS 皆通過審核並上架**（2.3.6／5.1.2(i) 兩項拒絕理由修正後過關）。
- **上架後實測發現關鍵字策略失敗**：App Store 搜尋除非直接打「JD2」「JoyDive」
  等品牌詞，否則找不到本產品。現行 Keywords（`dive log,scuba,logbook,
  Shearwater,UDDF,Garmin,Suunto,Subsurface,nitrox,dive computer,freediving`）
  被電腦錶品牌名稱佔掉大半版位，一般用戶的「潛水日誌」核心搜尋意圖詞沒有
  被覆蓋到。已記入 `V1_RELEASE_CHECKLIST.md`「下一版重點工作」列為首要
  任務，下次改版送審前需重新設計三語各自的關鍵字策略。

### 2026-07-28 — v1.2 (Build 3)：iOS 送審駁回二次核查與修正、App Store 文案定版、iOS + macOS 雙平台送出審核

- **5.1.2(i) 隱私追蹤聲明二次核查，發現「已修復」記錄與 ASC 實際狀態不符**：
  `V1_2_BACKLOG.md` #1 先前記錄 2026-07-25 已在 ASC 後台將 Coarse
  Location／Device ID／Usage Data 的追蹤用途改為 No，但本次直接在 ASC 網頁
  逐格點開確認，三格的「Purpose」問卷實際仍勾選著「Third-Party
  Advertising」（Apple 定義下這個勾選即等同宣告追蹤，與先前記錄的「used to
  track: No」是不同的問卷欄位，先前的操作大概率是改到後面的追蹤問題但漏了
  前面的用途勾選）。程式碼面複查結果不變（全專案無 ATT 實作、無 IDFA 存取、
  AdMob 用預設 `Request()` 未傳遞定位/裝置資料、CoreLocation 僅本機一次性
  `requestLocation()`、無任何網路請求程式碼），確認 App 本身沒有追蹤行為，
  問題出在宣告本身。三格皆改為僅勾選「App Functionality」，逐一走完
  Linked-to-identity（No）與 Tracking（No）兩個子問題後 Publish，並重新整理
  頁面截圖驗證三格摘要皆顯示「Used for App Functionality」。
- **2.3.6 Age Rating Advertising 二次確認**：先前記錄的「Advertising = Yes」
  在 ASC 問卷內直接開啟確認為真，未變更。
- **Declare Your Regulated Medical Device 新增聲明**（Apple 新增的強制欄位，
  2027 年前 EU/EEA/UK/US 上架皆須回答）：判定 JoyDive² 不構成醫療器材（不
  診斷/治療/監測疾病，組織艙飽和度為估算功能且文案已明確聲明「僅供參考，
  不能取代你的潛水電腦錶」），回答 No。
- **Build 3 (v1.2) 正式上傳並綁定**：iOS 端先前多次 Archive／上傳皆卡在
  ASC 尚未收到新 build（先前挂著的是 Build 2／v1.0）；本次完成 Xcode
  Archive → Distribute App → Upload（過程遇到 GoogleMobileAds／
  UserMessagingPlatform 缺 dSYM 的無害警告，及一次可重試排除的 App Store
  Connect Credentials Error 逾時），Build 3 上傳成功後在 ASC 移除舊 Build 2、
  綁定 Build 3，Export Compliance 回答「None of the algorithms mentioned
  above」。macOS 端另外走一次相同 Archive／Distribute 流程（macOS 1.0 為
  已核准狀態，需先用 macOS App 旁的「+」建立全新 1.2 版本才能編輯欄位）。
- **App Store 文案三語（English／Chinese Traditional／Japanese）定版套用**：
  依 `docs/APPSTORE_COPY.md` 最終版本，將 Description／Keywords／
  Promotional Text 套用到 iOS App 1.2 三語頁面；套用日文時一度誤操作
  （語言下拉選單點擊未即時生效，文字打進了尚未真正切換過去的繁中頁面），
  幸好尚未存檔即發現並改用重新整理捨棄，改以逐次確認下拉選單勾選狀態後才
  輸入文字的方式修正流程。macOS App 1.2 另建版本後，比照套用同一份三語
  文案＋新版 Screenshots（含使用者自行調整過的正確尺寸）＋What's New
  文案。
- **Review Notes**：iOS 版註明本次修正的兩項駁回理由（2.3.6／5.1.2(i)）
  對應說明；macOS 版因非重審（1.0 為核准狀態的正常升級），改寫簡述本次
  功能更新內容。
- **兩平台皆已送出審核**：iOS App 1.2 (3)、macOS App 1.2 (3) 皆為
  Waiting for Review。

### 2026-07-26 — v1.2 (Build 3)：語系全域掃除、Trimix 存檔資料損毀修復、單位換算補完、稽核報告雙輪查核

- **語言切換殘留問題全域掃除**：確認舊病根因——`String(localized:)` 讀系統
  `Locale.current`，語言切換後不重開 App 不會反映；`Text(LocalizedStringKey)`／
  `languageManager.localized(_:)` 才會即時跟隨。全專案掃過 `SettingsView`／
  `DiveLogEditSheet`／`DiveLogDetailView`／`DiveCalendarView`／`MapView`／
  `DiveAnalysisView`／`DiveLogListView`／`MainTabView`／`LogbookContainerView`／
  `DiveMapRepresentable`／`DiveSiteAnnotation`（非 View 型別，改吃呼叫端已解析
  字串）／`GasMix+LocalizedDisplay.swift`，全部改對，實際呼叫 0 處殘留。
- **`ImportWizardView` 進度/結果畫面完全未走在地化機制（v1.1 port 就存在的舊
  bug，非本次回歸）**：`"File X of Y"`／`"N dive(s) imported"`／`"N skipped
  (duplicates)"` 原本是純字串插值，永遠顯示英文；旁邊早已有 18 語言完整翻譯的
  key 閒置沒被呼叫。已重新接回既有 key，不需要新翻譯。
- **Trimix 潛水編輯後靜默資料損毀（🚨 confirmed real bug）**：`DiveLogEditSheet`
  的 Gas picker 不支援編輯 trimix，但 `save()` 原本無條件用 picker 顯示值（固定
  降級成 Air）覆寫 `dive.gasMixJSON`——只要對任何 trimix 潛水按 Edit 再 Save
  （哪怕只改備註），氣體資料就不可逆遺失成 Air。已修：記住原始 trimix JSON，
  save() 時維持不動；Gas picker 對 trimix 潛水加 `.disabled()` + 說明文字避免
  誤導。
- **配重／氣瓶壓力英制單位換算補完**：`UnitSystem` 新增 `convertWeight`/
  `convertPressure`（kg↔lbs、bar↔psi），修復 `DiveLogEditSheet`（v1.2 #4 的
  漏網之魚）與**獨立寫死的 `DiveLogDetailView`**（唯讀詳情頁自己另外硬編碼
  `"%.1f kg"`/`"%.0f bar"`，跟編輯表單的問題各自獨立、互不相關）；`DiveLogListView`
  的「Deepest」統計卡片同樣硬編碼 `%.1fm` 一併修掉。
- **新增潛水表單移除不合理的假預設值**：氣瓶起始/結束壓力原本預設 200/50 bar，
  換算成英制出現「2,901 psi」「725 psi」這種假精確度零頭數字；配重原本預設 0
  （無法區分「沒填」跟「真的配重 0」）。比照既有 `airTemperature`/`visibility`
  的「nil = 未記錄」寫法統一處理。`maxDepth` 因是必填欄位改用 0 當「不可能值」
  哨兵（借用既有 `isSaveEnabled` 驗證關卡）；`waterTemperature` 因沒有安全的
  「不可能值」可借用，維持原預設（PM 確認）。
- **剖面圖互動列多語系版面問題**：分兩輪處理，第一輪只查到部分語言的「英文
  詞＋當地語」複合字串過長（de/nl 的 Ceiling、ms/id/el 的 No Deco）；真機截圖
  回報後改成不設長度門檻、逐一核對全部 5 個欄位 × 18 語言，額外抓到法文（28
  字）／越南文／泰文／克羅埃西亞文的同類問題，以及德文 Temp「Wassertemp.」
  單獨超長。修法：`calloutCell` label 加 `.minimumScaleFactor` 當版面保底（過長
  文字縮小字級而非省略號截斷成看不懂的內容）；能在同檔案內找到既有先例的（如
  西班牙文 Ceiling 比照葡萄牙文「Teto」、法文 No Deco 比照西/葡/義的
  「[without]+deco」模式）直接移除冗餘用詞，不硬猜的留給母語審核（僅剩希臘文/
  克羅埃西亞文 No Deco）。
- **死碼清理**：`JD2Core/Utilities/Extensions.swift` 整個檔案（21 個符號，逐一
  驗證含測試目標皆 0 呼叫端後確認是 v1.0 舊架構遺留）連同 `DiveLog.averageAscentRate`
  一併移除，不留 `// removed` 註解。
- **`DiveReplayEngine.tissueLoadPercent` 效能修正**：原本每次呼叫都重建一個
  `Buhlmann` 實例，只為了讀兩個跟 environment 無關的常數欄位（`gfHigh`／
  `compartments[].aN2/bN2`）；互動拖曳剖面時每個拖曳幀都觸發，等於每幀都重新
  配置一次 16 隔室陣列。改為快取，只有 environment 真的變了才重建。
- **兩輪第三方 AI 稽核報告逐項查核**（非官方稽核，PM 提供給 Claude 交叉驗證）：
  第一輪（`code_audit_report-0726.md`）主要問題屬實，如上已修復；第二輪
  （`audit_report-0726-R2.md` 及其修訂版 `-rev3.md`）發現多項報告本身的幻覺
  內容（例如宣稱只支援「6 種語言」，實際 18 種；多個「未本地化」的具體指控
  查證後其實是透過 SwiftUI 自動 `Text(LocalizedStringKey)` 正確運作，報告作者
  不理解這個機制；部分程式碼片段直接編造、檔案裡查無此行），逐項記錄查證結果
  於 `V1_2_BACKLOG.md`，不照單全收。
- **本地端 Debug/Release 效能落差釐清**：真機回報「開啟或互動經常卡住」，追查
  懷疑是 Debug build（未優化、除錯器連線）而非程式邏輯問題，指導 PM 用 Xcode
  Release Testing 匯出＋直接裝置安裝測試（非 TestFlight 上傳）排除變因。

### 2026-07-25 — v1.2 (Build 3)：單位系統全面套用、Game Mode 修復、真機廣告/IAP 驗證、匯入情境測試

- **公制／英制單位系統全面套用**（V1_2_BACKLOG.md #4 收尾）：先前只做了 Settings
  選項本身，這次展開到 `DiveRowView`／`DiveLogDetailView`／`DiveSiteSheetView`／
  `DiveAnalysisView` 的 `calloutRow`／`DiveSiteAnnotation`／`DiveMapRepresentable`
  （非 SwiftUI View context，改直讀 `UserDefaults`）／`DiveLogEditSheet`（新增
  4 個雙向 `Binding` computed property供輸入欄位換算）。
- **Dive Profile trimix 顯示修復**：原本 trimix 潛水（DiveKit 無氦氣組織負荷
  計算）會讓整個狀態列（連 Time/Depth/Temp 都有算的資料）被免責聲明取代；改為
  `calloutRow` 固定 5 欄排版，缺資料的 Ceiling/No Deco 才用「—」佔位，維持互動；
  組織艙圖用帶 `info.circle` 圖示的說明文字取代，明確標示是已知限制非程式錯誤。
  順便修好狀態列文字大小忽大忽小的問題（`minimumScaleFactor` 導致 5 欄各自獨立
  縮放不一致，改用固定不縮放字級＋關閉插入動畫）。
- **macOS/iOS Game Mode 誤觸發修復**：`Info.plist` 的 `LSApplicationCategoryType`
  從 `public.app-category.sports-games`（Apple 分類系統裡其實是「Games→Sports」
  子分類，非獨立的「Sports」）改為 `public.app-category.healthcare-fitness`；
  App Store Connect 的 Category 欄位同步更新。iOS + macOS 皆已用真機／直接雙擊
  安裝版驗證修復生效（排除是 Xcode `cmd+R` 偵錯階段特有現象後確認）。
- **AdMob 真機驗證 + DEBUG 測試 ID 改用官方常數**：真機驗證 4 個廣告版位正常
  顯示；`AdUnitID` 的 DEBUG 分支改用 Google 官方測試 Ad Unit ID（不綁裝置），
  取代原本註冊 `testDeviceIdentifiers` 的做法（裝置 `identifierForVendor` 在整個
  刪除重裝 App 後會重新產生，測 Restore Purchase 這類情境時裝置 ID 一直變）。
- **IAP／Restore Purchase 真機 Sandbox 驗證**：正向購買、正向 Restore、反向
  Restore（Clear Purchase History 後應正確顯示無法還原）、重複購買後再 Restore
  皆 PASS。移除 Settings 的「Simulate Premium」除錯開關（其 getter 直接綁真實
  StoreKit 授權狀態，一旦帳號完成過真實購買，`refreshPurchaseStatus()` 每次啟動
  都會覆蓋回 true，開關永遠關不掉）。
- **匯入情境測試（V1_2_BACKLOG.md #5）**：`_JD2-family/00_Import_test_scenes/`
  建 5 個情境資料夾，涵蓋黃金路徑、單檔多潛水、8 格式批次混合、去重/錯誤處理、
  trimix／ZIP 包裝／跨品牌相容性等特殊情況，全數通過。過程發現 `DiveImportKit`
  的匯入失敗錯誤訊息全數寫死繁體中文（跨三個 App），依家族鐵律回報而非自行
  修改，記錄於 `_JD2-family/reports/R-2026-07-25-DiveImportKit錯誤訊息未本地化.md`；
  家族總管已處理第一階段（6 個錯誤樣板改英文，DiveImportKit v0.4.0→v0.4.1）。
  同時補上 `F-07-IMPORT_FORMAT_COVERAGE.md` 的 Garmin Connect JSON（首次有資料
  驗證過）、DAN DL7／Divesoft DLF v2／Garmin FIT 跨廠牌拒收的 E2E 驗證紀錄。
- **App Store Connect 送審動作完成**：Age Rating 問卷（Advertising=Yes，其餘
  如實回答 No）、App Privacy 問卷（Location/Device ID/Usage Data 的「used to
  track」皆改 No）、Category 改 Health & Fitness。AdMob 後台封鎖全部 13 個標準
  敏感類別廣告（因應 Google 8/10 賭博廣告政策放寬，主動避免未來廣告內容跟年齡
  分級不符的風險）。
- **Export/Import Backup 功能先隱藏**：v1.1 做的功能這輪還沒完整測試，
  `SettingsView.swift` 加 `showBackupSection = false` feature flag，UI 隱藏、
  程式碼保留，下一版驗證後開放。
- **版號**：`MARKETING_VERSION` 1.0 → 1.2，`CURRENT_PROJECT_VERSION` 2 → 3。
- **本機開發環境清理**：清除 29 筆 macOS LaunchServices 殭屍 App 註冊（模擬器/
  XCTestDevice 暫存路徑已刪除但快取殘留）＋約 2.7GB 舊 DerivedData／過期專案
  資料夾（`iosApp/JoyDive` 舊專案、JD2-ultra/JD2-immersion 的舊 DerivedData）。

### 2026-07-21 — 剖面圖警示標示與資訊列 + Import 語系修復（同日第二條）

- **剖面圖警示事件系統**（V1_2_BACKLOG.md #3 子項②③）：`DiveReplayEngine.replay()`
  新增上升速度追蹤，門檻與文案數值比照統一 DiveKit `AlgorithmConstants`
  （10 m/min、連續 5s→Ascent Rate Alert、連續 10s→Mandatory Safety Stop），
  新增 `ReplayWarning`／`ReplayWarningKind`，不綁在既有 `ReplayPoint` 上（獨立
  清單，避免兩種警示落在同一樣本區間互相覆蓋）。`DiveAnalysisView` 新增：
  ①曲線上的彩色圓點標記（chartOverlay 疊加，沿用時間軸偏移修復的
  `plotAreaFrame` 校正手法）②狀態資訊列下方第二列——選取點命中警示事件時顯示
  事件卡片（圖示＋標題＋描述＋右側深度/時間）。4 個新翻譯 key 補齊 18 語言。
- **Import tab 語系死角修復**：使用者發現日文語系下 Import tab 仍顯示英文。
  根因與 v1.1 #8（navigationTitle/tabItem 死角）同類型：`ImportWizardView.swift`
  用 `String(localized:)`（純 Foundation API，只認系統語言）而非
  `languageManager.localized(_:)`（吃 App 內語言切換器）——v1.1 #8 修復當時這批
  Import 格式清單程式碼還沒寫，沒被涵蓋到。全面替換，新增缺漏的
  "Import Completed with Issues" 翻譯 key。
- **macOS 地圖 recenter 按鈕缺失**：查證後確認非 bug，是 Settings 頁 GPS 定位
  開關未開（macOS/iOS 各自獨立安裝，UserDefaults 不共用），使用者確認後跳過。

### 2026-07-21 — 剖面圖時間軸偏移修復 + 公英制單位設定選項

- **剖面圖互動選取偏移 bug**：`DiveAnalysisView` 的 `chartOverlay` 把 Swift
  Charts 的 `proxy.position(forX:)`／`proxy.value(atX:)`（相對繪圖區域座標，
  不含左側 Y 軸刻度標籤寬度）直接當成 GeometryReader 的座標系使用，導致選取線
  與拖曳命中整體往左偏移一個刻度標籤寬度（使用者截圖佐證：選取線飄移到 0 分鐘
  外面）。改用 `geo[proxy.plotAreaFrame]` 校正 origin。JD2-Ultra companion 的
  同款程式碼有一樣的 bug，已記錄到 `SYNC_TO_JD2-ULTRA.md` #6。
- **公制／英制單位設定（Settings 選項，範圍限定）**：新增
  `JD2Core/Models/UnitSystem.swift`（metric/imperial 列舉＋深度/溫度轉換函式）
  ＋ Settings 頁單位系統切換，依指示不用文字、直接用符號表示（`m / °C` vs
  `ft / °F`），`@AppStorage` 持久化。⚠️ 本次只做設定頁選項本身，尚未展開到全
  App 各處顯示/輸入欄位套用，詳見 `V1_2_BACKLOG.md` #4。

### 2026-07-20 — iOS 送審駁回分析 + privacy.md 修正

iOS 1.0 (Build 2) 送審遭 Apple 駁回，兩項理由：

- **2.3.6（Age Rating 不準確）**：Age Rating 的「Advertising」欄未勾選 Yes，
  但 App 確實顯示 AdMob 廣告（駁回信附截圖佐證）。純 App Store Connect 設定
  問題，不需改程式碼，待使用者自行於 ASC 修正。
- **5.1.2(i)（隱私標籤與實際行為不符）**：ASC 的 App Privacy 標示 Coarse
  Location、Other Usage Data、Device ID 用於「追蹤」，但需先請求 App Tracking
  Transparency 授權才符合規範。逐項核對程式碼確認：全專案無 `AppTrackingTransparency`
  引用、Info.plist 無 `NSUserTrackingUsageDescription`、AdMob 用預設
  `Request()`（無 IDFA/個人化廣告設定）、`CoreLocation` 僅供地圖「回到我的
  位置」一次性定位、資料不外傳。確認 App **實際上沒有追蹤行為**，ASC 隱私標籤
  應是誤填（很可能是照抄 `logbook/privacy.md` 舊文案填的，該文案本身就寫了
  「IDFA 僅在授權後」「可透過 ATT 重設追蹤授權」等從未真正實作的敘述）。
  修正 `logbook/privacy.md` 三語版本（EN/繁中/日文），移除與實際行為不符的
  IDFA/ATT 敘述，改為明確聲明不使用 IDFA、不請求 ATT 授權、廣告非個人化投放。
  **待使用者執行**：ASC App Privacy 問卷重新填寫（Location/Device ID/Usage
  Data 取消「used to track」）＋ Review Notes 註明已修正。詳見 `V1_2_BACKLOG.md` #1。

### 2026-07-19 — 移除 Deepblu COSMIQ+ 匯入格式支援

Deepblu 公司已停業，官方 App 從未支援直接匯出 `.json`/`.csv`（2026-07-19 網路
查證確認），唯一取得結構化資料的路徑是社群第三方工具 `deepblu-tools`，但需要
使用者自己的 Deepblu 帳號——確認沒有帳號，此路徑不可行。加上現有樣本自建立
以來就是模擬資料，`DeepbluCOSMIQParser` 從未被真實資料驗證過，PM 決定直接
移除格式支援，不再長期掛著一個無法驗證、公司已消失的格式。

移除範圍：`DiveLogFormat.deepblu` case（含 `supportedExtensions`／`priority`）、
`DeepbluCOSMIQParser.swift`、`DeepbluCOSMIQParserTests.swift`、匯入畫面選單裡
的「Deepblu COSMIQ+」項目、`DiveLogDetailView` 的 `sourceFormat` 顯示標籤。
`ARCHITECTURE.md` 同步移除對應解析器列（該列原本宣稱「已對真實樣本驗證」，
本來就是錯的）。`JD2-LogbookTests` 全套件 205 通過／15 略過／0 失敗。詳見
`_JD2-family/decisions/2026-07-19_移除Deepblu支援.md`。

### 2026-07-19 — 補齊 Suunto DM5 最後一個遺失檔案 `Dive_2026-06-04-0819.xml`

F-07 待辦 6 原本列了 2 個確認遺失的 D4i 檔案（`0948`／`0819`），`0948` 已於同日
稍早補齊，`0819` 使用者補上傳後也已歸檔驗證（`SuuntoDM5XMLParserTests` 新增
1 個真實樣本斷言，全綠），待辦 6 全數銷項。另外，4 個 `.sde` 匯出重新下載後
依然是 0 bytes 空檔，非傳輸偶發問題，疑似 DM5 軟體端 `.sde` 匯出功能本身有
問題，使用者決定暫緩擱置，已記錄於 F-07 待辦表。

### 2026-07-19 — 使用者提供同批 4 次潛水的完整 Suunto 多格式匯出，修復 3 個真實 bug

使用者提供同一支錶（序號 99723006）4 次潛水的多格式匯出：4 個 SML、3 個新
DM5 XML（其中 `Dive_2026-06-03-0948.xml` 正是先前 F-07 確認遺失、待辦要 PM
重新匯出的那個檔案，本次補齊）、2 個真實 Suunto App JSON、2 個 Suunto FIT；
4 個 `.sde` 匯出皆為 0 bytes 空檔，未歸檔（待使用者確認匯出流程問題）。三方
（SML／DM5 XML／JSON）交叉核對同一批潛水的深度/時長/氣體數值一致。

**修復 1：`SuuntoJSONParser` 樣本剖面靜默遺失**——真機的 Suunto App JSON 匯出
樣本點只有絕對時間戳 `TimeISO8601`，從未出現解析器原本唯一支援的相對秒數
`Time` 欄位，導致 `profileSamples` 永遠是空陣列（dive 匯入成功但深度剖面圖是
空的，不報錯）。已修復：改用 `TimeISO8601 - Header.DateTime` 反推相對秒數，
`Time` 欄位保留作 fallback。**這也是本次順便補齊的最急迫格式缺口**——Suunto
JSON 先前連假資料都沒有，是全格式中驗證狀態最差者，`SuuntoJSONParserTests`
新增 3 個測試（2 真實樣本＋1 迴歸測試）全綠。

**修復 2：`GarminDescentParser` 誤接受非 Garmin 廠牌的 FIT 檔案**——用 2 個真實
Suunto FIT 匯出驗證時發現，`canHandle` 原本只驗證 FIT magic bytes（通用容器
格式），會誤判非 Garmin 廠牌的 `.fit` 為可解析；解析時因缺少 Garmin 專屬的
`dive_gas`（GMN 269）訊息，`gasMixJSON` 靜默退回預設值 `"air"`，但深度/時長
（來自通用的 `session` GMN 18）看起來完全正常、不會報錯——實測兩筆皆為
Nitrox 30%，被誤判成 Air，是最危險的一種靜默資料錯誤。已修復：新增
`file_id.manufacturer` 檢查，非 Garmin 廠牌在 `canHandle`／`validateContent`
階段明確拒絕，`parse` 拋出寫明實際廠牌的 `unsupportedFormat` 錯誤。
`GarminFITParserTests` 新增 2 個迴歸測試全綠。Suunto FIT 樣本已歸檔為負向
測試 fixture，不會被任何解析器誤用。

真實樣本已歸檔至 `_JD2-family/dive-log-samples/Suunto/`（原始檔，SML/DM5/JSON/
FIT 各自子目錄）與 `_JD2-family/00_Import_samples/`（Suunto_SML 更新、
Suunto_DM5 新增第 3 筆、**新增 `Suunto_JSON/` 首次涵蓋此格式**）。
`JD2-LogbookTests` 全套件 209 通過／15 略過／0 失敗。詳見
`_JD2-family/F-07-IMPORT_FORMAT_COVERAGE.md` Suunto 各行。

### 2026-07-19 — 修復 Suunto SML 解析器真實 bug（使用者提供真實裝置匯出後發現）

使用者提供 2 個真實 Moveslink 裝置匯出（序號 99723006，2021-09-01／2021-09-04，
共 141／156 筆採樣），取代先前 F-07 稽核確認的模擬樣本。實測發現
`SuuntoSMLParser.parseISO8601` 對真機常見的無時區 `DateTime`（如
`2021-09-01T15:14:26`，不含 `Z`／offset）一律回傳 `nil`，導致整筆解析失敗——
舊的模擬樣本因誤植了 `Z` 後綴而長期未曝光此問題。已修復（加無時區格式
fallback，與 `ShearwaterXMLParser`／`UDDFParser` 既有慣例一致）；另外發現真機
Header 其實有 `<Depth><Max>` 欄位（舊文件誤記「Header 沒有 MaxDepth」），已更正
檔頭註解，解析行為本身不變（仍從樣本點推算 maxDepth，較穩健）。
`SuuntoSMLParserTests` 新增 3 個測試（2 個真實樣本斷言＋1 個無時區迴歸測試）
全綠。真實樣本已歸檔至 `_JD2-family/dive-log-samples/Suunto/SML/`（原始檔）與
`_JD2-family/00_Import_samples/Suunto_SML/`（改日期版，取代原模擬樣本）。詳見
`_JD2-family/F-07-IMPORT_FORMAT_COVERAGE.md` Suunto 表格。

### 2026-07-19 — 修復 DAN DL7 解析器兩個真實 bug

家族樣本庫 `DL7.zxu` 從截斷版（誤植，只有 1 筆採樣點）補回 Subsurface 官方完整
內容（3 組潛水記錄＋1 個真實 `ZDP{...}` 剖面區塊）後，發現解析器完全無法正確
處理：① `ZDH`/`ZDT` 配對用錯欄位（`fields[1]` 應為 `fields[2]`），導致唯一帶
剖面資料的那筆潛水配對失敗被靜默丟棄；② `ZDP{...ZDP}` 多行區塊語法完全不被
支援，只認合成測試用的單行格式。依 PyDL7 開源實作核實欄位語意後修正兩者，
新增區塊語法解析（與既有單行語法並存）。修復後正確解析出 3 筆潛水，`ZDP`
剖面路徑首次被真實資料驗證通過。iOS+macOS build 成功、`DANDL7ParserTests`
全綠、全套件無回歸。詳見 `_JD2-family/F-07-IMPORT_FORMAT_COVERAGE.md` 第七節。

### 2026-07-19 — 匯入批次結果 UI：不再靜默丟棄失敗清單

實測 `00_Import_samples`（20 個真實樣本）批次匯入時發現 UI 只顯示
「Import Successful」，完全不顯示哪些檔案失敗。追查根因：
`ImportWizardView.runBatchImport` 逐檔錯誤只記 `firstError`（第 2 個以後的失敗
直接丟棄），只要批次裡有一筆成功就跳到 `.success`；`skipped` 也永遠寫死 0，
即使 `ImportCoordinator` 內部確實算出 dedup 略過筆數，只印到 console 沒回傳。

- `ImportCoordinator.importFile` 回傳型別改 `ImportFileResult`（`dives` +
  `skippedDuplicates`），把原本只印 console 的 dedup 筆數一併回傳。
- `ImportWizardView`：新增 `ImportFailure`（檔名+原因）；`ImportStep.success`
  加 `failures` 參數；`runBatchImport` 改單一 catch block 蒐集**全部**失敗
  （含原本被特殊跳過的 `emptyFile`），不再只留第一個；成功畫面依
  `failures`/`count` 三態呈現（全成功綠勾勾／部分完成橘色警示+失敗清單／
  全失敗紅色 X+失敗清單），不再有任何一筆錯誤資訊被靜默丟棄。
- 驗證：iOS+macOS build 成功、測試套件全綠、`00_Import_samples` 全部 20 個
  真實檔案批次匯入 **100% 成功**（0 失敗——搭配同日 DiveImportKit v0.2.1 的
  Seabear／SubsurfaceCSV 格式覆蓋補強後，先前的 4 個失敗樣本已全部修正）。

分支 `feature/import-failure-visibility`（總指揮驗收後 merge）。

### 2026-07-19 — F6 階段一：改用家族共用匯入解析器套件 DiveImportKit

家族 F6（Importers 合流）第一步：Logbook 端採用新建的 `../DiveImportKit`
（獨立 git repo，v0.1.0，130 tests 全綠），5 個已抽取的格式解析器
（UDDF／Subsurface XML／Subsurface CSV／Shearwater／Seabear CSV）改為
Kit 引用＋App 端薄包裝，App 內對應實作刪除。分支
`feature/F6-shared-import-kit`，三個 commit（總指揮驗收後 merge）：

1. **`project.pbxproj` 新增 `../DiveImportKit` local package**（主 target +
   Tests target，比照 F5 DiveKit 手法；plutil -lint ＋ resolvePackageDependencies
   兩道驗證通過）。
2. **新增 `JD2Core/Importers/DiveImportKitAdapter.swift`**——全 App 唯一
   `import DiveImportKit` 的檔案（Kit 與本地型別同名，只在 adapter 內以
   `DiveImportKit.` 前綴限定，避免全面歧義）：
   - `ParsedDiveLog → DiveLog` 逐欄位對映；`profileSamples` 陣列編回
     `profileSamplesJSON`（短鍵 t/d/w）、`importExtras` 陣列走既有
     `buildImportExtrasJSON` 編回 `importExtrasJSON`，SwiftData schema 零變動。
   - **Kit 錯誤 → 本地 `DiveLogImportError` 逐 case 轉換**（ImportWizardView
     以本地 case 逐一 catch，不轉換 UI 錯誤提示會劣化）。
   - 5 個薄包裝 struct 沿用原名（`UDDFParser` 等），`DiveLogImporterFactory`
     清單與 priority 順序、既有測試（F5 E2E 等）零改動。
   - `MinimalZipReader` 本地薄轉發 enum（`SuuntoSDEParser` 仍在用；因專案啟用
     `MemberImportVisibility`，typealias 再匯出行不通，Ultra 端採用時同樣要注意）。
   刪除已搬遷實作：monolith 內 4 個解析器＋私有 delegate/資料結構
   （`DiveLogImporter.swift` 2483→911 行）、`ShearwaterXMLParser.swift`、
   `MinimalZipReader.swift` 整檔。保留：protocol／`DiveLogFormat`／
   `DiveLogImportError`／Factory／Peregrine·Oceanic 本地 stub／其餘 Logbook
   專屬解析器／`ImportCoordinator`（去重/並發邏輯不動，SYNC #2/#3 另案）。
3. **測試調整**：刪除 5 個已搬遷解析器的測試檔（邏輯已在 Kit 測過），新增
   `DiveImportKitAdapterTests`（test42.uddf 走 factory→包裝→DiveLog 全流程，
   關鍵欄位斷言與搬遷前期望值一致）。

驗證：iOS＋macOS build 成功；iOS 模擬器與 macOS 本機均實際啟動；測試套件
（排除既有已知崩潰的 `ImportCoordinatorTests`）0 failures（SuuntoJSON 樣本
缺檔 skip 為既有現象）。UI 完全未動，匯入流程仍走原 factory 入口。

### 2026-07-18 — F5：改用家族統一 DiveKit（取代 JD2Core 演算法 fork）

三個 JD2 家族 App 中 ultra／immersion 已於 F3a/F3b 改用統一 `DiveKit`（SPM 引用），
本次 Logbook 跟進，家族「共用演算法只有一份」目標達成。分支
`feature/F5-divekit-migration`，三個 commit：

1. **`project.pbxproj` 新增 `../DiveKit` local package**（主 target + Tests target）。
2. **刪除 JD2Core 12 個死碼/重複檔**（Algorithm 7 檔＋Constants 1 檔＋State 3 檔＋
   Models 4 檔），改吃 DiveKit 對應型別；`DiveReplayEngine.swift`（Logbook 專屬回放
   引擎，語意不同不遷移）與 21 個消費檔補 `import DiveKit`。刪除
   `DiveEngineTests.swift`（測試已刪除的死碼，其回歸場景已在 DiveKit 自己的測試
   套件覆蓋）。**根因排查**：`DiveReplayEngineTests` 先前的 malloc 崩潰證實是被
   `DiveEngineTests` 汙染共享測試行程，刪除後單獨執行 4/4 全過、無崩潰。
3. **發現並繞過 DiveKit 已知缺口**：`Buhlmann` 只追蹤氮氣（`Compartment` 無 `pHe`
   欄位），trimix 的 `ndlSeconds()` 會 `assertionFailure`（v2.0 項目，尚未實作）；
   用真實 trimix 樣本（`00_Import_samples/`）走完整匯入→剖面分析流程時首次踩到。
   PM 決策：F5 繞過（不動 DiveKit 演算法本體），`DiveReplayEngine.replay()` 偵測
   trimix 即跳過生理計算、只給深度/時間/溫度剖面（`decoDataUnavailable`），
   `DiveAnalysisView` 對應隱藏 Ceiling/NDL/組織艙 UI。真正的 trimix 氦氣支援
   另排（家族層追蹤）。

新增 `F5DiveKitMigrationE2ETests.swift`：真實 trimix 樣本驗證短路路徑正確、合成
空氣潛水驗證完整 DiveKit 重放路徑正常。驗證：iOS+macOS build 成功；測試套件
（排除既有已知崩潰的 `ImportCoordinatorTests`，與本次無關）0 failures。

### 2026-07-17 — 外部稽核報告修復（4 項風險）+ 建立 Ultra 同步追蹤文件

外部稽核報告 `docs/reports/R-2026-07-17-audit_report.md`（原 `audit_report-0717.md`，2026-07-18 歸檔更名）針對核心演算法與匯入流程提出 4 項風險，
逐項核對程式碼後確認全數屬實（非誤報），並全數修復：

1. **`Buhlmann` chunking 迴圈 pRate 歸零 bug**（[DiveEngine.swift](JD2-Logbook/JD2Core/Algorithm/DiveEngine.swift)）
   ：時間補償的 chunk 迴圈原本每一步都傳最終深度給 `buhlmann.update()`，導致
   `Buhlmann` 內部 `prevDepth` 在第一個 chunk 後就等於最終深度，depthDelta 恆為
   0、壓力變化率被誤判為 0，等同把補算期間全當恆深處理。改為依已耗用時間比例
   在「tick 開始前深度」→「本次 tick 深度」間線性插值，與同一份程式碼庫內
   `DiveReplayEngine.swift`（本 session 較早修復）已驗證過的手法一致。
2. **匯入批次去重漏洞**（[ImportCoordinator.swift](JD2-Logbook/JD2Core/Importers/ImportCoordinator.swift)）
   ：`deduplicateDives` 原本只比對資料庫既有記錄的靜態快照，同一批次（甚至單一
   檔案）內部彼此重複的日誌會互相漏檢、全數寫入。改為逐筆比對＋動態把已確認
   非重複的日誌併入比對陣列，抽成可獨立單元測試的 `Self.dedupe(_:against:)`，
   與 `DiveLogDatabase.importFromJSON` 既有正確做法一致。
3. **匯入解析阻塞主執行緒**：`ImportCoordinator` 為 `@MainActor`，`importer.parse()`
   為同步 CPU 密集操作，大檔案/批次匯入會讓 UI 卡住甚至觸發 Watchdog 強制關閉。
   改用 `Task.detached` 包住選格式＋解析。⚠️ 已知限制：專案預設
   `-default-isolation=MainActor`、`DiveLogImporter`/`DiveLog` 皆非 `nonisolated`/
   `Sendable`，此修復在目前編譯設定下僅為 warning（非 error），警告訊息明確標註
   「this is an error in the Swift 6 language mode」；徹底解法需將協定三方法與
   全部 20 個解析器實作標記 `nonisolated`＋處理 `DiveLog` 跨 actor 傳遞，規模較大，
   本次未一併處理，已記錄於 `SYNC_TO_JD2-ULTRA.md`。
4. **OTU 跨日未主動重置**（[DiveEngine.swift](JD2-Logbook/JD2Core/Algorithm/DiveEngine.swift)）
   ：OTU 單日重置原本只在 `beginDive()` 觸發時檢查，若潛水員完成潛水後在水面
   停留超過 24 小時卻未再下潛，UI/Widget 顯示的 OTU 會卡在舊值。抽成共用的
   `resetStaleOTUIfNeeded(now:)`，同時掛在 `beginDive()`、水面 `tick()`、
   `restore()`（App 重啟還原）三處呼叫。

**測試**：新增 `DiveEngineTests.swift`（4 項，涵蓋風險 #1 的 chunking 插值正確性
與風險 #4 的三種歸零情境）＋ `ImportCoordinatorTests.swift` 新增 4 項純邏輯去重
測試（不碰資料庫）。全數通過，iOS/macOS 雙平台建置成功。

**Ultra companion 風險評估**：逐一核對 [JD2-ultra](../JD2-ultra) 對應檔案
（`DiveKit/Sources/DiveKit/Algorithm/DiveEngine.swift`、
`JD2UltraPhone/Import/ImportCoordinator.swift`），確認 4 項風險**全數同樣存在、
尚未修復**（DiveKit 演算法程式碼為早期整包 port 自 Ultra，ImportCoordinator 架構
高度相似）。本次僅評估、未修改 Ultra 程式碼（不同專案，需另行決定是否同步）。
新增 `SYNC_TO_JD2-ULTRA.md` 作為長期追蹤文件，記錄「JD2-Logbook 發現且可能同樣
影響 Ultra」的問題，供 Ultra 端未來參考同步。

### 2026-07-17 — Import 格式清單重新規劃 + 剖面資訊列比照 Ultra companion

**Import tab「Supported Formats」**：格式數擴充到 16 種後，原本無分類的 2 欄
卡片格線難以掃視，改為依品牌/來源分 4 組（Universal / Suunto / Garmin /
Other Brands）＋單欄列表列。列的視覺語彙 port 自 JD2-Ultra companion
`DiveComponents.swift` 的 `SectionHeader`／`ValueRow` 慣例（圖示＋標題置左、
次要資訊置右，grouped 卡片背景＋列間 Divider），對齊 iOS 原生
`List(.insetGrouped)` 視覺語言，而非沿用舊版無來源依據的卡片格線設計。

**Dive Profile 互動剖面圖／組織艙負荷資訊列**：原本的圖示膠囊列（icon+text
pill）改為與 JD2-Ultra companion `DiveAnalysisView.calloutRow` 完全一致的
五欄等寬排版（Time / Depth / Temp / Ceiling / No Deco，label 在上、數值在
下）；新增「安全語意數值才用填色膠囊強調」規則——一般狀態為純深色文字，
只有真的減壓中（紅底白字）或免減壓時間逼近 10 分鐘（黃底黑字）時膠囊才
亮起，其餘與 Ultra 邏輯（`PlanModel.ndlText`：99+ / 分鐘）一致。

新增 4 個 xcstrings 翻譯 key（"Temp"／"No Deco"／"Universal"／"Other Brands"），
18 種語言全數補齊，優先沿用 Ultra 既有翻譯值。

### 2026-07-17 — 匯入格式全面擴充（10 個新解析器，8 個確認無法安全實作）

PM 指示全面查證 `/file_format_research` 盤點的 18 種潛水電腦/軟體格式，不接受
「叫使用者自己轉檔」的退讓方案。逐一重新驗證研究文件的假設（多處與真實樣本
不符，例如 Suunto SDE 內部其實是舊版 DM3 格式而非 DM5、DAN DL7 的 ZDT 記錄
語意與初版猜測相反），並在可能時搜尋開源參考實作交叉驗證byte-level正確性。

**新增 10 個格式解析器**：
- `SuuntoDM5XMLParser`：Suunto DM4/DM5 WCF XML（D4i 等錶款直傳），真實樣本逐欄位驗證
- `SHEARWATERParser`：從空 stub 改為真實實作，同時修正原本用預設 canHandle 誤攔截所有 `.xml`（含 D4i 檔）的根因 bug
- `SuuntoSMLParser`：Moveslink XML，含 Kelvin 水溫轉換
- `DANDL7Parser`：業界標準交換格式，欄位對照依開源 PyDL7 校正（研究文件誤判 ZDT 為逐樣本剖面，實為 dive trailer）
- `DivesoftDLFParser`：二進位格式，欄位偏移依開源 divesoft-parser 逐位元核對，並用真實樣本 3 個獨立欄位（start_time/max_depth/min_temperature）精確驗證吻合；v2 header（"DiVE" magic）明確拒絕而非臆測
- `SuuntoSDEParser`：ZIP 包裝的舊版 DM3 XML（非原研究猜測的 DM5 格式），歐式逗號小數處理
- `ReefnetSensusParser`：CSV，壓力→深度公式依 ReefNet 官方換算說明驗證；水溫欄位因無法可靠確認編碼，刻意不猜測轉換
- `DivingLogSQLiteParser`：原生 SQLite3（無需第三方套件），RTF 備註欄位手寫剝除器（避免引入 UIKit 依賴破壞 JD2Core 跨平台界線）
- `GarminConnectJSONParser`、`DeepbluCOSMIQParser`：格式假設（無公開 API 文件），待真實樣本驗證

**新增 `MinimalZipReader.swift`**：純 Swift 跨平台 ZIP 讀取器（PKWARE 公開規格，
支援 stored/deflate），取代原本只在 macOS 用 `/usr/bin/unzip` 的做法，順便修正
UDDF 的 ZIP 包裝格式在 iOS 原本完全無法匯入的既有缺口。

**確認 8 個格式目前無法安全實作**（Scubapro LogTRAK、Mares Dive Organizer、
Heinrichs Weikamp OSTC、Cressi PC Interface、Ratio iDive、Cochran CAN、
Aqualung i-Trak、APD LogViewer）：逐一檢查後證實為 Microsoft Access/SQL Server
Compact 等專有二進位資料庫無公開規格、或研究樣本僅為文字佔位符（無真實資料
可驗證），非偷懶跳過。具體理由見 `file_format_research/format_inventory.md`。

### 2026-07-17 — v1.1 backlog 完工（6/7 項，widget 決定不做）

**功能**：
- #6/#7 `importExtrasJSON` 欄位：buddy / 裝置序號 / 韌體不再塞進 notes 文字，改結構化存儲；Detail 頁新增可折疊「原始資料」區塊
- #8 `avgDepth` 欄位：來源值優先，無則以剖面樣本梯形近似重建
- #14 Export/Import 備份：`DiveLogDatabase.exportAsJSON/importFromJSON` 從拋錯 stub 改為真正可用，Settings 頁新增入口
- #4/#5 移植 Ultra `DiveKit`：取代本地死碼 `Buhlmann.swift`/`DiveEngine.swift`/`AlgorithmConstants.swift`（9 項已知安全問題）；新增互動剖面圖（拖曳查看深度/水溫/ceiling/NDL，放開後保留選取）＋組織艙飽和度長條圖（預設收合，互動後才顯示）
- #12 Garmin Connect JSON 解析器（FIT 的替代匯入路線）
- #13 解析器測試覆蓋率：`DiveLogImporter.swift` 82.2% → 89.1%
- #9/#10 iOS 18 Widget：PM 確認不需要，終止規劃

**技術債（順手修復，與今日改動無關的舊問題）**：
- `project.pbxproj` 測試 target `TEST_HOST` 殘留改名前的 `JD2-Logbook.app`（應為 `JoyDive².app`），導致 `xcodebuild test` 完全無法建置
- 9 個測試檔案的 `@testable import JD2_Logbook` 未隨模組改名同步（實際模組為 `JoyDive_`）

**架構重點**：互動剖面圖與組織艙圖的選取狀態統一由 `DiveAnalysisView` 管理（非各自為政），重放引擎改為直接驅動 `Buhlmann` + 樣本間 ≤10s 線性內插（比對 JD2-Ultra companion `DiveReplay.swift` 對齊，取代原本用 `DiveEngine.tick()` 逐樣本呼叫、樣本間隔大時深度會瞬間跳變的失真做法）。

**待決策**（下次上架前）：macOS `Info.plist` 的 `LSApplicationCategoryType = public.app-category.sports-games` 會觸發系統誤判為遊戲、自動開啟 macOS 遊戲模式（`gamepolicyd` 只檢查分類值是否以 `games` 結尾）；需決定改為 `public.app-category.sports` 或 `public.app-category.healthcare-fitness`，同時要對齊 App Store Connect 的上架分類。

### 2026-06-03 — AdMob 正式接入（commit 656a246）
- 接入 GoogleMobileAds SDK v11
- 更新 4 個正式 Ad Unit ID
- 修正 SDK v11 API 改名（BannerView / AdSizeBanner / Request）
- 修正 PremiumAwareAdBanner 高度約束問題

### 2026-06-02 — 死碼清理 + 部署目標統一（commit deda6ca / 56dc1a3）
- 刪除 ContentView、placeholder views 等死碼
- SwiftData schema 移除 `buddy` 欄位
- 修正 macOS DiveLogEditSheet O₂ 重複顯示 bug
- 統一部署目標 iOS 17.0 / macOS 14.0
- 新增 .gitignore

### 2026-05-xx — i18n 實裝（commit 84b7b47 / 682087c）
- 匯入 V7.2 多語系校訂版
- 中文用詞統一（繁中 / 簡中 區分）
- 修正 navigationTitle("") 空字串 key 問題

### 2026-05-17 — 專案初始化
- Xcode 專案建立，SwiftData 初始化
- JD2Core 模組架構確立
