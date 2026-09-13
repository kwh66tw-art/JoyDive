# HANDOFF — JD2-Logbook

> 交接文件（固定檔名滾動式；前一版在
> `docs/handoff-archive/HANDOFF_2026-08-16_trimix繞過解除與上架後關鍵字策略.md`）。
> ⚠️ 前一版的檔名日期取自它**最後一次被 commit 的日期**（`462efd2`，2026-08-16）；
> 該檔內文自己寫的「交接時間」是 **2026-07-30**——兩者不一致是既有文件債，
> 歸檔時刻意保留原文未改。既有 6 份歸檔的命名約定是純 `HANDOFF_<日期>.md`，
> 本次依派工指示加了主題後綴，是**刻意的風格變更**。

## 交接時間

2026-09-13（產生方式：派工指示手寫，非 `/handoff` skill；本輪**只動文件**，
零程式碼改動。同日稍晚 PM 再次指示「全盤複查所有文件登載確實」，已完成
第二輪複查與修正，見下方「✅ 文件與事實不符全盤複查」節）

---

## 目前狀態

### 上架與版本

- **v1.2 (Build 3) 已上架**（iOS + macOS，2026-07-29 通過審核）。
  `MARKETING_VERSION = 1.2`／`CURRENT_PROJECT_VERSION = 3`（實測
  `project.pbxproj`）。**下次送審的 build number 應為 4**。
- 送審相關敘述一律以 `../_JD2-family/F-08-SUBMISSION_PITFALLS.md` 為準；
  本 repo 的 `V1_RELEASE_CHECKLIST.md`／`CLAUDE.md`「下次發布流程」只當操作備忘。

### 工作區

- `git status --porcelain` **乾淨**（無未 commit 變更）。
- 本地 HEAD：`8e908e1 docs: Kit 打 tag v1.28.1／v0.7.1 ＋ 矩陣與三 App 版本回填`。
- ⚠️ **未確認是否已 push**（本輪沒跑 `git fetch`／沒比對 `origin/main`）。
  下一個 session 開場請自己跑 `git log --oneline origin/main..HEAD` 確認。
- Remote 為 `github.com/kwh66tw-art/JoyDive.git`（repo 名是 **JoyDive**，不是
  JD2-Logbook）。三 App 中本 repo 是少數有 remote 的 ⇒ **任何文件都不得寫入
  憑證**；GitHub token 存於密碼管理器，走 `credential.helper`（osxkeychain）。

### 共用層版本

- DiveKit：tag **v1.28.1**（`git describe` = `v1.28.1-1-ge8c9925`，HEAD 比 tag
  多 1 個 commit，那個 commit 就是「打 tag ＋ 矩陣回填」的 docs commit 本身）。
- DiveImportKit：tag **v0.7.1**（`git describe` = `v0.7.1-1-g6b33e2d`，同上）。
- 兩者與 `../_JD2-family/F-02-COMPAT_MATRIX.md` 第 5 行一致；本 repo `CLAUDE.md`
  寫的 v1.28.1／v0.7.1 也一致。兩個 Kit 工作區皆乾淨。
- 引用方式：SPM local path（`../../_JD2-family/DiveKit`／`DiveImportKit`），
  **本 repo 無任何演算法／解析器原始碼拷貝**。

### 本輪之前剛落地的兩批改動（2026-09-12）

**(A) 重放異常 UI 重新設計**（commit `fbc7d73`，PM 全案裁示）：

- callout 三欄（Time／Depth／Temp）在異常時**照常顯示且可拖曳**——那三欄來自
  原始剖面、與重放無關；Ceiling／No Deco 顯示「—」。
  （原本連三欄一起關掉，使「inspect any moment of the dive」在這些潛水上
  變成做不到的承諾。）
- 組織艙區塊改為說明文字 ＋ ⓘ；異常分三類，A 類用 *not available*、
  B/C 類用 *not applicable*。
- 新增 `ReplayLimitationsInfoView`（`JD2-Logbook/JD2-Logbook/Views/Logbook/`）：
  **8 種異常 ＋ 2 項一般性限制**全部羅列，並標出「本次適用」；ⓘ 入口恆常可達。
