# v1.3 D6／D7 查證結果（2026-10-04 夜，依 PM 核准「先查證再決定」）

> 引用一律來自官方原頁（WebFetch 讀原文，不採搜尋摘要）。**兩項都未改程式**，待 PM 決定。

## D7 ATS：`NSAllowsArbitraryLoads` 保留或移除

- **現況**（`JD2-Logbook/Info.plist`）：`NSAllowsArbitraryLoads = true`、`NSAllowsArbitraryLoadsForMedia = true`。
- **AdMob 官方**（[App Transport Security](https://developers.google.com/admob/ios/privacy/app-transport-security)，頁面標示最後更新 2026-10-02）：
  要求的只有 `NSAllowsArbitraryLoadsForMedia` 與 `NSAllowsArbitraryLoadsInWebContent` 兩個鍵；**全頁未提及 `NSAllowsArbitraryLoads`**。
- **建議**：改成官方寫法——移除 `NSAllowsArbitraryLoads`、補 `NSAllowsArbitraryLoadsInWebContent`（`ForMedia` 保留）。
  好處：少一個需要向審核解釋的全域放寬；風險：若 App 有其他非 HTTPS 的連線會被擋——已 grep 確認 App 原始碼 `"http://` **0 處**（2026-10-04）；改後仍須於模擬器確認測試廣告照常顯示。
- ⚠️ v1.2 帶著現行設定已過審，所以這不是送審阻擋項；改不改由 PM 決定。

## D6 GDPR／UMP 同意流程（歐洲經濟區、英國、瑞士）

- **現況**：`GoogleUserMessagingPlatform` 已被解析成相依套件，但**沒有任何程式碼呼叫 UMP API**（稽核 R-12）；App 只走非個人化廣告。
- **Google 官方**：
  - [EU user consent policy help](https://www.google.com/about/company/user-consent-policy-help/)：非個人化廣告「still require cookies to operate」；cookie 或行動裝置識別碼用於非個人化廣告的頻率上限與彙總報表。
  - [AdMob Help：EU User Consent Policy consent audit](https://support.google.com/admob/answer/16758589?hl=en)：發布商須「adopt a Google certified CMP in accordance with TCF requirements」；未配合時，**只有 Limited Ads（受限廣告）有資格投放**。
- **結論**：「只放非個人化廣告」**不等於免同意**。目前在歐洲區的實際影響是廣告收益（只能投受限廣告，或不投放）與 AdMob 帳號政策風險；**不是 App Store 審核規則**，不阻擋 v1.3 送審。
- **選項**：
  - (A) v1.3 接上 UMP（套件已在）：首次啟動在歐洲區顯示同意表單；需新增 UI 流程、隱私政策補述、測試（UMP 有測試地區設定）。
  - (B) v1.3 不做，下一版做；送審照常。
  - **我的建議：B**——v1.3 聚焦正確性與揭露；UMP 屬營收與廣告政策，獨立做一版較好驗證。

## 驗證方式

兩頁皆以 WebFetch 讀原文；搜尋摘要曾把「iOS 9 需要 `NSAllowsArbitraryLoads`」寫進結論，但官方現行頁面**沒有這句**——以原頁為準。
