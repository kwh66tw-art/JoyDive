# HANDOFF — JD2-Logbook

> 交接文件（固定檔名滾動式；前一版在 docs/handoff-archive/HANDOFF_2026-07-21.md）。

## 交接時間

2026-07-26（產生方式：/handoff skill，2026-07-26 補記完工狀態）

## 目前狀態

- 所在里程碑：v1.2 語系全審核**已收尾**（`V1_2_BACKLOG.md` #6/#16 皆已完成）。
- 未 commit 變更：`Localizable.xcstrings` 有 27 個儲存格的翻譯修正（見下方「本輪完成
  的工作」），**尚未 commit**，等使用者確認後再 commit。另有以下**刻意保留為未追蹤**
  的工作檔案（CSV/xlsx 校閱素材，非原始碼，慣例不進 git）：
  - `JD2-Logbook_i18n_Completed_0725_rev02.csv`
  - `JD2-Logbook_v1.2新增key_0725-revised01.csv`
  - `JD2-Logbook_語系全審核-0725.csv`
  - `JD2-Logbook_語系全審核_260筆_0725_v2-rev05.csv`
  - `語系修正建議彙整.xlsx`
  - `Translation_Review_Report.md`（已讀取並處理完畢，工作用途結束，是否移出根目錄
    留給使用者決定）
  - `.DS_Store`（一律忽略）
  - HEAD：分支 `main`，領先 `origin/main` 18 個 commit（尚未 push；未收到 push 指示）
- 共用層版本（家族專案）：DiveKit `v1.4.0`／DiveImportKit `v0.4.1`，皆與
  `_JD2-family/F-02-COMPAT_MATRIX.md` 登記一致，`check_family_drift.sh` 全數通過
  （`═══ 通過：家族合流狀態健康 ═══`），無 drift。

## 本輪完成的工作（2026-07-26）

`V1_2_BACKLOG.md` #16 遺留的 3 項使用者裁定＋`Translation_Review_Report.md` 的建議，
已全數套用到 `Localizable.xcstrings`（第一批 18 個儲存格），iOS + macOS build 皆已
驗證通過：

1. **"Min NDL"**（zh-Hant/zh-Hans）→「最短 NDL」
2. **Trimix 說明文字精簡**（zh-Hant/zh-Hans）→ 移除冗餘「混合氣體/混合气体」；已核對
   ja/ko/th/vi 同句翻譯本來就沒有這個冗詞問題，不需比照修改
3. **"Visibility"**（id/ms）→「Jarak pandang」／「Jarak penglihatan」
4. 連帶採用報告另外提出的 6 項 id/ms 建議：Weight／Ascent Rate Alert／Wetsuit（皆已用
   App 內既有字串驗證內部一致性）、Ceiling／Cylinder Material／Cylinder Size（信任
   報告專業判斷，App 內無既有字串可交叉驗證，屬較低信心度套用）

**使用者接著主動問「要不要再審一次」，做了第二輪自我複查**（不是重新過一遍全部 260
key，而是針對這次改的每個詞，programmatically grep 全檔案找有沒有同義但沒改到的姊妹
key），**抓到 3 個真的漏改的地方**（再套用 9 個儲存格，累計 27 個）：
- `Max Ceiling`（id/ms）：跟 `Ceiling` 一樣的 false friend 問題沒有連帶修 → 已修
- `Ascent rate exceeded...`（僅 id）：跟 `Ascent Rate Alert` 一樣的「Ascent 原文混雜」
  問題沒有連帶修 → 已修
- `Visibility: %.1f metres`／`Visibility: %@`／`Visibility: Not recorded`（id/ms，
  6 格）：跟裸 key `Visibility` 一樣用「Visibilitas」，完全沒被檢查到 → 已修，格式
  參數（`%.1f m`／`%@`）位置與數量已驗證與 en 版一致

修完再次全檔案掃描（殘留舊詞 + 格式參數一致性），確認乾淨；iOS + macOS build 再次
皆通過。詳細裁定理由與逐項驗證紀錄見 `V1_2_BACKLOG.md` #16「翻譯疑慮裁定紀錄」章節
（含 2026-07-26 事後複查段落）。

## 進行中的決策（尚未定案）

無阻塞決策。唯一提醒：Ceiling／Cylinder Material／Cylinder Size 這 3 個 id/ms key
若日後有印尼文/馬來文母語潛水員可覆核，值得優先看一下（信心度低於其他項目，理由見
上方）。

## 下一步（按順序，具體到可直接執行）

