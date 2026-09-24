# HANDOFF — JD2-Logbook

> 交接文件（固定檔名滾動式；前一版在 `docs/handoff-archive/HANDOFF_2026-09-13.md`）。

## 交接時間

2026-09-25（PM 指示「更新進度」手寫；本輪**只動文件**，零程式碼改動）

---

## 目前狀態

### 工作區

- `git status --porcelain` 乾淨（本次 `git mv` 舊 HANDOFF 除外）。
- 本地 HEAD：`6b45791 docs(CLAUDE): DiveKit 引用版號 v5.1.0→v5.2.0`。
- ⚠️ **本地領先 `origin/main` 15 個 commit，尚未 push**（`git status -sb` 實測
  `ahead 15`）。這 15 筆幾乎全是 2026-09-13～09-22 期間 DiveKit 連續打版
  （v1.29.1 → v5.2.0）逐次回填 `CLAUDE.md` 版號宣稱的 docs commit，其中
  **只有一筆是真程式碼改動**：`cebeb59`（見下）。**push 是對外動作，本輪
  未執行，需向 PM 確認是否現在 push**。
- Remote 為 `github.com/kwh66tw-art/JoyDive.git`（repo 名是 **JoyDive**，不是
  JD2-Logbook）。GitHub token 走 `credential.helper`（osxkeychain）。

### 共用層版本

- DiveKit：tag **v5.2.0**（`git describe` 確認）。2026-09-13～09-22 間連續
  打了十幾版，本 repo 逐次回填 `CLAUDE.md:13` 的版號宣稱字串，兩支閘門
  （`check_doc_version_sync`／`check_version_lock`）本輪重跑皆綠。
  絕大多數是**純文件/註解批次或本 App 零命中的變更**，`Sources/` 無感知；
  **唯一影響本 App 程式碼的是 DiveKit v4.0.0**（見下方「本輪之前的真實
  程式碼改動」）。
- DiveImportKit：tag **v0.7.1**（`git describe` = `v0.7.1-2-g33a7352`，
  2 個 commit 落後但未打新 tag，本輪未動）。
- 引用方式：SPM local path，**本 repo 無任何演算法／解析器原始碼拷貝**。
- **家族層 2026-09-22 交接文件**（`../_JD2-family/HANDOFF.md`）已獨立核對過
  本 repo 在同一個 HEAD（`6b45791`）下的狀態，與本檔互為交叉驗證來源。

### 本輪之前的真實程式碼改動（`cebeb59`，2026-09-21，PM 裁示）

DiveKit v4.0.0 把 `DiveReplayEngine.ReplayWarningKind.mandatorySafetyStop`
正名為 `.ascentSustained`（該警示的實際觸發條件從頭到尾是「超速持續 10
秒」，從未真的碰過安全停留機制；正名理由與家族決策見
`../_JD2-family/decisions/2026-09-21_移除強制安全停留加時-模型不相容.md`）。

本 App 跟進：`DiveAnalysisView.swift` 四處 case（icon／color／title／detail）
改用新名；文案從「Safety stop became mandatory: …」改寫為「Ascent rate
stayed above %1$.0f m/min (%2$.1f ft/min) for %3$d seconds.」（照實描述，
不再宣稱一個已移除的機制）；新增 2 個英文 key（其餘 18 語系待 #6 語系全審核
補齊）；舊 key（"Mandatory Safety Stop" 等）刻意保留不刪，已有完整翻譯留著
無害，是否清理併入 #6 一併考慮。

⚠️ **這個功能目前是關閉的**（`showWarningEvents = false`，PM 2026-08-13
裁示「先 mark 掉，之後改版再決定怎麼呈現」，見 `V1_2_BACKLOG.md` #3）——
**使用者今天看不到這次文案改寫**，純粹是跟上 Kit 介面改名、避免程式碼裡
留著描述已不存在機制的文字。

### 測試現況（家族層 2026-09-22 於同一 HEAD `6b45791` 驗證，本 session 另跑一次確認中）

- **129 passed／18 failed／1 skipped**（`../_JD2-family/HANDOFF.md` §0b 記錄，
  與本 repo 同一 HEAD）。