- **免責拆兩句**：「Estimated using…」隨重放存在與否顯示（沒重放時那句是假的）；
  「Not a substitute…」**恆常顯示**——那是**全 App 唯一**的免責句，且本 App
  **無總體免責頁**。同原則往下套：「Replay is simulated…」也只在有重放時顯示。
- 順帶修掉一個原本就在的靜默錯誤：選取索引原本用**未排序**的 samples 計算卻拿去
  索引 `replay.points`（Kit 內部是 `sorted().enumerated()` 且對 span<=0 `continue`）
  ⇒ 會顯示到**別的時間點**的 Ceiling／NDL，而畫面看起來完全正常。
  已改為 `orderedSamples` ＋ 以 `sampleIndex` 對應。
- 裁示全文：
  `../_JD2-family/decisions/2026-09-12_重放異常的文案細分與UI重新設計-PM裁示.md`
  🔴 **該檔取代 `V1_2_BACKLOG.md` #24 的 2026-08-23 定版**（#24 列內已自己註明
  「實作時以新檔為準，不要照本列」）。

**(B) 顯示層數字帶 `locale:`**（commit `23e9180`）：

- 🔴 **登記的債務是「6 處」，實際是 7 處**。漏掉的是
  `JD2Core/Models/UnitSystem.swift` 的 `formatDepth`（格式字串用字串插值
  `"%.\(decimals)f %@"`，先前的 `%[0-9.]*[dfg]` 正則掃不到），而它是**全 App
  最常用**的那一個。現已修（`UnitSystem.swift:87-91`，新增 `locale:` 參數，
  預設 `.current`），`formatDepthConservative`／`formatTemperature` 同批處理。
- App 內語言切換器的選擇**不在系統語言裡** ⇒ 只用 `.current` 仍抓不到，
  拿得到 `languageManager.locale` 的 View 呼叫端要傳進去。
- **三處刻意不加 `locale:`，已在原地註明理由**（下一個人不要順手改掉）：
  `DiveLogEditSheet` 寫進儲存欄位的 JSON（帶 locale 會產生逗號小數點、
  **靜默壞在資料層**）；`DiveLog.swift:287` 的 `"%02d:%02d:%02d"`（全是補零整數，
  18 語系皆用西方數字 ⇒ 無差別）；`ImportCoordinator.swift:296` 的匯入報告
  （內部診斷字串，標籤本來就是硬編碼中文）。

### 測試現況（本輪實測）

- **146 passed／1 failed／1 skipped**。跑法一律
  `bash ../_JD2-family/scripts/run_tests.sh logbook`（憲法鐵律：不手拼
  `xcodebuild test`，已有 `PreToolUse` hook 攔裸指令）。
- 🔴 **那 1 failed 是既有 flaky，不是新傷**：
  `ImportCoordinatorTests.testPerformance_SuuntoJSON_Repeated`
  （`JD2-Logbook/JD2-LogbookTests/ImportCoordinatorTests.swift:444`）是**牆鐘**
  `< 100ms/parse` 斷言，完整套件裡與 **UI 測試 clone 並行**被搶 CPU 就紅；
  **單獨跑該類別 40／0／0 通過**；`git stash` 拿掉 2026-09-12 的改動後
  **同一支照樣 FAIL**。
  **刻意不改門檻**——改門檻是掩蓋訊號；正解是**改量 CPU 時間**，或**把效能測試
  移出閘門套件**。（對照：commit `23e9180` 訊息裡記的是 147 passed／0 failed，
  同一套測試同一份程式碼——這正是 flaky 的證據，不要把 146 當成回歸。）
- 那 1 skipped 是 `PurchasePriceDisplayTests.swift:61` 的
  `XCTSkipUnless(pm.premiumProduct == nil, …)`——**商品有載入到才跳過**，
  換機器／換環境可能變 0 skipped。**回報 skipped 數字時必須註明這個條件**，
  否則下一個人會把 0 或 1 的變化誤判為測試消失。

---

## 進行中的決策（尚未定案）

1. 🔴 **17 個新 key × 18 語言待母語審閱**（重放限制說明）。其中 **2 句**
   （「Estimated using…」「Not a substitute…」）是從既有**已審核**的合併句
   機械切開，**不需重審**；**15 句為新撰**，術語已對 F-10
   `tissue loading` 各語標準詞。已登記 `V1_2_BACKLOG.md` #6「第三輪」。
   ⇒ **這是本 repo 目前唯一明確的阻塞項**（阻塞下一次送審的文案定稿）。