1. 跟使用者確認本輪 18 個儲存格的翻譯修正是否要 commit（`Localizable.xcstrings`）。
2. 確認 `V1_2_BACKLOG.md` #6（語系全審核）是否已無其他待審內容；若使用者沒有新一輪
   CSV 要處理，可將 #6 狀態改為 ✅ 完成。
3. `_JD2-family/reports/R-2026-07-25-多語系Vary_by_Plural規則需求.md` 的家族層 plural
   規則工作仍卡在「等使用者通知 Logbook 已送審」的觸發條件，尚未開始，不要自行判斷
   時機提前動手。
4. `V1_RELEASE_CHECKLIST.md`「本地化」章節目前仍全數未勾選（繁中/英文/簡中/日文/
   韓文/歐語/東南亞語言抽樣驗證），這輪語系審核完工後可考慮請使用者實機抽樣驗證後
   勾選。
5. `V1_2_BACKLOG.md` #1 標記「ASC 後台動作已完成，待送出審核」——語系工作已不再是
   送審前的阻塞項，下一步重點可轉回送審準備本身（Archive／App Store Connect 上傳）。

## 陷阱提醒

- **CSV/xlsx 資料損毀（本 session 踩到兩次，務必留意）**：上游工具把逗號分隔資料轉
  成欄位時若沒處理儲存格內文字本身含逗號（例如德文/越南文的小數逗號「32,8」，或
  `%1$@, %2$@` 這類格式字串），會把內容從中間截斷或漏到相鄰欄位，且**不會報錯、看起來
  像正常資料**。這在一份 AI 審核者的 xlsx（`修正建議彙整.xlsx` 的 ppl 分頁）發生過，
  **也在被視為「已審核定案」的主要來源 `_260筆_0725_v2-rev05.csv` 本身發生過**（3 處
  英文格式字串損毀 + 3 句長句截斷 + 1 格編輯備註被誤存成翻譯值）。**教訓：任何要直接
  套用進 `.xcstrings` 的 CSV，套用後務必跑格式參數一致性 + 截斷偵測的自動化驗證，不能
  只信任「已審閱」的標籤。**
- **不要在低信心語言上自由發揮**：曾在套用一則審核建議時，額外多改了一個沒被要求的
  克羅埃西亞文文法修正（加代名詞「ih」），事後自己抓到並改回最小化、逐字對應建議的
  版本。低信心語言（th/vi/hr/el/ms/id 等）只做被明確驗證/要求的修改，不要自行「順手
  優化」。
- **審核者引用的佐證要自己查證，不能照單全收**：一位審核者宣稱「印尼文/馬來文的
  Visibility 其他地方已經這樣翻」作為建議理由，實際 grep 全檔案後證實該用法根本不
  存在——這類「因為 X 已經這樣做」的理由，套用前務必自己 grep 驗證，不要因為理由聽
  起來合理就直接採信。
- 套用翻譯修正時，改動前先讀出當前值當作 `expected_old`，寫回腳本裡逐一斷言比對，
  不符就直接中止——這次 27 個儲存格全數一次比對成功，是避免誤改到別的語言/別的 key
  的有效做法，值得延續。
- **改術語時只改報告/建議明確點名的 key 是不夠的**：這輪 18 個儲存格套用完後，
  programmatically grep 同一詞在全檔案的其他出現位置，抓到 3 個真正漏改的姊妹 key
  （`Max Ceiling` 沒跟著 `Ceiling` 一起修、`Ascent rate exceeded...` 內文沒跟著
  `Ascent Rate Alert` 標題一起修、`Visibility: %@` 等 3 個帶格式參數的姊妹 key 沒跟
  著裸 key `Visibility` 一起修）。**每次改一個術語的翻法，套用後務必額外跑一次「這個
  詞還出現在哪裡」的全檔案掃描，不能只信任建議清單/報告點名的 key 範圍是完整的。**
- `V1_2_BACKLOG.md`／`V1_RELEASE_CHECKLIST.md`／`docs/KNOWN_ISSUES.md` 三份文件的
  「最後更新」已改指向 `git log -- <file>`，不再手動維護日期戳——若之後又看到手動寫
  死的日期，代表退化了，改回 git log 寫法即可。

## 開場指令建議（給下一個 session）

先讀本檔，確認 `Localizable.xcstrings` 的 18 個儲存格修正是否已 commit（`git status`／
`git log -1 -- Localizable.xcstrings`），再依「下一步」接續。不需要重新驗證環境（本次
交接已確認 build 狀態與家族層同步皆無異常，見上方「共用層版本」）。
