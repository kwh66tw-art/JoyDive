# 下一版送審檢查（2026-10-03 建立；**2026-10-06 送審收尾複核**，依 `app-store-submission-guide` §0 清單）

## 2026-10-10 送審前再複核（10/07 之後：送審前 7 項＋PM 追加；以指令查證）

| 項目 | 結果 | 驗證 |
|---|---|---|
| Release 建置 | ✅ rc=0、0 error、BUILD SUCCEEDED | `xcodebuild -configuration Release -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO`（獨立 DerivedData） |
| 版號 | ✅ 1.3（4） | 產物 `defaults read`：`CFBundleShortVersionString`=1.3、`CFBundleVersion`=4 |
| 加密宣告 | ✅ NO | 產物 `ITSAppUsesNonExemptEncryption`=0 |
| 廣告 ID | ✅ 正式 4 個、測試 0 個 | Release 執行檔 `strings`（`GADApplicationIdentifier` 為正式值） |
| Privacy Manifest | ✅ 3 份（App＋AdMob＋UMP） | `find *.xcprivacy` |
| ATS | ✅ 不變（`…ForMedia`、`…InWebContent`；無 `NSAllowsArbitraryLoads`） | 產物 `plutil -p Info.plist` |
| 網路／隱私問卷 | ✅ 不變（`URLSession` 0 次） | `grep` |
| Support／Privacy URL | ✅ HTTP 200 | `curl -L https://kwh66tw-art.github.io/JoyDive/logbook/privacy` |
| 共用層 | ✅ DiveKit **v9.3.0**／DiveImportKit **v0.7.8**（HEAD＝tag） | `git describe` |
| 測試 | ✅ App-lb **171／0／1**；DiveKit 572／0／0；DiveImportKit 406／0／0；App-u phone 45、watch 175、App-i 63（皆 0 失敗） | `run_tests.sh` |
| 新增使用者可見字串 | ✅ 2 條、18 語齊（多氣體／循環呼吸器鎖住說明；「設為水肺才能選氣體」）；另 1 鍵改格式 `Nitrox O2: %@ percent`（18 語 %d→%@） | Release 產物 de／ja／hr／zh-Hant `Localizable.strings` 皆含新鍵；全目錄格式符號與鍵 0 不符 |
| 10/07 之後新增行為 | 編輯頁氣體保留原值／百分比不取整、未知氣體模式空白與多氣體鎖住、新增潛水不選模式、自由潛水／浮潛不顯示氣體、潛水時間不截整分、App 內語言殘留修正（約 110 處）、短潛水秒軸、ATMOS FIT 匯入 | 決策 §十九、§二十二、§二十三 |
| 模擬器目視 | ✅ 克羅埃西亞文（系統繁中）：列表、新增、編輯、詳細、匯入、選單、剖面讀數無中文殘留；編輯頁各情境；ATMOS FIT 匯入。Ceiling 膠囊、Mac ⓘ：PM 確認；UDDF 逐點水溫：PM 確認（ATMOS） | iPhone Air 模擬器 |
| What's New | ✅ 三語加 ATMOS FIT 一句（PM 10/10） | `APPSTORE_COPY.md` |
| App 類別（PM 10/10 追加） | ✅ `public.app-category.sports`；**ASC 主類別要 PM 手動改 Sports** | Release 產物 macOS／iOS `plutil -extract LSApplicationCategoryType` 皆為 `public.app-category.sports` |
| 英文關鍵字（PM 10/10 追加） | ✅ 只放各國潛水日誌用詞，100 字元／114 bytes；✅ ASC 以字元計（10/10 實測，剩餘 0） | `APPSTORE_COPY.md` Keywords |
| 說明文（PM 10/10 追加） | ✅ 手動記錄句去掉 GPS 座標、氣體混合→氣體；品牌加 ATMOS（三語） | `APPSTORE_COPY.md` |
| ASC 上傳、問卷、送審 | PM | — |

## 2026-10-07 送審前再複核（10/06 之後又改了匯入與顯示；以指令查證）

