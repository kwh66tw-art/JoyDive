# 下一版送審檢查（2026-10-03，依 `app-store-submission-guide` §0 清單）

> 狀態以指令查證：建置產物 `Debug-iphonesimulator/JoyDive².app`（`defaults read`、`find *.xcprivacy`），原始碼 `grep`。
> Kit 已凍結（DiveKit v8.9.1／DiveImportKit v0.7.1）。

## 🔴 需要處理（送審前）

| # | 項目 | 現況（查證） | 建議 |
|---|---|---|---|
| 1 | **Privacy Manifest**（§4） | App 本身**沒有** `PrivacyInfo.xcprivacy`；產物裡只有 AdMob 兩個 SDK 自帶的。App 用到 `UserDefaults.standard`（6 個檔；無 App Group 存取、無檔案時間戳／開機時間／磁碟空間 API；兩個 Kit 皆未用到） | 新增 App 的 `PrivacyInfo.xcprivacy`：`NSPrivacyAccessedAPICategoryUserDefaults`＋理由 `CA92.1`（只讀寫本 App 自己的資料）。**理由代碼送審前對官方頁面再核一次** |
| 2 | **加密宣告**（§5） | `ITSAppUsesNonExemptEncryption` 不在 Info.plist、產物也沒有 ⇒ 每個新 build 會卡 TestFlight「Missing Compliance」 | 加 `ITSAppUsesNonExemptEncryption = NO`（只用系統 HTTPS）；法國上架另需宣告表（§5 特例），沿用 v1.2 做法 |
| 3 | **版號** | 產物 `CFBundleShortVersionString` 1.2、`CFBundleVersion` 3 | 改 1.3（4）——**版本號由 PM 定**；改完用 `defaults read` 驗產物 |
| 4 | **關鍵字**（§1 2.3.7） | 現行含 Shearwater／Garmin／Suunto／Subsurface | 依 `docs/KEYWORDS_NEXT_DRAFT.md`（待 PM 審） |
| 5 | **What's New**（§1 2.3.12） | — | 需寫明演算法係數改正：v1.2 標示 ZHL-16C 實為 ZHL-16B a 係數（`_JD2-family/decisions/2026-10-03_App-lb重放輸出差異回顧-v1.2對現行.md` §四草稿，待 PM） |
| 6 | **免責句其餘 14 語** | ⓘ 說明頁 Bühlmann 句只有英／en-GB／繁中／日 | 缺翻譯會退回英文原文；要不要補由 PM 定 |
| 7 | **複數字串顯示 bug** | `V1_RELEASE_CHECKLIST.md`「下一版重點工作」：`"%lld dive%@ imported"` 在 18 語混入英文 s | 已有方案（F-09 §3），列為本版處理 |

## 🟡 確認即可

- **ATS**：`NSAllowsArbitraryLoads`／`…ForMedia` 皆為 true。v1.2 已過審；若用不到可移除以降低審核問答——需確認 AdMob 是否仍需要。
- **隱私問卷**（§3.1）：AdMob（`GADApplicationIdentifier`）＋定位（`NSLocationWhenInUseUsageDescription`）——問卷與 manifest 要一致；v1.2 曾因 5.1.2(i) 被拒，修正紀錄見 `CHANGELOG.md` 2026-07-28。
- **Support URL**：`https://…/logbook/privacy`（真網頁，非 mailto）✅。
- **測試**：`run_tests logbook` 147/0/1 ✅（`ImportCoordinatorTests` 崩潰已修，`181e441`）。
- **實機／模擬器走一次匯入流程**：`ImportCoordinator` 的 deinit 崩潰在正式版關閉匯入精靈時是同一路徑——修正後應手動驗一次。
