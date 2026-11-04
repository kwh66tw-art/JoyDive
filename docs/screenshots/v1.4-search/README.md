# v1.4 搜尋收合成按鈕（PM 2026-11-04；B 案）截圖

- 資料：iOS `JD2-LB-Audit`（iPhone 17 Pro，iOS 26.2，105 筆）、`JD2-LB-B1-SE`（iPhone SE 3）；macOS audit 版（`com.jd2logbook.JD2-Logbook.audit`，104 筆）。App 內語言：iOS 日文、macOS 繁中。
- ⚠️ **03、04、07、13（iOS「輸入中／有結果」）的搜尋字「DA」是用暫時的 DEBUG 啟動參數預填**：模擬器的貼上與鍵盤按鍵點擊都打不進欄位（HANDOFF 陷阱）。預填程式已移除，未提交。
- ⚠️ **22–25（macOS）是在工具列順序修正前拍攝**：當時順序為「月曆、＋、放大鏡、篩選」；行為與現行程式碼相同。修正後順序「放大鏡、篩選、月曆、＋」見 21、26、27。
- 26 由全螢幕截圖裁成只剩 App 視窗。
- 00：淘汰的變體 b（一直掛 `.searchable`、只切 isPresented）——搜尋列收不起來。

| 檔名 | 狀態 |
|---|---|
| 00 | iOS 變體 b（淘汰） |
| 01／11 | iOS 收合（17 Pro／SE） |
| 02／12 | iOS 展開＋聚焦 |
| 03 | iOS 輸入中（預填） |
| 04／13 | iOS 有結果（預填） |
| 05／15 | iOS 取消後收回 |
| 06 → 07 | iOS 先篩 Nitrox，再搜 DA ⇒ 沒有符合（AND） |
| 21 | macOS 收合（修正後順序） |
| 22 | macOS 展開 |
| 23 | macOS 輸入＋結果，放大鏡實心藍 |
| 24 | macOS Esc 後收回 |
| 25 | macOS 清除後收回 |
| 26 → 27 | macOS 先篩 Nitrox，再搜 DA ⇒ 沒有符合（AND） |
