# HANDOFF — JD2-Logbook

> 交接文件（固定檔名滾動式；前一版在 `docs/handoff-archive/HANDOFF_2026-10-26.md`，v1.3 送審與更早紀錄在 `HANDOFF_2026-10-18.md`）。

## 交接時間
2026-10-27 12:03（產生方式：/handoff skill）

## 目前狀態
- **所在里程碑**：v1.4 開發中（v1.3 Build 4 已上架）。A1 環境「未記錄」✅、A2 搜尋擴充 ✅、D-A ✅、D-C ✅；A3／B1／B2／C 未做。
  進度與裁示：`docs/V1_4_WORK_PLAN.md`（已同步）；全盤稽核：`docs/V1_4_AUDIT_TEST_PLAN.md`（逐項狀態＋發現 F1–F19）。
- **未 commit 變更**：本次交接的文件更新（CHANGELOG、KNOWN_ISSUES、V1_4_WORK_PLAN、CLAUDE.md、本檔、歸檔）——待 PM 確認後提交。程式最後提交 `04c9af6`（= origin/main）。
- **測試**：`run_tests.sh logbook` **212／0／1**（唯一允許的 skip＝`PurchasePriceDisplayTests.testPremiumPriceStringIsNilWhenProductNotYetLoaded`，依 StoreKit 載入時機浮動）。
- **共用層**：DiveKit **v9.7.0**、DiveImportKit **v0.8.2**（local path、無版本鎖定；`check_doc_version_sync.sh` 通過）。COMPAT_MATRIX 的 App-lb 列由總指揮在 v9.8.0 合併後一起補。
- **已裁示的決策檔**（皆 `docs/decisions/`）：`D-2026-10-26-環境欄位未記錄.md`、`D-2026-10-26-v1.4-D3至D7裁示.md`、
  `D-2026-10-26-DA-舊標籤高海拔前導潛水-聯合提案.md`（主案 a' 已由 Kit v9.7.0 取代暫行 a；10/27 更正 a'' 理由）、`D-2026-10-27-DC-水面氣壓不合理值顯示-聯合提案.md`。

## 進行中的決策（尚未定案）
- **D-B**：手動新增要不要加潛伴／標籤欄位（會動 schema → V1_5）。未裁示。
- **D-E**：搜尋 2,000 筆每鍵 30–38 ms（> 16 ms，本專案門檻）。App-lb 建議先記已知限制、有回報再做記憶體快取。未裁示。
- **F17／F18／F19**（既有，非 v1.4）：AX5 版面、`MockDataSeeder` 進 Release、`Localizable.xcstrings.backup` 進 App。PM 10/27：另行排程，現在不處理。
- **文案**：A1 三段、D-A 兩句原因、A2 搜尋提示皆為草稿（英／繁中／日）；⏸ 上架前收尾定稿＋其餘 14 語（PM 10/26）。

## 下一步（按順序）
1. **等總指揮通知 DiveKit v9.8.0 合併**（F14：環境數值不合理 ⇒ 新 case `Anomaly.implausibleEnvironment`，`.untrustedEnvironment` 語意不變）。合併後：
   跑 `bash /Users/kevin/Documents/AppProject/_JD2-family/scripts/run_tests.sh logbook` ⇒ 預期 `EnvironmentEdgeCaseTests.testImplausibleSurfacePressureCurrentBehavior` 紅 ⇒
   把重放段改成斷言 `.implausibleEnvironment`（顯示段已是 D-C (a)，不動）；`LegacyAltitudeReplayGate.reason(for:)` 不用改（新 case 自然走通用句）；
   CLAUDE.md DiveKit 版號改 v9.8.0、跑 `check_doc_version_sync.sh`；回報總指揮三數字。
2. **稽核收尾**：T29（全 repo grep `environmentType`／`"altitude"`／`Search location…`／`importExtras[` 逐處審查）、T30（`check_privacy_manifest.py`、版號、機敏掃描）。
   T19 已因判定移到 Kit 而不再適用（App 只顯示 Kit 的原因，不會重複）；T7 同 T6，備份介面自 v1.2 隱藏 ⇒ 不適用。回填稽核計劃。
