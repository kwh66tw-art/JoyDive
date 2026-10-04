# App-lb v1.3(4) 工作計劃——修錯與功能增修（2026-10-04 晚，待 PM 核准）

> PM 10/04：v1.3 由總指揮直接更新；先列計劃，PM 看過沒問題再開工；**翻譯最後做**。
> 來源：App-lb session（JD2-lb_CC01）整理的 18 項＋本 repo `V1_2_BACKLOG.md`／`HANDOFF.md`／`docs/KNOWN_ISSUES.md`／`docs/SUBMISSION_CHECK_NEXT.md`，逐項以指令查證。
> 基準：HEAD `b893a9c`；DiveKit v9.2.0／DiveImportKit v0.7.1 **凍結**（只修 bug）；`run_tests.sh logbook` **147/0/1**（v9.2.0）。
> 可寫入範圍：只限 `JD2-Logbook`；不動兩個 Kit（凍結）、不動其他 App、不 push（對外動作，PM 決定）。

## 〇、PM 早上要看的決定（共 7 個，其餘照建議做）

| # | 決定 | 我的建議 |
|---|---|---|
| D1 | P0-1 升級測試需要操作**模擬器畫面**（範圍紀律：先徵得同意） | 同意（只操作模擬器內的 App-lb） |
| D2 | P0-1 若升級失敗時的行為：現在是 `fatalError`（每次開 App 都閃退） | 改成「顯示錯誤畫面、**絕不刪除資料檔**」，不論升級測試結果都做 |
| D3 | 文案開頭「到進階技術潛水」三語定位句 | 改成不暗示技術潛水分析的說法（例：「從第一次下水到每一次進階潛水」） |
| D4 | P2 功能類哪些納入 v1.3（警示標記、備份、地圖 VoiceOver、icon） | **都不納入**，v1.3 聚焦正確性與揭露 |
| D5 | 不穩定效能測試：改量 CPU 時間，或移出閘門 | 改量 CPU 時間（保留覆蓋） |
| D6 | GDPR／UMP 同意流程（歐洲區廣告） | 先查證 Google 政策對非個人化廣告的要求，查完再報；本版不寫程式 |
| D7 | ATS（`NSAllowsArbitraryLoads`）保留或移除 | 先查 AdMob 官方需求再決定；查不到就保留（v1.2 已過審） |

## 一、P0：必做（安全、資料、送審阻擋）

### P0-1 v1.2 → v1.3 升級不丟資料、不閃退 🔴
- **事實**：v1.2 之後持久化模型改了兩處——`waterTemperature` 由必填改選填、新增 `diveMode`（有預設值）（`git diff 05852a8 HEAD -- JD2Core/Models/`）。
  SwiftData 通常會自動遷移這兩種變更，但**沒有實測過**；而開資料庫失敗時 `DiveLogDatabase.swift:56` 直接 `fatalError` ⇒ 升級失敗的使用者**每次開 App 都閃退**。
- **做法**：用 `git worktree` 簽出 v1.2（`05852a8`）建置到模擬器 → 建立數筆紀錄（含水溫、無水溫、各氣體）→ 不刪 App、直接裝 HEAD 版 → 確認筆數與欄位完整、新欄位為預設值。
- **D2**：開資料庫失敗改為顯示錯誤畫面＋保留資料檔（不建新庫、不刪檔），附回歸測試（以故意壞掉的設定觸發）。
- **驗證**：升級前後截圖＋筆數；新增測試；故障注入。

### P0-2 減壓分析「有限支援」揭露——UI 與文案（PM 10/04 裁示）
- **事實**：重放的前置判斷只要鏈中有 **trimix** 就整條拒算（DiveKit `DiveReplay.swift:591`），trimix 已於 9/15 裁定為產品範圍外。現有說法不準：
  - ⓘ 頁 `ReplayLimitationsInfoView.swift:48`：只說「多氣體與循環呼吸器不支援」——**單一氣體 trimix 也不支援**。
  - 文案英文 `APPSTORE_COPY.md:37`「technical (multi-gas) dives」同樣漏掉單一氣體 trimix；**繁中 :165、日文 :267 完全沒有這句但書**，兩者的標題也沒有「（有限支援）」。