2. `V1_2_BACKLOG.md` #21（第二輪 AI 稽核報告）尚有「記錄待決」項目；#3 剖面圖
   警示標記／狀態列第二列已建置但**先隱藏**，開放時機未定。
3. `V1_2_BACKLOG.md` #26（匯入自動帶入 dive mode）標註「待家族層，**不在本 repo
   範圍**」——要動就走家族回報鏈（憲法鐵律 8），不要在本 repo 自行決定。
4. App Store 關鍵字策略重新設計（2026-07-29 上架後發現非品牌詞搜尋找不到本產品）
   仍未執行，記在 `V1_RELEASE_CHECKLIST.md`「下一版重點工作」第一項。
   **已擱置約七週，需向 PM／總指揮確認是否仍是首要任務**。
5. 🆕（2026-09-13 查證發現）**`.xcarchive` 清理待決**：`V1_2_BACKLOG.md` #10
   的清理觸發條件（v1.2 送審過關）早已滿足，但清理動作未執行；`ls` 實測
   `~/Library/Developer/Xcode/Archives/2026-06-17/` 下實際是 **3 個**
   `.xcarchive`（原記錄只提到 2 個，多出的 `11.03` 那份來源未查）。刪除為
   不可逆操作，**下一次開工需 PM 決定**：(a) 3 個都清、(b) 只清原記錄的 2 個、
   (c) 先查證第 3 份來源再決定。
6. 🆕（2026-09-13）文件全盤複查已完成，`CLAUDE.md`／`ARCHITECTURE.md`／
   `V1_2_BACKLOG.md` 的既有文件債已修正（見上方「✅ 文件與事實不符全盤複查」節）。
   **下一次開工不需要重複這輪複查**，除非又有新的架構/狀態變動未同步。

---

## 下一步（具體到「打開哪個檔、跑哪條指令」）

1. **確認同步狀態**：
   `git -C /Users/kevin/Documents/AppProject/JD2-Logbook log --oneline origin/main..HEAD`
   ——若非空，先問 PM 要不要 push（本 repo 有 remote，push 是對外動作）。
2. **開場自檢**：`bash ../_JD2-family/scripts/preflight.sh`，再讀
   `../_JD2-family/HANDOFF.md`（家族層）確認沒有跨 repo 待辦落在 Logbook 頭上。
3. **測試基準重跑一次**：`bash ../_JD2-family/scripts/run_tests.sh logbook`。
   預期 **146/1/1**（或 147/0/1，看那支 flaky 當下有沒有被搶 CPU）。
   **只要 failed 只有 `testPerformance_SuuntoJSON_Repeated` 就不是回歸。**
4. **處理那支 flaky（若 PM 同意排入）**：打開
   `JD2-Logbook/JD2-LogbookTests/ImportCoordinatorTests.swift:444`，二選一——
   (a) 把牆鐘改量 CPU 時間；(b) 把三支 `testPerformance_*`（:433／:460／:489）
   移出閘門套件。**不要改門檻數字**。
5. **語系第三輪**：`bash ../_JD2-family/scripts/check_localization.sh JD2-Logbook`
   先確認使用鍵皆存在，再產 CSV 交母語審閱；流程見
   `docs/LOCALIZATION_GUIDE.md`，術語一律先查
   `../_JD2-family/dive-terminology-glossary.json`（憲法鐵律 1／F-10：
   **任何 App 新增/修改 UI 翻譯文字前必查**）。
6. **關鍵字策略**：打開 `V1_RELEASE_CHECKLIST.md`「下一版重點工作」第一項，
   先向 PM／總指揮確認是否仍是首要任務（已擱置約六週）。
7. 地圖 VoiceOver 無障礙改造、Vary-by-Plural 顯示 bug
   （`ImportWizardView.swift`，方案見
   `../_JD2-family/F-09-PLURAL_LOCALIZATION_GUIDE.md` §3）——皆為範圍明確的
   獨立工作，未排期。
