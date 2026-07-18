# JoyDive²（JD2-Logbook）— 專案文件登錄表 v1.7

**專案代號：** JD2-Logbook
**文件版本：** v1.7
**建立日期：** 2026-07-04
**維護人：** 開發負責人

> 本登錄表列出本專案從前期規劃到上線所需的所有文件，作為進度追蹤與品質管控的唯一索引。
> 每次新增或更新文件時，同步更新此表的版本號與狀態。

---

## 一、狀態說明

| 狀態標籤 | 說明 |
|---------|------|
| ✅ 完成 | 文件已建立，內容可用 |
| 🔄 進行中 | 文件已建立草稿，持續更新 |
| 📋 待建 | 尚未建立 |
| ⏸ 凍結 | 暫不需要（依里程碑）或已封存 |

---

## 二、核心專案文件

| # | 文件名稱 | 狀態 | 最後更新 | 說明 |
|---|---------|------|---------|------|
| C-01 | `README.md` | ✅ 完成 | 2026-07-04 | 專案介紹、編譯方式、目錄結構、功能摘要 |
| C-02 | `CLAUDE.md` | 🔄 進行中 | 2026-07-04 | Claude agent 工作指引；含 Bundle ID / Apple Team / 下次發布流程 / Export Compliance，隨進度持續更新 |
| C-03 | `CHANGELOG.md` | 🔄 進行中 | 2026-06 | 版本異動紀錄；v1.0.0 正式上線後補上線日期定稿 |
| C-04 | `JD2-Logbook_文件登錄表_v1.7.md` | ✅ 完成 | 2026-07-17 | 本文件 |

---

## 三、設計與規格文件

| # | 文件名稱 | 狀態 | 最後更新 | 說明 |
|---|---------|------|---------|------|
| D-01 | `ARCHITECTURE.md` | ✅ 完成 | 2026-06-03 | 模組設計、SwiftData schema、8 種解析器一覽、UI 架構、SPM 依賴 |
| D-02 | `UI_UX_SPEC.md` | ✅ 完成 | 2026-05-20 | UI/UX 完整規劃書 v1.0（Week 10 決策確認版） |

---

## 四、技術維護文件（Docs/）

| # | 文件名稱 | 狀態 | 最後更新 | 說明 |
|---|---------|------|---------|------|
| T-01 | `Docs/ADMOB_IAP_SETUP.md` | ✅ 完成 | 2026-06 | AdMob App ID / 4 個 Ad Unit ID / IAP 設定紀錄。⚠️ 含真實 ID，勿上傳公開 repo |
| T-02 | `Docs/LOCALIZATION_GUIDE.md` | ✅ 完成 | 2026-06 | 18 種語言維護流程、用詞規範（繁中/簡中區分） |
| T-03 | `Docs/KNOWN_ISSUES.md` | 🔄 進行中 | 2026-07-17 | 已知問題、技術雷區（SwiftData migration、pbxproj、xcstrings 空 key、AdMob v11 API、Supabase 非整合澄清、TEST_HOST 修復）；新增「待決策事項」（macOS LSApplicationCategoryType）；v1.1 規劃改為精簡清單並指向 `V1_1_BACKLOG.md` 為單一權威來源 |
| T-04 | `SwiftData Migration 指引` | ⏸ 凍結 | 2026-07-17 | 原規劃給 v1.1 `avgDepth`/`importExtrasJSON` schema 變更用；實作時採 additive 欄位＋預設值（lightweight migration，無需手動 migrationPlan），已隨 v1.1 完工驗證零事故，本文件不再需要 |

---

## 五、上架與法規文件

| # | 文件名稱 | 狀態 | 最後更新 | 說明 |
|---|---------|------|---------|------|
| L-01 | `logbook/privacy.md` | ✅ 完成 | 2026-06-07 | 隱私政策正文（EN / 繁中 / 日文）。**唯一來源**，同時作為 GitHub Pages 線上版本 |
| L-02 | `Docs/APPSTORE_COPY.md` | ✅ 完成 | 2026-06 | App Store 上架文案：名稱、副標、描述、關鍵字 |