- **做法**：
  1. ⓘ 頁技術潛水條目改為涵蓋 trimix、多氣體、循環呼吸器。
  2. ⓘ 頁「Always applies」加一條**支援範圍**：組織負荷與 NDL 只支援單一氣體的空氣／高氧潛水。
  3. 文案三語：英文改正括號；繁中／日文補但書句與標題「（有限支援）／（限定サポート）」；D3 定位句。
  4. 用詞先對 F-10 術語表（`dive-terminology-glossary.json`）。
- 新增 UI 字串只寫英／en-GB／繁中／日，**其餘語言進翻譯階段**。
- **驗證**：模擬器開一筆 trimix 紀錄截圖（異常說明＋ⓘ頁）；文案 diff。

### P0-3 匯入精靈關閉不再閃退（`181e441` 實地驗證）
- 模擬器：用專案測試資料匯入一個檔案 → 關閉精靈 → 重複數次，確認不閃退。截圖存證。

### P0-4 What's New 係數改正措辭
- 三語草稿已在 `APPSTORE_COPY.md`；PM 定稿（文件，不寫程式）。

## 二、P1：建議納入（低風險修錯，不需 PM 判斷）

| # | 項目 | 做法 | 驗證 |
|---|---|---|---|
| P1-1 | 定位權限說明只有英文（稽核 R-06） | 新增 `InfoPlist.xcstrings`，放 `NSLocationWhenInUseUsageDescription`；英／繁中／日先寫，其餘進翻譯階段 | 產物 `defaults read`＋切語言截圖 |
| P1-2 | 死碼 `getStatistics()`（稽核 R-04，平均深度算法錯誤但無人呼叫） | 先 `callers.sh` 重確認 0 呼叫端，再移除 | 建置＋測試 |
| P1-3 | 不穩定效能測試（`ImportCoordinatorTests.swift:444`） | 依 D5；**不改門檻數字** | 測試連跑 3 次 |
| P1-4 | `Task.detached` 的 Swift 6 並行警告 | 讀碼確認隔離後修；無法安全修就保留並註明 | 建置警告數 |
| P1-5 | Catalog 孤兒鍵 96 個（含舊 "Mandatory Safety Stop"）、缺 'Developer Tools' 鍵 | 逐鍵 `grep` 確認無引用才刪；補缺鍵 | `check_localization.sh` |

## 三、P2：功能類，建議**不**納入 v1.3（D4）

| # | 項目 | 不納入的理由 |
|---|---|---|
| 剖面圖警示標記／狀態列第二列（`DiveAnalysisView.swift:31`） | 8/13 PM 裁示「之後改版再決定怎麼呈現」，呈現方式未定 |
| 備份匯出入（`SettingsView.swift:24`） | 須先修三語單複數＋完整測試；非本版目標 |
| 地圖 VoiceOver 改造 | 中等工作量，非送審阻擋 |
| icon 全盤 review | 設計工作 |
| SwiftData 正式遷移計畫（稽核 R-07） | 先看 P0-1 結果；現在才補 `VersionedSchema` 本身有風險，留到下一次改資料模型時一起做 |
| 匯入自動帶入潛水模式（#26） | PM 10/04：等 App-u 日誌格式定案 |
| `GasMix.mod()` 移除預設參數 | Kit 凍結，排到 v1.3 之後 |

## 四、翻譯階段（最後做）

ⓘ 免責句 14 語、重放限制說明 17＋2 個 key、本計劃新增的有限支援字串、定位權限說明；希臘文／克羅埃西亞文 No Deco 用詞母語審（#23）。翻法（機器翻譯標註 or 維持英文）**屆時 PM 決定**。

## 五、送審收尾

隱私理由碼 `CA92.1` 對官方頁再核、隱私問卷一致性、CHANGELOG 補本計劃內容、`SUBMISSION_CHECK_NEXT.md` 逐項更新、`run_tests.sh logbook`；push 與上傳由 PM。

## 六、順序與回報

P0-1 → P0-2 → P0-3 → P1-1～P1-5 → 翻譯 → 送審收尾。每項完成即提交（`git log` 可追），回報一律用逐項表格（狀態＋驗證方式），沒有證據的不寫「完成」。