3. **待 PM 手動**：iOS 模擬器文字輸入（T4 存檔後重開、T27 iOS、T28 iOS）。或加 UI 測試 target 自動輸入（需 PM 同意）。
4. **v1.4 剩餘功能**（PM 排序）：A3 列表篩選（組織負荷篩選以 Kit 重放結果為準、不得另寫條件；統計／地圖不跟篩選）→ B1＋B2 → C。

## 陷阱提醒
- **提交閘門**：commit 前用 `set -e` 串機敏掃描＋`check_doc_version_sync.sh`，失敗就停（10/27 曾在版號檢查回 1 時照推，因 DiveImportKit v0.8.2 未通知就上 main）。**逐檔 `git add`，不用 `-A`**（總指揮要求）。
- **Kit 可能未通知就更新**：local path 引用 ⇒ 下一次 build 就吃新版。開工前先 `git -C ../_JD2-family/DiveKit describe --tags`、`DiveImportKit` 同。
- **macOS 實測不得用正式 bundle ID**：PM 這台 Mac 的 `~/Library/Containers/com.jd2logbook.JD2-Logbook` 是 **v1.3 真實資料（70 筆，結構 1.0.0/48ac84ec）**，v1.4 開啟會遷移、v1.3 就打不開。
  做法（PM 10/27 指定）：`xcodebuild … PRODUCT_BUNDLE_IDENTIFIER=com.jd2logbook.JD2-Logbook.audit CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=`，測前測後比對真實 store 的 SHA-256。
- **iOS 模擬器文字輸入**：simctl 貼上、模擬器工具 text、螢幕鍵盤點擊三種都進不了欄位 ⇒ 不要再試；macOS 的 app_type 可以。改 App 語言用 App 內選單（`simctl spawn defaults write` 第二次起不生效）。
- **假資料剖面 JSON 鍵是 `t`／`d`／`w`**（`DiveProfileSample` CodingKeys），不是 `timeSeconds`；氣體 JSON 是 `"air"` 或 `{"nitrox":{"fO2":0.32}}`。
- 測試中不得釋放 `AppLanguageManager`（SIGABRT）⇒ 用 static 共用實例；zsh 不拆 `$var` ⇒ 迴圈寫成 bash 腳本；測試取數用 `TEST_RUNNER_JD2_T18_OUT=<主機路徑>`。
- 舊版 App 編譯要用當年的 Kit（`git archive` 匯出到 scratchpad，不要在 Kit repo 開 worktree）。
- 量具自我驗證：`grep -rlF` 在 .app 上對照組失效（10/27），改用 `strings -a <binary>`，先確認 Debug 對照組找得到再判 Release。

## 專用模擬器與測試資料（可刪）
- iOS：`JD2-LB-UpgradeTest`、`JD2-LB-Upgrade-v10／v12／v13`（跳版升級 T1–T3）、`JD2-LB-Audit`（10/27：105 筆假資料＋8 筆特製紀錄；語言已還原為跟隨系統）。
- macOS：`~/Library/Containers/com.jd2logbook.JD2-Logbook.audit`（audit 版本的獨立資料，可整個刪除）。
- 截圖：`docs/screenshots/v1.4-A1/`、`v1.4-A2/`、`v1.4-audit-sim/`（01–29）。

## 開場指令建議（給下一個 session）
先讀本檔與 `docs/V1_4_AUDIT_TEST_PLAN.md`（逐項狀態）、`docs/V1_4_WORK_PLAN.md`；確認 Kit 版號：
`git -C /Users/kevin/Documents/AppProject/_JD2-family/DiveKit describe --tags`（v9.7.0 或已到 v9.8.0）；
跑 `bash /Users/kevin/Documents/AppProject/_JD2-family/scripts/run_tests.sh logbook`，對照 **212／0／1**。