---

## 六、QA 與驗證文件

| # | 文件名稱 | 狀態 | 最後更新 | 說明 |
|---|---------|------|---------|------|
| Q-01 | `V1_RELEASE_CHECKLIST.md` | 🔄 進行中 | 2026-07-17 | 上線前驗證清單（Block release / 建議完成 / 提審準備三級）；新增「待決策」章節（macOS LSApplicationCategoryType）；編譯/測試/覆蓋率三項已勾銷 |
| Q-02 | `WCAG_2.1_AA_AUDIT_CHECKLIST.md` | 🔄 進行中 | 2026-05 | 可達性合規查核表；排定 2026-08-02 ~ 08-09（Week 12）執行最終審核 |
| Q-03 | `真機驗證報告` | 📋 待建 | — | v1.0 上線後執行：AdMob 廣告（Logbook / Import / Settings）、IAP $1.99 購買流程、Restore Purchase 真機驗證結果 |
| Q-04 | `audit_report-0717.md` | ✅ 完成 | 2026-07-17 | 外部稽核報告（核心演算法 + 匯入流程），提出 4 項風險，逐項核對後確認全數屬實並修復，詳見 `CHANGELOG.md` 同日條目與 `SYNC_TO_JD2-ULTRA.md` |

---

## 七、規劃與 Backlog

| # | 文件名稱 | 狀態 | 最後更新 | 說明 |
|---|---------|------|---------|------|
| P-01 | `V1_1_BACKLOG.md` | ✅ 完成 | 2026-07-17 | v1.1 待辦整合：3 項技術債 + 11 項功能擴充。**13/14 項完工**（#9/#10 iOS 18 Widget PM 確認不需要，終止規劃）；**單一權威來源**，KNOWN_ISSUES.md 只放精簡清單 |
| P-02 | `V1_1_BACKLOG_解法參考_from_JD2-Ultra.md` | ✅ 完成 | 2026-07-13 | 姊妹專案 [JD2-ultra](../JD2-ultra) 單向提供的 backlog 解法參考（不回寫 Ultra）；含 BuhlmannCalculator 停用警告、DiveKit 取用建議。Ultra 端不再同步更新，對照版本 v0.2.8 |
| P-03 | `SYNC_TO_JD2-ULTRA.md` | 🔄 進行中 | 2026-07-17 | 方向與 P-02 相反：JD2-Logbook → Ultra 單向記錄，追蹤「在 Logbook 發現、程式碼可追溯到 Ultra（DiveKit port 或架構相似）的問題」，供 Ultra 端未來參考同步。首批 4 筆：外部稽核報告 4 項風險，已逐一核對 Ultra 對應檔案確認同樣存在、尚未修復 |

---

## 八、交接與歷史文件

| # | 文件名稱 | 狀態 | 最後更新 | 說明 |
|---|---------|------|---------|------|
| H-01 | `Archive/HANDOFF_JD2LB_15.md` | ⏸ 凍結 | 2026-06-07 | 交接文件；內容已由 `CLAUDE.md` 接手，2026-07-04 移入 `Archive/` |
| H-02 | `Archive/HANDOVER_Cowork-ClaudeCode.md` | ⏸ 凍結 | 2026-07-04 | Cowork → Claude Code 交接文件；內容已核對與 `project.pbxproj` 一致，新增資訊（Bundle ID、Apple Team、下次發布流程、Export Compliance）已併入 `CLAUDE.md`，隨即移入 `Archive/` |
| H-03 | `Archive/`（43 份，含 H-01、H-02） | ⏸ 凍結 | — | 開發過渡性文件封存：週交接（HANDOFF_WEEK2~13、JD2LB_10~15）、稽核報告（W3-W8/W9/解析器/FIT）、開發計劃（12 週計劃、Reality-Based Plan）、格式技術分析、色彩系統計畫、翻譯注意事項等。僅供追溯，不再更新 |
| H-04 | `Archive/stray_root_folders/`（2 個資料夾） | ⏸ 凍結 | 2026-07-17 | 專案根目錄整理時發現的孤兒資料夾，非刪除、原檔案原封不動移入：`Sources/JD2Logbook.swift`（早期 `swift package init` 預設樣板，從未被使用，與現行 Xcode 專案架構無關）、`Tests/`（僅含 `.DS_Store`，無實質內容）。同時移除 9 個確認完全空白（0 檔案，非 git 追蹤，未被 `.xcodeproj`/測試程式引用）的空目錄：`JD2-App`、`JD2-LB_b`、根層級 `JD2Core`（與 `JD2-Logbook/JD2Core` 重複的孤兒目錄）、`JD2-Logbook/JD2-LogbookTests/TestFiles/`（含 `Suunto` 子目錄，路徑與測試實際使用的根層級 `TestFiles/` 不同，未被引用）、`TestFiles/{Cressi,GPX,Mares,Oceanic}`、`file_format_research/Peregrine_XML` |

