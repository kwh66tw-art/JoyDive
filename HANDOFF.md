# HANDOFF — JD2-Logbook

> 交接文件（固定檔名滾動式；前一版在 docs/handoff-archive/HANDOFF_2026-07-28.md）。

## 交接時間

2026-07-30（產生方式：/handoff skill）

## 目前狀態

- 所在里程碑：**v1.2 (Build 3) 已於 2026-07-29 通過審核並上架**（iOS +
  macOS）。上架後發現 App Store 關鍵字策略失敗（已記入
  `V1_RELEASE_CHECKLIST.md`「下一版重點工作」首要任務，見下）。本輪
  （2026-07-30）另外完成：**解除 trimix 減壓分析的 F5 暫時繞過**——家族
  總指揮（`JD2-Fami_01`）跨 session 派工，DiveKit 前置條件（v1.5.0 雙氣體
  Buhlmann／v1.6.0 DecoCalculator 正式修復／v1.7.0 N2 隔室常數修正）皆已
  完成並經黑盒交叉驗證後，`DiveReplayEngine`／`DiveAnalysisView` 移除
  trimix 短路邏輯，trimix 潛水現在與 air/nitrox 走完全相同的分析路徑。
- **未 commit 變更**：`CHANGELOG.md`（新增 2026-07-30 條目）、
  `JD2-Logbook/JD2Core/Algorithm/DiveReplayEngine.swift`、
  `JD2-Logbook/JD2-Logbook/Views/Logbook/DiveAnalysisView.swift`、
  `JD2-Logbook/JD2-LogbookTests/F5DiveKitMigrationE2ETests.swift`——**即將
  在本次交接後立即 commit**（使用者已下指示）。本地 main 領先
  origin/main 3 個 commit（`dc8c1ae`／`05852a8`／`64ece37`，皆為上一輪
  session 已 push 完成的 v1.2 上架與家族協調相關 docs commit，這輪新增
  的 trimix commit 會疊加在其後）。
- 共用層版本：DiveKit **v1.7.0**（`56c3826`）／DiveImportKit **v0.4.1**，
  與 `_JD2-family/F-02-COMPAT_MATRIX.md` 一致。本輪未新增 Kit 版本異動，
  只是 Logbook 重新 build 抓到 v1.7.0 既有修正並解除自己的繞過邏輯。

## 進行中的決策（尚未定案）

- 無阻塞決策。`_JD2-family/decisions/2026-07-18_trimix減壓計算缺口.md`
  裡「隔室 1 N2/He 配對問題」（發現 2）仍待 PM／總指揮裁示要統一哪個變體，
  本輪未動，不影響本次已完成的工作。

## 下一步（按順序，具體到可直接執行）

1. **確認 push**：`git push origin main`，把本輪 trimix commit（與稍早已
   累積但未 push 的 3 個 commit 一併）送上去。
2. **回報家族總指揮（`JD2-Fami_01`）**：trimix 解除繞過已完成並驗證，
   commit hash 記得附上；順便同步 macOS CLI 測試 infra 的既有缺口（見
   下方陷阱提醒），供總指揮評估是否要排入其他 App 的檢查範圍。
3. **App Store 關鍵字策略重新設計**（v1.2 上架後發現的首要任務，見
   `V1_RELEASE_CHECKLIST.md`「下一版重點工作」）：以「潛水日誌／dive log」
   核心意圖詞為主軸，品牌相容性移到 Description 內文，三語各自依搜尋習慣
   重新規劃，不要三語共用同一組英文詞。
4. Vary-by-Plural 顯示 bug（`ImportWizardView.swift`）：v1.2 審核通過後
   排入，完整技術方案見 `_JD2-family/F-09-PLURAL_LOCALIZATION_GUIDE.md`
   §3。
5. Export/Import Backup 功能、剖面圖警示標記兩個 feature flag 待驗證後
   開放（`V1_RELEASE_CHECKLIST.md`「已列 v1.2」章節）。
6. 地圖 VoiceOver 無障礙改造——範圍明確的獨立功能，非小修。
7. 潛水術語跨 App 一致性 272 處不一致——待有翻譯資源時逐項核對
   （`_JD2-family/F-10-DIVE_TERMINOLOGY_GLOSSARY.md`）。

## 陷阱提醒

- **macOS 的 `xcodebuild test`／`build-for-testing` 目前透過 CLI 無法執行**
  （`@testable import JoyDive_` 回報 "unable to resolve module dependency"）
  ——本輪已用 `git stash` 驗證此問題在 trimix 改動之前就存在（未改任何
  程式碼一樣重現），非本輪引入的回歸。根因研判與 Test Action 的多平台
  destination 解析有關（macOS 目的地下仍嘗試解析 Debug-iphoneos 路徑），
  未深入排查（超出本輪任務範圍）。macOS **App build**（非測試）透過 CLI
  正常成功；`DiveReplayEngine`／`DiveAnalysisView` 皆為無平台分支的共用
  檔案，iOS 測試套件已完整覆蓋其邏輯，不影響本輪驗證的可信度，但下次若要
  在 CLI 上跑 macOS 單元測試，這個 infra 缺口需要先解決（建議用 Xcode GUI
  ⌘U 在 My Mac scheme 上測試作為替代方案）。
- **trimix 组织艙飽和度視覺化的 He 加權公式是 Logbook 本地重新實作**
  （`DiveReplayEngine.tissueLoadPercent`），不是呼叫 DiveKit 的 API（
  `combinedAB()` 是 DiveKit 內部私有函式，未公開）——沿用同一套加權規則，
  但如果 DiveKit 未來變更這個公式，Logbook 這邊需要手動同步，目前沒有
  機制性防呆（同類陷阱見 `SYNC_TO_JD2-ULTRA.md` #8 記錄的 error enum
  複製教訓，這裡是同一種模式的第三個實例，只是這次是公式而非樣板文字）。
- **`ReplayResult.decoDataUnavailable` 旗標已完全移除**（不是保留但恆
  false）——如果之後任何地方需要重新引入「某氣體暫不支援分析」的概念
  （例如未來有其他尚未支援的氣體類型），不要假設這個旗標還在，需要重新
  設計。

## 開場指令建議（給下一個 session）

先讀本檔，確認上方「未 commit 變更」是否已 commit+push（若這次交接後已
立即處理，這裡的清單應該已經清空）。接續「下一步」#3（App Store 關鍵字
策略）或 #2（回報家族總指揮，若還沒做）。不需要重新驗證 trimix 邏輯本身
——iOS 78 測試全綠、真實樣本端到端數字已記錄在 `CHANGELOG.md` 2026-07-30
條目，除非有新的程式碼變動觸及 `DiveReplayEngine`/`DiveAnalysisView`。
