# HANDOFF — JD2-Logbook

> 交接文件（固定檔名滾動式；前一版在 docs/handoff-archive/HANDOFF_2026-07-27.md）。

## 交接時間

2026-07-28（產生方式：/handoff skill）

## 目前狀態

- 所在里程碑：**v1.2 (Build 3) 已送出審核**（iOS + macOS 皆 Waiting for
  Review，2026-07-28）。本輪工作重點：修正 iOS 1.0 送審駁回的兩項理由
  （2.3.6 Age Rating／5.1.2(i) Privacy 追蹤宣告不符）並重新送審；App Store
  文案三語（EN/繁中/日文）定版套用至 iOS+macOS；全專案文件正確性校對
  （ARCHITECTURE.md／UI_UX_SPEC.md／README.md／WCAG 清單／
  LOCALIZATION_GUIDE.md，修正累積自 v1.0 規劃期的多處過時敘述）；
  v1.1→v1.2 定版復盤報告；家族層資料彙整（COMPAT_MATRIX 更新、觸發
  Vary-by-Plural 延後決策執行）。
- **未 commit 變更**：`V1_RELEASE_CHECKLIST.md`（新增「下一版重點工作」
  章節，記錄 plural bug 待辦，內容見下方「陷阱提醒」）。其餘皆已 commit
  並 **push 完成**（HEAD: `210370e`，與 origin/main 同步，工作樹除上述
  一份外皆乾淨）。
- 共用層版本：DiveKit **v1.4.0**／DiveImportKit **v0.4.1**，與
  `_JD2-family/F-02-COMPAT_MATRIX.md` 一致；本輪**未異動任何 Kit 程式碼
  或版本**；`check_family_drift.sh` 2026-07-28 重跑**全綠**（僅剩已知、
  刻意保留的「潛水術語 272 處不一致」提醒，不計入 FAIL）。

## 進行中的決策（尚未定案）

- 無阻塞決策。`V1_RELEASE_CHECKLIST.md` 裡「IAP 項目在 App Store Connect
  建立並審核通過」一項標記「沒找到相關文件紀錄，需要 PM 直接在 ASC 後台
  確認狀態」——非阻塞，但下次進 ASC 時值得順手看一眼。

## 下一步（按順序，具體到可直接執行）

1. **檢查 Apple 審核結果**：App Store Connect → JoyDive² → 確認 iOS App／
   macOS App 的 v1.2 (Build 3) 狀態是否仍為 Waiting for Review，或已有
   結果。
2. **若再次被拒**：優先重複本輪驗證方法——**重新整理 ASC 頁面、即時核對
   當下畫面狀態，不信任任何「上次已處理」的文字記錄**，完整方法論見
   `docs/reports/R-2026-07-28-iOS送審駁回二次核查與修正.md`。
3. **若審核通過**：依使用者 2026-07-28 明確指示，開始處理
   `V1_RELEASE_CHECKLIST.md`「下一版重點工作」章節記錄的 **Vary-by-Plural
   顯示 bug**（`JD2-Logbook/JD2-Logbook/Views/Import/ImportWizardView.swift`
   的 `"%lld dive%@ imported"`／`"%lld skipped (duplicates)"`）——18 種
   語言 count≠1 時會混入字面英文 "s"，是可見的顯示 bug 不是翻譯精緻度
   問題。完整技術方案（含 Logbook 專屬的 `String(localized:locale:)` 修法
   與模擬器多語言實測要求）見 `_JD2-family/F-09-PLURAL_LOCALIZATION_GUIDE.md`
   §3「兩個 App 的技術路徑不同」。
4. Export/Import Backup 功能、剖面圖警示標記（上升速度警示）兩個
   feature flag（`showBackupSection`／`showWarningEvents`）待驗證後開放，
   見 `V1_RELEASE_CHECKLIST.md`「已列 v1.2」章節。
5. 地圖 VoiceOver 無障礙改造（獨立縮放按鈕／逐一切換 pin）——範圍明確的
   獨立功能，非小修，見 `WCAG_2.1_AA_AUDIT_CHECKLIST.md` 附錄 5。
6. 潛水術語跨 App 一致性 272 處不一致——待有翻譯資源的 session 逐項核對，
   見 `_JD2-family/F-10-DIVE_TERMINOLOGY_GLOSSARY.md`，查核指令
   `python3 _JD2-family/scripts/dive_terminology_glossary.py check`。

## 陷阱提醒

- **「已在 ASC/後台完成」的記錄不可盡信，必須重新整理頁面即時核對再
  判斷**——這是本輪最大的教訓：2026-07-25 記錄「App Privacy 問卷已改為
  No」，但 2026-07-28 送審前重新逐格核對 ASC，發現 Coarse Location／
  Device ID／Usage Data 三格的「Third-Party Advertising」用途勾選其實
  還在，07-25 的操作大概率漏改了這一格。任何送審前的檢查清單，最終驗證
  基準永遠是**重新整理後的即時畫面狀態**，不是操作當下的記憶或幾天前的
  截圖。
- **ASC 隱私問卷有兩個容易混淆的獨立控制項**：資料類型的「Purpose」勾選
  清單（含 Third-Party Advertising 等選項）與後續「是否用於追蹤」問題是
  不同畫面、不同欄位，勾了 Purpose 裡的「Third-Party Advertising」本身
  即等同宣告追蹤，跟後面追蹤問題怎麼回答無關。詳見
  `_JD2-family/F-08-SUBMISSION_PITFALLS.md`。
- Logbook 的動態數量字串走自訂 `AppLanguageManager.localized()` +
  `String(format:)`（為了支援 App 內建語言切換器），**繞過 Apple 原生
  stringsdict 複數解析機制**——光改 `.xcstrings` 的 Vary-by-Plural 資料
  完全不會生效，這跟 ultra 端的修法不同，見上方「下一步」#3。
- 家族層文件（`_JD2-family/F-08`／`F-09`／`F-10` 三份 2026-07-28 新建）
  已登錄進 `AppProject/CLAUDE.md` 開場必讀清單與 `jd2-logbook.md` agent
  定義，新增翻譯前應先查 `dive-terminology-glossary.json`／
  `dive-terminology-concepts.json`，不要重新翻一次已有 canonical 翻譯的
  潛水術語。

## 開場指令建議（給下一個 session）

先讀本檔，接著到 App Store Connect 確認 iOS/macOS v1.2 (Build 3) 審核
是否已有結果，依上方「下一步」#2 或 #3 接續。不需要重新驗證家族層同步
狀態（本次交接已跑過 `check_family_drift.sh`，全綠）。若 `V1_RELEASE_
CHECKLIST.md` 的未 commit 變更還在，先確認內容仍然正確再 commit（單純
記錄性質，正常情況下直接 commit 即可）。