| 項目 | 結果 | 驗證 |
|---|---|---|
| Release 建置 | ✅ rc=0、0 error | `xcodebuild -configuration Release generic/platform=iOS CODE_SIGNING_ALLOWED=NO` |
| 版號 | ✅ 1.3（4） | 產物 `defaults read` |
| 加密宣告 | ✅ NO | 同上 |
| 測試廣告 ID | ✅ 0 個 | Release 執行檔 `strings` |
| Privacy Manifest | ✅ 3 份（App＋AdMob＋UMP） | `find *.xcprivacy` |
| 共用層 | ✅ DiveKit v9.2.0／**DiveImportKit v0.7.6**（10/06 起 v0.7.3～v0.7.6：匯入稽核、逐點水溫、Subsurface XML 多氣瓶） | `git describe` |
| 測試 | ✅ **165／0／1** | `run_tests.sh logbook` |
| 新增使用者可見字串 | ✅ 無（「未知氣體」沿用既有 18 語字串） | 本輪程式改動未新增 `localized` 鍵 |
| 10/06 之後新增行為 | SDE 0 °C 遷移、逐點水溫、Subsurface XML 舊資料不可信、改氣體＝確認、不可信顯示「未知氣體」、原始匯入資料隱藏內部標記 | 決策 §十三～§十八 |
| 模擬器匯入目視 | ✅ 4 格式（§十七）；「未知氣體」列表／詳細頁截圖 | iPhone Air 模擬器 |
| ASC 上傳、問卷、送審 | PM | — |

## 2026-10-06 收尾複核（以指令查證；舊內容保留於下方）

產物：Release `generic/platform=iOS`（`CODE_SIGNING_ALLOWED=NO`，BUILD SUCCEEDED）＋ Debug 模擬器。

| 項目 | 結果 | 驗證 |
|---|---|---|
| 版號 | ✅ 1.3（4） | Release 產物 `defaults read`：`CFBundleShortVersionString`=1.3、`CFBundleVersion`=4 |
| 加密宣告 | ✅ `ITSAppUsesNonExemptEncryption`=NO | 同上（值 0） |
| Privacy Manifest | ✅ 產物內含 App 自己的 `PrivacyInfo.xcprivacy`（＋AdMob／UMP 各一） | `find *.xcprivacy` |
| 理由碼 `CA92.1` | ✅ **已對 Apple 官方原文核對**：「access user defaults to read and write information that is only accessible to the app itself」，不得讀其他 App／系統寫入的資訊 | Apple 文件 JSON（`nsprivacyaccessedapitypereasons`）。App 的 UserDefaults 只讀寫自己的鍵；`AppleLanguages` 只**寫入**本 App 網域（`AppLanguageManager.swift:59`）、未讀系統值 |
| 其他 Required Reason API | ✅ 無 | `grep` App＋兩 Kit：檔案時間戳／開機時間／磁碟空間／鍵盤 皆 0 次；無 App Group |
| ATS | ✅ AdMob 官方寫法 | 產物：`NSAllowsArbitraryLoadsForMedia`、`…InWebContent`；無 `NSAllowsArbitraryLoads` |
| 廣告 ID | ✅ Release 為正式 ID | Release 執行檔 `strings`：正式 ID 4 個、測試 ID 0 個 |
| 隱私問卷一致性 | ✅ 與 v1.2 過審狀態相同，無需改 ASC | 無網路請求程式碼（`URLSession` 0 次）；AdMob 仍為預設 `Request()`、未傳定位；無 ATT／IDFA |
| 定位權限說明 | ✅ 18 語 | Release 產物各 `.lproj/InfoPlist.strings` 含 `NSLocationWhenInUseUsageDescription`（抽查 de／el／ja／vi） |
| 翻譯 | ✅ 18 語補齊（原 #6） | `V1_3_WORK_PLAN.md` §九；`babd78b` |
| 共用層 | ✅ DiveKit v9.2.0（HEAD＝tag）；DiveImportKit v0.7.2（HEAD 多一個純 `CLAUDE.md` 文件提交，`Sources` 與 tag 無差異） | `git describe`／`git diff --stat v0.7.2..HEAD -- Sources` |
| 測試 | ✅ 155／0／1 | `run_tests.sh logbook`（10/06） |
| Support／Privacy URL | ✅ HTTP 200 | `curl -L` |
| 匯入流程手動走一次 | ✅ PM 10/05 模擬器 26 檔 | — |
| What's New | ✅ 三語定稿 | `APPSTORE_COPY.md` |
| ✅ **隱私權政策的「定位」段與實際用途不符**（10/06 PM 同意修正，三語改為「設定開啟後、僅用於地圖顯示目前位置」，更新日期 2026-10-06） | ✅ 已改並 push | 政策三語（`logbook/privacy.md:38／133／228`）寫「只在您選擇**記錄潛點 GPS 座標**時請求定位」；實際只用於**地圖「回到我的位置」**，且須在設定開啟（`UserLocationProvider.swift` 檔頭、`MapView.swift:40`）。v1.2 已是如此且過審，但 5.1.1(i) 要求政策說明用途。改 `privacy.md` 並 push 即更新公開網頁（對外動作） |
| ASC 上傳、問卷、送審 | PM | — |

---

## 2026-10-03 原始清單

> 狀態以指令查證：建置產物 `Debug-iphonesimulator/JoyDive².app`（`defaults read`、`find *.xcprivacy`），原始碼 `grep`。
> Kit 已凍結（DiveKit v9.2.0／DiveImportKit v0.7.1，2026-10-04 晚重新凍結）。