8. 🆕 **`.xcarchive` 清理決策**：向 PM 確認 `~/Library/Developer/Xcode/Archives/
   2026-06-17/` 下 3 個 `.xcarchive`（含來源未查證的 `11.03` 那份）如何處理，
   決定後才刪除（刪除不可逆，見上方「進行中的決策」#5）。

---

## 陷阱提醒

1. 🔴 **掃描式盤點會漏掉字串插值組出來的格式**。`UnitSystem.formatDepth` 用
   `"%.\(decimals)f %@"`，正則 `%[0-9.]*[dfg]` 完全掃不到，於是「6 處」這個
   登記數字錯了一個多月，而漏掉的那個是全 App 最常用的。**任何「用 grep/正則
   盤點出 N 處」的結論，都要先問「有沒有一種寫法會讓它躲掉」。**
2. 🔴 **行為 grep 對跨行呼叫會給假結果**。本輪用
   `grep "String(format:" | grep -v "locale:"` 時，多處 VoiceOver
   `accessibilityLabel`（`DiveLogEditSheet.swift:584`／`:627`、`SettingsView`、
   `DiveCalendarView`）被列為「缺 locale」——**實際上有**，`locale:` 在下一行。
   逐行 grep ⇒ 假陽性；反過來也會假陰性。宣稱「N 處缺 X」前要開檔案看。
3. 🔴 **效能測試的紅燈不等於回歸**。見上方測試段落。反向也成立：
   **不要因為它常紅就把它從失敗清單裡「習慣性忽略」**——它是唯一在量匯入解析
   效能的東西。
4. **`XCTSkipUnless(premiumProduct == nil)` 型的 skip 是環境相依的**：
   skipped 數字在不同機器上會變，回報時必須附條件。
5. **本地複製的 `DiveLogImportError`**（`JD2Core/Importers/DiveLogImporter.swift`）
   樣板文字必須跟 DiveImportKit 一致，**沒有機制防止兩邊漂移**
   （2026-07-25 已發生過一次，見 `SYNC_TO_JD2-ULTRA.md` #8）。Kit 樣板文字
   異動時記得手動檢查這裡。
6. **ultra ↔ Logbook 的單向記錄機制是 `SYNC_TO_JD2-ULTRA.md`，僅限非 DiveKit
   問題**。DiveKit／DiveImportKit 的問題一律回對應 Kit 修（憲法鐵律 2／3），
   不得在本 repo 繞道，也不得兩邊各改。
7. **本 App 支援匯入 Subsurface XML/CSV** ⇒ 讀**格式**可以，
   **讀該專案原始碼絕對不行**（GPL/copyleft 污染風險，憲法法務紅線）。
   同理 libdivecomputer。需要對照時只能當黑盒（餵輸入、讀輸出、比對數字）。
8. **對外文件（含程式碼與註解）不得提及品牌／產品名稱**；真實出處記在
   `../_JD2-family/decisions/`、F 系列。**不得以「XX 規範」「業界慣例」冠名而
   不附可查證出處**——家族剛把全艦隊未附出處冠名清到 0（commit `6d60362`／
   `1ba0719`，274 → 0），不要重新引入。有 `check_citations.sh` 在守。
9. **`project.pbxproj` 勿手動腳本編輯**；`fileSystemSynchronizedGroups` 會自動
   收納新增/刪除的 `.swift`。

---

## ✅ 「文件與事實不符」全盤複查與修正（2026-09-13，PM 指示執行）

PM 指示「先 review 所有文件登載確實、反應最新狀態」後，以下已**實際修正**
（不再只是回報），修正方式一律是**補註記＋更正內容**，不是靜默改掉重寫：

### 本 repo `CLAUDE.md`（已修正）

| 位置 | 原寫法 | 已修正為 |
|------|----------|------|
| 「現況速覽 → 狀態」 | 「v1.0 已提審…2026-07-14 啟動 v1.1 開發，2026-07-17 完工 13/14 項」 | **v1.2 (Build 3) 已上架**（2026-07-29），落後兩個里程碑的敘述已更新，v1.1/v1.0 歷史保留在對應小節 |
| 「現況速覽 → 目標上線」 | 「2026 年 8 月 18 日」 | 改為「已上架，不再適用；下一版時程未定」 |
| 「下次發布流程」#2 | 「`CURRENT_PROJECT_VERSION` +1（下次應改為 3）」 | 改為「下次應改為 **4**」（實測目前為 3，Build 3 已上架，照原文照做會撞號） |
| 「Xcode 專案位置」 | `JD2-Logbook/JD2-Logbook/JD2-Logbook.xcodeproj` | 改為 `JD2-Logbook/JD2-Logbook.xcodeproj`（`find` 實測僅此一個 `.xcodeproj`） |