---

## 九、里程碑索引

| 里程碑 | 相關文件 | 狀態 / 目標時間 |
|--------|---------|---------------|
| v1.0 提審 | Q-01、L-01、L-02、T-01 | ✅ 已完成（2026-06-17 提審；macOS 已過審，iOS 審核中） |
| WCAG 最終審核 | Q-02 | 2026-08-02 ~ 08-09（Week 12） |
| v1.0 上線 | C-03（補上線日期）、Q-01（全數勾銷） | 2026-08-18 |
| 上線後驗證 | Q-03（真機驗證報告） | 上線後 1 週內 |
| v1.1 開發 | P-01、P-02、T-03 | ✅ 13/14 項完工（2026-07-14 啟動 → 2026-07-17 完工；#9/#10 Widget 終止規劃） |
| v1.1 上架前待決策 | `Docs/KNOWN_ISSUES.md`「待決策事項」、Q-01 | macOS LSApplicationCategoryType，待新版本收斂準備上架前決定 |

---

> **文件版本：** v1.7 | **建立日期：** 2026-07-04 | **最後更新：** 2026-07-17
> **v1.0 變更：** 初版建立。盤點專案現有 14 份現役文件 + Archive 42 份歷史文件，新增 2 項待建文件（SwiftData Migration 指引、真機驗證報告）。同日執行盤點時發現的兩項整理：`HANDOFF_JD2LB_15.md` 移入 `Archive/`、README 專案結構圖修正（移除已刪除的 `PRIVACY_POLICY.md`，補上 `logbook/` 與本登錄表）。
> **v1.1 變更：** 確認 `HANDOVER_Cowork-ClaudeCode.md`（2026-07-04 建立）為最新交接內容，逐項核對 `project.pbxproj` 一致（Bundle ID、Build 2、iPhone-only）；新增的維運細節（Apple Team、下次發布 5 步驟流程、Export Compliance 選項、Debug Developer Tools 說明）已併入 `CLAUDE.md`，該交接檔隨即移入 `Archive/`（登錄為 H-02），Archive 更新為 43 份。
> **v1.2 變更：** 兩項查證與整理（2026-07-13）。① Supabase 帳號通知專案 `joydive` 即將凍結，查證程式碼與 [JD2-ultra-D4](../JD2-ultra-D4) 均無 Supabase 整合（兩專案同步架構皆為 Apple CloudKit），PM 決定還原保留、結果記錄於 `Docs/KNOWN_ISSUES.md` 新增段落「Supabase 專案（非本專案技術棧）」。② 姊妹專案資料夾由 `JD2-ultra` 更名為 `JD2-ultra-D4`，全文掃描確認本 repo 僅 `V1_1_BACKLOG_解法參考_from_JD2-Ultra.md` 引用該路徑且原本已用新名稱，無需修改；新登記該文件為 P-02。
> **v1.3 變更：** 姊妹專案資料夾由 `JD2-ultra-D4` 改回 `JD2-ultra`（2026-07-13，同日二次更名）。全文掃描更新 3 處活動引用：`V1_1_BACKLOG_解法參考_from_JD2-Ultra.md`（2 處路徑）、`Docs/KNOWN_ISSUES.md`（1 處連結 + 1 處路徑）、本表 P-02 說明欄；v1.2 版變更紀錄保留原文不回溯修改，僅供歷史對照。
> **v1.4 變更（v1.1 開工，2026-07-14）：** iOS 審核逾期未回覆，PM 決定不再等待、直接啟動 v1.1 開發。開工前稽核 `V1_1_BACKLOG.md` 與 `Docs/KNOWN_ISSUES.md` 發現後者 v1.1 清單漏同步 3 項技術債（06-07 vs 06-08 的一天落差）；同時發現 #4/#5 依賴的本地 `Buhlmann.swift`/`DiveEngine.swift` 是死碼，對應 Ultra 稽核（`JD2-ultra_決策.md` §4.2）實際為 9 項已知安全問題（P-02 參考文件誤植 8 項）。PM 拍板兩項決策：① #4/#5 改為整包 port Ultra `DiveKit`，不修本地死碼；② 新增 #14 Export/Import 備份功能與 #6 一起做（稽核發現 `DiveLogDatabase.exportAsJSON/importFromJSON` 目前是拋錯 stub）。`V1_1_BACKLOG.md` 已更新為 14 項並記錄兩項決策；`Docs/KNOWN_ISSUES.md` 的 v1.1 規劃段落精簡為清單＋指向 `V1_1_BACKLOG.md`，避免雙處維護再度失同步。
> **v1.5 變更（v1.1 完工，2026-07-17）：** v1.1 backlog 13/14 項完工（#1–8、#11–14），詳細內容見 `CHANGELOG.md` 2026-07-17 條目。T-04（SwiftData Migration 指引）改為凍結——實作時證實 additive 欄位＋預設值已足夠，不需正式 migrationPlan 文件。新增待決策事項：macOS `Info.plist` 的 `LSApplicationCategoryType` 誤觸發系統遊戲模式，PM 決定延後到下次上架前拍板，已記錄於 `Docs/KNOWN_ISSUES.md` 與 `V1_RELEASE_CHECKLIST.md`。
> **v1.6 變更（外部稽核修復，2026-07-17）：** 外部稽核報告 `audit_report-0717.md` 提出 4 項風險，逐項核對後確認全數屬實並修復（`Buhlmann` chunking pRate 歸零、匯入批次去重漏洞、匯入解析阻塞主執行緒、OTU 跨日未重置），詳見 `CHANGELOG.md` 同日條目。同時核對 [JD2-ultra](../JD2-ultra) 對應程式碼，確認 4 項風險同樣存在、尚未修復（不同專案，本次僅評估未修改）；新增 `SYNC_TO_JD2-ULTRA.md`（登記為 P-03）作為長期追蹤文件，記錄「Logbook 發現、可能同樣影響 Ultra」的問題供其參考同步。
> **v1.7 變更（專案根目錄整理，2026-07-17）：** 全面掃描 repo 根目錄與各子目錄，**不刪除任何檔案**：移除 9 個完全空白（0 檔案、非 git 追蹤、未被 `.xcodeproj` 或測試程式引用）的孤兒空目錄（`JD2-App`、`JD2-LB_b`、根層級重複的 `JD2Core`、`JD2-Logbook/JD2-LogbookTests/TestFiles/Suunto` 及其變空的父目錄、`TestFiles/{Cressi,GPX,Mares,Oceanic}`、`file_format_research/Peregrine_XML`）；另有 2 個非空但明顯孤兒的根層級資料夾（`Sources/`：早期 `swift package init` 樣板，`Tests/`：僅含 `.DS_Store`）**原檔案原封不動移入** `Archive/stray_root_folders/`，登記為 H-04。整理後 iOS/macOS 雙平台建置與完整測試套件皆確認正常，未影響任何現行功能。新增 `audit_report-0717.md` 為正式登錄文件（Q-04）。
> 依里程碑推進時，逐步更新本表各文件的狀態。