## 🔴 需要處理（送審前）

| # | 項目 | 現況（查證） | 建議 |
|---|---|---|---|
| 1 | ✅ **Privacy Manifest**（§4）——2026-10-03 已補 `JD2-Logbook/PrivacyInfo.xcprivacy` | App 本身**沒有** `PrivacyInfo.xcprivacy`；產物裡只有 AdMob 兩個 SDK 自帶的。App 用到 `UserDefaults.standard`（6 個檔；無 App Group 存取、無檔案時間戳／開機時間／磁碟空間 API；兩個 Kit 皆未用到） | 新增 App 的 `PrivacyInfo.xcprivacy`：`NSPrivacyAccessedAPICategoryUserDefaults`＋理由 `CA92.1`（只讀寫本 App 自己的資料）。**理由代碼送審前對官方頁面再核一次** |
| 2 | ✅ **加密宣告**（§5）——2026-10-03 已加 `ITSAppUsesNonExemptEncryption = NO` | `ITSAppUsesNonExemptEncryption` 不在 Info.plist、產物也沒有 ⇒ 每個新 build 會卡 TestFlight「Missing Compliance」 | 加 `ITSAppUsesNonExemptEncryption = NO`（只用系統 HTTPS）；法國上架另需宣告表（§5 特例），沿用 v1.2 做法 |
| 3 | ✅ **版號**——PM 定 1.3（4），已改 | 產物 `CFBundleShortVersionString` 1.2、`CFBundleVersion` 3 | 改 1.3（4）——**版本號由 PM 定**；改完用 `defaults read` 驗產物 |
| 4 | ✅ **關鍵字**（§1 2.3.7）——PM 2026-10-03：移除品牌、台灣／日本在地化、其餘用英文組；已寫入 `APPSTORE_COPY.md`（繁中／日文副標 PM 2026-10-03 定稿） | 現行含 Shearwater／Garmin／Suunto／Subsurface | 依 `docs/KEYWORDS_NEXT_DRAFT.md`（待 PM 審） |
| 5 | ✅ **What's New**（§1 2.3.12）——三語草稿已寫入 `APPSTORE_COPY.md`（準確度＋連續潛水並列、不寫因果） | — | 需寫明演算法係數改正：v1.2 標示 ZHL-16C 實為 ZHL-16B a 係數（`_JD2-family/decisions/2026-10-03_App-lb重放輸出差異回顧-v1.2對現行.md` §四草稿，待 PM） |
| 6 | ⏸ **免責句其餘 14 語**（PM：上架前一次做） | ⓘ 說明頁 Bühlmann 句只有英／en-GB／繁中／日 | 缺翻譯會退回英文原文；要不要補由 PM 定 |
| 7 | ✅ **複數字串**——查證已於 2026-09-02 R-050（`efe4e42`）修好，清單為過期紀錄；全目錄再掃一次，使用者可達畫面無殘留 | ⚠️ 隱藏中的備份功能有 `"Imported %d dives, skipped %d duplicates."`（en／de／hr 單複數錯）——**備份功能重新開放前要修** |

## 🟡 確認即可

- **ATS**：`NSAllowsArbitraryLoads`／`…ForMedia` 皆為 true。v1.2 已過審；若用不到可移除以降低審核問答——需確認 AdMob 是否仍需要。
- **隱私問卷**（§3.1）：AdMob（`GADApplicationIdentifier`）＋定位（`NSLocationWhenInUseUsageDescription`）——問卷與 manifest 要一致；v1.2 曾因 5.1.2(i) 被拒，修正紀錄見 `CHANGELOG.md` 2026-07-28。
- **Support URL**：`https://…/logbook/privacy`（真網頁，非 mailto）✅。
- **測試**：`run_tests logbook` **150/0/1** ✅（2026-10-04 夜，DiveKit v9.2.0；147＋新增 3 支資料庫開啟失敗測試）。
- **升級**：v1.2→v1.3 模擬器實測通過（見 `docs/V1_3_WORK_PLAN.md` §七）。
- ❌ **實機／模擬器走一次匯入流程**：2026-10-04 模擬器嘗試未成（檔案選擇器看不到測試檔）——**待 PM 手動驗一次**（匯入→關閉精靈）。

## 🟡 PM 判斷（2026-10-03 新增）

- **說明文與宣傳文字仍提到 Garmin、Suunto、Subsurface**（三語）。Apple 一般允許在說明文寫「相容於某格式」，
  但艦隊紅線是「對外文件不得提品牌」——這兩者怎麼取捨需 PM 決定（關鍵字已移除）。
  ✅ **PM 2026-10-03 裁示：說明文與宣傳文字保留**（格式相容性說明；關鍵字仍不放品牌）。