（Kit 版本 v1.28.1／v0.7.1 與 F5/F6 敘述皆與事實相符，未動。）

### `ARCHITECTURE.md`（新發現，已修正——不在總指揮原始回報的四項內）

- 「JD2Core/Algorithm」節原寫「現在僅存 `DiveReplayEngine.swift`」，與
  `CLAUDE.md` 早於 2026-09-02 就修正過的事實矛盾：該檔已於 DiveKit v1.9.0
  （2026-08-22）上收為 Kit 內 `DiveReplay.swift` 後刪除，本 repo
  `JD2Core/Algorithm/` 現在只剩 `DiveReplayInput.swift`（`ls` 實測確認）。
  `CLAUDE.md` 改對了但 `ARCHITECTURE.md` 沒同步跟上，這次一併修正。
  **教訓同 HANDOFF 陷阱提醒 #1**：家族層/單一文件改對了不代表全部文件都同步，
  同一事實在多份文件出現時要逐一 grep 確認，不能只信任「應該已經改過」。

### `V1_2_BACKLOG.md`（已修正）

- 檔頭導言「目前僅剩 #6 最後一輪 rev05…」已更新為反映現況（#6 現為第三輪，
  17 key × 18 語言待母語審閱，是本檔唯一明確阻塞項）。
- #1 標題「iOS 版送審被拒絕，擬訂下次送審對策」與狀態 ✅ 不一致，標題已加註
  更正說明（v1.2 已上架，非仍在 Waiting for Review）。
- #10「2 個 `.xcarchive` 待送審過關再清」：**已查證**送審觸發條件早已滿足
  （2026-07-29 上架）但清理動作未執行；`ls` 實測
  `~/Library/Developer/Xcode/Archives/2026-06-17/` 底下實際是**3 個**
  `.xcarchive`（比原記錄多一份 `11.03` 那份，來源未查證）。**刪除是不可逆
  操作，本輪僅查證更新記錄，未動手刪除**——是否清除、如何處理多出的第 3 份，
  留給下一次開工時 PM 決定（見下方「下一步」）。
- #6、#24 經核對**與實際相符**，未動。

### 前一版 HANDOFF（已歸檔，維持不動）

- 內文「交接時間 2026-07-30」vs 最後 commit 日 2026-08-16 不一致、
  「DiveKit v1.7.0」已過時 20 個版本——**歸檔文件是歷史快照，刻意保留原文
  不回頭改**，此處僅重申原則，不算未辦事項。

---

## 開場指令建議（給下一個 session）

```bash
cd /Users/kevin/Documents/AppProject/JD2-Logbook
# 1) 本檔 + 家族層必讀
cat HANDOFF.md CLAUDE.md
cat ../_JD2-family/HANDOFF.md
# 2) 同步狀態（本 repo 有 remote，push 前要問）
git status --porcelain && git log --oneline origin/main..HEAD
# 3) Kit 版本對照（應為 v1.28.1 / v0.7.1）
git -C ../_JD2-family/DiveKit describe --tags
git -C ../_JD2-family/DiveImportKit describe --tags
grep -n "v1.28.1" ../_JD2-family/F-02-COMPAT_MATRIX.md | head -3
# 4) 開場自檢 + 測試基準（預期 146/1/1 或 147/0/1）
bash ../_JD2-family/scripts/preflight.sh
bash ../_JD2-family/scripts/run_tests.sh logbook
```

接手後**不需要**重新驗證 2026-09-12 兩批改動本身（build 已 SUCCEEDED、
`check_localization.sh` 已通過、測試基準已記錄在上），除非有新程式碼觸及
`DiveAnalysisView`／`ReplayLimitationsInfoView`／`UnitSystem`。
第一件該推進的實質工作是**語系第三輪 17 key × 18 語言的母語審閱**。
