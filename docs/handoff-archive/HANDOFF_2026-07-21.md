# HANDOFF — JD2-Logbook

> 交接文件（固定檔名滾動式；前一版在 docs/handoff-archive/HANDOFF_2026-07-19.md）。

## 交接時間

2026-07-21（產生方式：/handoff skill）

## 目前狀態

- **所在里程碑**：v1.1 已完工（13/14，#9/#10 Widget PM 確認終止規劃）。目前在
  v1.1 之後的下一輪工作（`V1_2_BACKLOG.md`，本 session 建立，尚無正式里程碑編號）。
- **branch**＝`main`，**HEAD**＝`4af9f48`（"feat: dive profile warning markers/row
  + fix Import tab localization"）。**本地領先 `origin/main` 4 個 commit**
  （`aef0d34`／`5628a07`／`35df2ba`／`4af9f48`），**使用者尚未決定要不要 push**
  ——下次 session 若要繼續，先問使用者是否已經決定，不要假設。
- **未 commit 變更**：僅本次 /handoff 執行的檔案搬移（`HANDOFF.md` →
  `docs/handoff-archive/HANDOFF_2026-07-19.md`，本檔重新產生於根目錄），尚未
  commit（依 skill 紅線不擅自 commit，需使用者確認）。
- **共用層版本**：DiveKit 本地 HEAD `v1.4.0-2-gef469ca`（領先 tag 兩個小 commit，
  非功能性差異，與 `F-02-COMPAT_MATRIX.md` 記載的 v1.4.0 一致）；DiveImportKit
  `v0.4.0-2-g325c7c6`，同樣與 COMPAT_MATRIX 一致。
  `bash _JD2-family/scripts/check_family_drift.sh` 本次執行有 **2 個 ❌**，但
  查證後確認是**腳本本身的假警報**，非真實 drift——見下方「陷阱提醒」。

## 進行中的決策（尚未定案）

- 無重大技術決策懸而未決。以下是「已知下一步、但時機由使用者決定」的事項，不算
  待決策：push 這 4 個 commit、iOS 送審駁回的 ASC 端修改（見下）、Game Center
  誤設定的細節釐清。

## 下一步（按順序，具體到可直接執行）

1. **push 待決**：確認使用者是否要 push 本地領先的 4 個 commit 到 `origin/main`。
2. **iOS 送審駁回（`V1_2_BACKLOG.md` #1）**：程式碼/文件端已完成
   （`logbook/privacy.md` 三語修正 IDFA/ATT 敘述）。**卡在使用者本人**要去
   App Store Connect 做兩件事：① Age Rating 勾選 Advertising=Yes；②
   App Privacy 問卷重新填寫，Location/Device ID/Usage Data 取消「used to
   track」。使用者明確要求：**這兩件事到了送審那一刻要主動提醒**，且**整個
   駁回事件落幕後**（重新送審通過或有新結果）要把「原因/分析/對策/行動/
   lessons learned」整理進 `docs/reports/`（比照 `R-2026-07-17-audit_report.md`
   的先例），目前都還沒做，等事件真正結束再處理。
3. **`DiveAnalysisView.swift` 的警示列文案沒有走 App 內語言切換器**——本 session
   剛修完 `ImportWizardView.swift` 同一類型的坑，結果在同一個 session 稍後新寫的
   警示事件文案（`warningTitle`/`warningDetail`，L261/262/269/271）又用了
   `String(localized:)`（只認系統語言），而且這個 View **目前完全沒有**
   `@Environment(AppLanguageManager.self)`。下次要修：① 加上
   `@Environment(AppLanguageManager.self) private var languageManager`；②
   4 處 `String(localized:)` 換成 `languageManager.localized(_:)`。**修完後建議
   順手全專案 `grep -rn "String(localized:" --include="*.swift"` 抓一次，確認
   沒有其他遺漏**（目前只抓了 `ImportWizardView.swift` 一個檔案，不保證是唯一
   受影響的畫面）。
4. `V1_2_BACKLOG.md` 剩餘項目：#2（icon 全盤 review，未開始）、#4（公制/英制
   單位——目前只有 Settings 選項本身生效，全 App 顯示/輸入欄位套用是後續較大
   範圍工作）、#5（匯入情境測試，未開始）、#6（語系全審核，未開始）。
5. `V1_2_BACKLOG.md` #1b（macOS「開啟 Game Center」誤設定）：細節待使用者釐清，
   使用者明確表示「到時候」（送審前）再處理，不用主動跟進。

## 陷阱提醒

- **`check_family_drift.sh` 對 JD2-Logbook 的 DiveKit/DiveImportKit local
  package 引用檢查目前是假警報**：腳本用
  `grep -q "relativePath = ../../_JD2-family/DiveKit;"`（無引號）比對
  `project.pbxproj`，但 Xcode 實際序列化成
  `relativePath = "../../_JD2-family/DiveKit";`（有雙引號），pattern 吃不到、
  一律回報 ❌。**已用 `grep -n "relativePath.*DiveKit" project.pbxproj` 直接
  核對過，引用本身完全正確**（確實指向 `../../_JD2-family/DiveKit` 與
  `../../_JD2-family/DiveImportKit`，本 session 也已成功建置驗證）。這是家族層
  共用腳本的問題，不屬於本 repo 範圍，依家族鐵律第 8 條回報鏈原則**已在此記錄，
  不擅自修改 `_JD2-family/scripts/`**——若總指揮 session 要修，pattern 需要同時
  接受有無引號兩種寫法。
- **`String(localized:)` vs `languageManager.localized(_:)` 是本專案最容易
  重複踩的坑**：`\.locale` environment 只有 SwiftUI 原生的
  `Text(LocalizedStringKey)` 才會自動吃到 App 內語言切換器；任何用
  `String(localized:)` 組出來的純字串（不管後面包不包 `Text()`）一律只認系統
  語言。已知修過的地方：`navigationTitle`/`tabItem`（v1.1 #8）、
  `ImportWizardView.swift`（本 session）；已知還沒修的地方：
  `DiveAnalysisView.swift` 警示列（見上方「下一步」#3，本 session 新寫的功能
  裡就中鏢，說明這個坑很容易在寫新畫面時無意識踩到，不是修一次就一勞永逸）。
- Repo 根目錄整理（本 session 稍早完成）移除了 9 個確認空白的孤兒目錄、把
  `Sources/`／`Tests/` 兩個孤兒資料夾原封不動移進
  `Archive/stray_root_folders/`——若之後又在根目錄看到陌生的空資料夾，先用
  `find . -type d -empty` 確認真的是空的、且不在 `.xcodeproj` 內部
  （`.xcodeproj` 底下的空資料夾如 `xcshareddata/swiftpm/configuration` 是
  Xcode 自己管的，不要動）。

## 開場指令建議（給下一個 session）

先讀本檔，若要處理跨專案／家族層議題再讀 `_JD2-family/F-00-文件登錄表.md`。
驗證環境跑 iOS+macOS `xcodebuild build` 與
`xcodebuild test -only-testing:JD2-LogbookTests`（預期全綠，306+ 案例）。若要
處理 iOS 送審後續，先問使用者 ASC 端兩項修改是否已完成。若要修
`DiveAnalysisView.swift` 的語言切換坑，先讀 `AppLanguageManager.swift` 的
`localized(_:)` 用法說明（檔頭註解已完整記錄四段式解法）。