- 🔴 **18 個 failed 全是既有問題，非本輪回歸**：
  - **17 支 `ImportCoordinatorTests` SIGABRT**：根因是
    `ImportCoordinator.__deallocating_deinit` 在
    `swift_task_deinitOnExecutorMainActorBackDeploy` 上崩潰
    （`___BUG_IN_CLIENT_OF_LIBMALLOC_POINTER_BEING_FREED_WAS_NOT_ALLOCATED`）。
    `cebeb59` commit 訊息裡有對照組驗證：**本 repo HEAD ＋ DiveKit v3.0.0**
    （即今日這波版本推進動手前的狀態）跑出**完全相同的 17 支**——與
    `cebeb59`／後續版號回填皆無關，是既有缺陷。
    🔴 **成本被低估的地方**（家族層丁-11b 記錄）：每跑一次測試就會跳出一個
    **寫著產品名的 macOS 系統崩潰視窗**，已造成兩次誤報（PM 誤以為是新
    崩潰）。家族層已解析本機 28 份崩潰報告，**28 份全是 XCTest 驅動、真實
    使用 0 份**——但這只證明本機，且**不得用關閉系統崩潰回報器處理**（憲法
    禁止改系統設定）。**下次看到這個崩潰視窗跳出來，先確認是不是這 17 支
    測試在跑，不要當成新回歸驚動 PM。**
  - **1 支 `testPerformance_SuuntoJSON_Repeated`** 是既有牆鐘硬門檻
    （`< 100ms/parse`），機器負載敏感，2026-09-13 已記錄為 flaky，
    2026-09-21 再次確認超標僅 3.2%，非回歸。**刻意不改門檻**，正解仍是
    改量 CPU 時間或移出閘門套件，**待 PM 排入**（見下方「進行中的決策」）。
- 那 1 skipped 仍是 `PurchasePriceDisplayTests.swift` 的
  `XCTSkipUnless(premiumProduct == nil)`，環境相依，回報時需註明條件。

---

## 進行中的決策（尚未定案）

1. 🔴 **17 個新 key × 18 語言待母語審閱**（2026-09-12 重放限制說明，見
   `V1_2_BACKLOG.md` #6「第三輪」）＋ **本輪新增 2 個英文 key**（`cebeb59`
   的警示文案改寫，同樣待 18 語系補齊，可與第三輪合併處理）。
   ⇒ **這是本 repo 目前唯一明確的阻塞項**（阻塞下一次送審的文案定稿）。
2. **那支 `testPerformance_SuuntoJSON_Repeated` flaky 效能測試**：改量 CPU
   時間，或把三支 `testPerformance_*` 移出閘門套件——**不要改門檻數字**，
   待 PM 選一個方向。
3. **17 支 `ImportCoordinatorTests` SIGABRT**：已歸因為既有、非回歸，但
   從未被排入修復；是否值得花時間修（vs. 接受它是 XCTest 環境限定的
   已知缺陷）待 PM 裁示。
4. `GasMix.mod()` 的兩個靜默預設參數（`surfacePressure`／`metersPerBar`）
   移除——**家族層多次預告、多次確認「本批刻意沒做」**，最新一次確認是
   2026-09-13。`JD2-LogbookTests/GasMixTests.swift:33`／`:60` 目前**仍是
   無參數呼叫、仍會編過**（本輪已重新核對程式碼確認）。**下一個 session
   若看到這兩個測試無故編不過，先查有沒有漏看新派工單，不要自己亂猜**。
5. App Store 關鍵字策略重新設計（2026-07-29 上架後發現非品牌詞搜尋找不到
   本產品）——**已擱置超過八週，仍未執行**，記在 `V1_RELEASE_CHECKLIST.md`
   「下一版重點工作」第一項。需向 PM／總指揮確認是否仍是首要任務，還是
   已被其他優先事項（重放異常 UI、DiveKit 一系列升版）取代。
6. `.xcarchive` 清理——PM 已裁示「先不動」（2026-09-13），現況不變，
   不需要再排。
7. `V1_2_BACKLOG.md` #21（第二輪 AI 稽核報告）尚有「記錄待決」項目；#3
   剖面圖警示標記／狀態列第二列已建置但**先隱藏**（`showWarningEvents =
   false`），開放時機未定——`cebeb59` 的文案改寫已經跟進但功能本身仍關閉。
8. `V1_2_BACKLOG.md` #26（匯入自動帶入 dive mode）標註「待家族層，不在本
   repo 範圍」——不要在本 repo 自行決定。

---

## 下一步（具體到「打開哪個檔、跑哪條指令」）

1. **push 決策**：向 PM 確認是否現在把領先的 15 個 commit push 到
   `origin/main`（本 repo 有 remote，push 是對外動作，本輪未執行）。
2. **確認本 session 背景測試結果**：本輪已啟動
   `bash ../_JD2-family/scripts/run_tests.sh logbook`（背景執行中，跑
   iOS 全測試套件較久），完成後核對是否仍是 129/18/1，若數字不同要
   查為什麼（機器差異？新回歸？），不要假設一定跟家族層記錄一樣。
3. **語系第三輪＋ `cebeb59` 新增 key**：合併處理，`bash
   ../_JD2-family/scripts/check_localization.sh JD2-Logbook` 先確認使用
   鍵皆存在，再產 CSV 交母語審閱；術語先查
   `../_JD2-family/dive-terminology-glossary.json`（憲法鐵律 1／F-10）。
4. **flaky 效能測試處理**（若 PM 同意排入）：打開
   `JD2-Logbook/JD2-LogbookTests/ImportCoordinatorTests.swift:444`，
   二選一——(a) 改量 CPU 時間；(b) 把三支 `testPerformance_*` 移出閘門
   套件。不要改門檻數字。
