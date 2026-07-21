# JD2-Logbook v1.2 Backlog（待辦追蹤）

> 建立日期：2026-07-20。v1.1 backlog（`V1_1_BACKLOG.md`）已完工，本檔案是下一輪工作的
> 追蹤清單，目前為**初始登錄**，多數項目尚待使用者補充細節後才能展開執行。
> **單一權威來源**：本輪工作以此檔為準，`Docs/KNOWN_ISSUES.md` 只放精簡清單＋連結於此。

---

## 待辦清單

| # | 項目 | 狀態 | 細節 |
|---|------|------|------|
| 1 | iOS 版送審被拒絕，擬訂下次送審對策 | 🔄 進行中 | 收到完整拒絕內容：2.3.6（Advertising 未勾選，Age Rating 需改 Yes，純 ASC 設定，使用者需自行至 App Store Connect 修改）+ 5.1.2(i)（App Privacy 標示 Coarse Location/Other Usage Data/Device ID 用於追蹤，但程式碼查核確認**未使用 ATT、未用 IDFA、AdMob 為預設非個人化廣告、CoreLocation 僅本機一次性定位**，判定為 ASC 隱私標籤誤填，非真的有追蹤行為）。已修復 `logbook/privacy.md` 三語（EN/繁中/日文）內文，移除「IDFA 僅在授權後」「ATT 重設」等與實際行為不符的敘述。**尚待使用者執行（送審時提醒）**：① ASC Age Rating 勾選 Advertising=Yes；② ASC App Privacy 問卷重新填寫，Location/Device ID/Usage Data 取消勾選「used to track」；③ 送審 Review Notes 註明已修正。**⚠️ 使用者已指示：處理完成後（送審過關/事件落幕時）要把本次駁回事件（原因/分析/對策/行動/lessons learned）整理記錄到適當檔案，目前尚未執行，屆時提醒** |
| 1b | macOS「開啟 Game Center」誤設定 | 📋 待開始（使用者指示到時候修正） | 使用者回報有一個「設定成開啟 Game Center」的錯誤設定，細節待釐清（程式碼查無 GameKit/Game Center entitlement，可能是 App Store Connect 的 App 資訊設定、或與既有已知的 macOS `LSApplicationCategoryType` 誤觸發遊戲模式問題有關，見 `docs/KNOWN_ISSUES.md`「待決策事項」）。使用者指示「到時候」（送審前）再處理，先登錄追蹤 |
| 2 | App 內 icon 全盤 review | 📋 待開始 | 檢視所有 icon 使用情境是否恰當，不適當的要修改，可能需要自行設計新 icon |
| 3 | 修正潛水剖面圖互動功能問題 | ✅ 完成（三個子項全數完成） | ①**時間軸偏移**——根因是 `chartOverlay` 直接拿 `proxy.position(forX:)`/`proxy.value(atX:)` 當 GeometryReader 座標用，沒扣掉 Swift Charts 左側 Y 軸刻度標籤寬度；改用 `geo[proxy.plotAreaFrame]` 校正 origin。JD2-Ultra companion 同款 bug，已記錄 `SYNC_TO_JD2-ULTRA.md` #6。②**狀態資訊列第二列**——選取點命中警示事件時，在原本 Time/Depth/Temp/Ceiling/No Deco 五欄下方新增一列警示事件卡片（圖示＋標題＋描述＋右側深度/時間，比照使用者提供的參考圖樣式）。③**曲線警示標示**——`DiveReplayEngine.replay()` 新增上升速度追蹤（比照統一 DiveKit `AlgorithmConstants.maxAscentRateWarn`＝10 m/min、連續 5s→紅點「Ascent Rate Alert」、連續 10s→橘點「Mandatory Safety Stop」門檻，非另外發明數值），曲線上疊加對應顏色圓點標記。4 個新翻譯 key 已補齊 18 語言。模擬器驗證：紅色標記正確顯示在剖面曲線的上升段；第二列的選取聯動邏輯經程式碼核對正確，但受限模擬器點擊精度，未能視覺化逐像素驗證命中同一 sample index 的情境 |
| 4 | 公制／英制單位設定 | 🔄 進行中（Settings 選項已完成） | 新增 `JD2Core/Models/UnitSystem.swift`（metric/imperial 列舉 + 深度/溫度轉換函式）+ Settings 頁單位系統切換（不用文字，直接用符號：`m / °C` vs `ft / °F`），`@AppStorage` 持久化。**範圍限定聲明**：本次只做了設定頁選項本身；全 App 各處深度/溫度顯示與輸入欄位套用英制換算（Logbook 列表、Dive Detail、剖面圖、地圖、匯入預覽等）是後續較大範圍的工作，目前選了 ft/°F 也不會改變任何畫面顯示，尚未真正生效 |
| 5 | 匯入情境測試 | 📋 待開始 | 對 16 種已實作格式做情境化/端對端測試（目前多為單元測試，此項可能著重實際匯入流程、批次匯入、錯誤情境等） |
| 6 | 語系全審核 | 📋 待開始 | 18 種語言的翻譯品質全面覆核（非僅補齊缺漏 key，而是審核既有翻譯的正確性/自然度） |
| 7 | Import tab 部分文字未跟隨 App 內語言切換 | ✅ 完成 | 使用者發現日文語系下 Import tab 仍顯示英文（「Select Files or Folder」「Supported Formats」「UNIVERSAL」等）。根因與 v1.1 #8 相同類型：`ImportWizardView.swift` 用 `String(localized:)`（純 Foundation API，只認系統語言）而非 `languageManager.localized(_:)`（吃 App 內語言切換器），只是 v1.1 #8 修復當時這批 Import 格式清單程式碼還沒寫。全面替換為 `languageManager.localized(_:)`，新增缺漏的 "Import Completed with Issues" 翻譯 key（18 語言） |
| 8 | macOS 地圖沒有 recenter 按鈕 | ⚪ 非問題（使用者確認） | 查證：`recenterButton` 程式碼本身沒有 iOS-only 限制，只受 Settings 頁「Enable GPS Location」開關（`gpsLocationEnabled`）控制，該開關未開時按鈕本來就不存在——macOS/iOS 是各自獨立的 App 安裝，UserDefaults 不共用。使用者確認是 macOS 版沒開定位開關，非程式 bug，跳過 |

---

## 使用方式

- 每項工作展開前，先跟使用者確認細節範圍（尤其 #1 需要等使用者提供 Apple 拒絕信完整內容）。
- 完成一項，狀態改為 ✅ 完成，並在「細節」欄補上實作摘要／commit 參照，比照 `V1_1_BACKLOG.md` 的紀錄方式。
- 若某項工作展開後發現屬於家族層共用（DiveKit／DiveImportKit）範圍，依 `../CLAUDE.md` 家族鐵律第 8 條「回報鏈」處理，不自行跨 repo 修改。

---

**文件版本：** v1.0 | **建立日期：** 2026-07-20 | **最後更新：** 2026-07-20