5. **17 支 SIGABRT 是否修復**：待 PM 裁示是否值得投入，若要修，先讀
   `cebeb59` commit 訊息裡的對照組驗證方法，確認根因描述（`deinit` 在
   `swift_task_deinitOnExecutorMainActorBackDeploy` 崩潰）沒有過時。
6. **關鍵字策略**：打開 `V1_RELEASE_CHECKLIST.md`「下一版重點工作」第一項，
   向 PM／總指揮確認優先序。
7. 地圖 VoiceOver 無障礙改造、Vary-by-Plural 顯示 bug
   （`ImportWizardView.swift`，方案見
   `../_JD2-family/F-09-PLURAL_LOCALIZATION_GUIDE.md` §3）——範圍明確的
   獨立工作，未排期。

---

## 陷阱提醒

1. 🔴 **測試崩潰視窗會彈出寫著產品名的系統對話框，不要當成新回歸驚動
   PM**——17 支 `ImportCoordinatorTests` SIGABRT 是已歸因的既有缺陷（見上）
   ，本機已誤報兩次。跑測試前心裡有數，跳出來先查是不是這批。
2. 🔴 **版號回填類 commit 看起來像雜訊，但每一筆都要驗證，不能批次假設
   「應該都只是版號」**——本輪核對 15 個 commit 時發現其中一筆（`cebeb59`）
   其實是真程式碼改動＋新增翻譯 key，如果沒有逐筆看 `git show --stat`
   會漏掉這個。
3. **`GasMix.mod()` 破壞性變更已經預告超過一週但仍未派工**——不要因為
   預告了很多次就自己先動手「幫忙做掉」，那是破壞性 public API 變更，
   家族鐵律 8 要求走回報鏈，等正式派工。
4. 🔴 **掃描式盤點會漏掉字串插值組出來的格式**（`UnitSystem.formatDepth`
   曾經漏掉一個多月，正則 `%[0-9.]*[dfg]` 掃不到 `"%.\(decimals)f %@"`）。
   任何「grep 出 N 處」的結論都要先問「有沒有一種寫法會躲掉」。
5. 🔴 **同一份文件裡同一件事可能講了不只一次**——2026-09-13 曾發生只改了
   `ARCHITECTURE.md` 一節、漏了檔頭摘要與架構圖裡同一句過時敘述。改文件
   前先 grep 同一關鍵字在整份檔案的所有出現處。
6. **效能測試的紅燈不等於回歸，但也不能因為常紅就習慣性忽略**——它是
   唯一在量匯入解析效能的東西。
7. **本地複製的 `DiveLogImportError`**（`JD2Core/Importers/DiveLogImporter.swift`）
   樣板文字必須跟 DiveImportKit 一致，沒有機制防止兩邊漂移，Kit 樣板文字
   異動時記得手動檢查這裡。
8. **ultra ↔ Logbook 的單向記錄機制是 `SYNC_TO_JD2-ULTRA.md`，僅限非
   DiveKit 問題**。DiveKit／DiveImportKit 問題一律回對應 Kit 修（憲法鐵律
   2／3），不得繞道。
9. **本 App 支援匯入 Subsurface XML/CSV** ⇒ 讀格式可以，**讀該專案原始碼
   絕對不行**（GPL/copyleft 污染風險，憲法法務紅線）。同理 libdivecomputer。
10. **對外文件（含程式碼與註解）不得提及品牌／產品名稱**；提到參考裝置
    一律用代號 Type1／Type2／Type3（2026-09-14 艦隊憲法新規），代號對照表
    只存在內部 `decisions/`，不得寫進本 repo 任何文件。
11. **`project.pbxproj` 勿手動腳本編輯**；`fileSystemSynchronizedGroups`
    會自動收納新增/刪除的 `.swift`。

---

## 開場指令建議（給下一個 session）

```bash
cd /Users/kevin/Documents/AppProject/JD2-Logbook
# 1) 本檔 + 家族層必讀（家族層 2026-09-22 版與本檔互為交叉驗證）
cat HANDOFF.md CLAUDE.md
cat ../_JD2-family/HANDOFF.md
# 2) 同步狀態（本 repo 有 remote，push 前要問 PM——目前 ahead 15）
git status --porcelain && git log --oneline origin/main..HEAD
# 3) Kit 版本對照（應為 v5.2.0 / v0.7.1）
git -C ../_JD2-family/DiveKit describe --tags
git -C ../_JD2-family/DiveImportKit describe --tags
# 4) 開場自檢 + 測試基準（預期 129/18/1，18 個既有 SIGABRT+flaky，非回歸）
bash ../_JD2-family/scripts/preflight.sh
bash ../_JD2-family/scripts/run_tests.sh logbook
```

第一件該推進的實質工作：**語系第三輪 17+2 key × 18 語言的母語審閱**（見
「進行中的決策」#1），或視 PM 指示先處理 push／關鍵字策略。
