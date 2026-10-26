# v1.4 A1＋A2 全盤稽核與邊界測試計劃

> 2026-10-26 App-lb 起草（PM 指示「先寫計劃」）。**本檔只是計劃，尚未執行**；執行結果逐項回填「狀態」欄。
> 範圍：A1 環境「未記錄」＋SwiftData 版本化（`1cf3dc7`，已 push）、A2 搜尋擴充（未 commit）。
> 基準：`run_tests.sh logbook` A1 後 185/0/1；含 A2 193/0/1（唯一 skip＝`PurchasePriceDisplayTests.testPremiumPriceStringIsNilWhenProductNotYetLoaded`，結果時跳時過）。

## 〇、優先級定義

- **P0**：可能讓使用者打不開資料、遺失資料、或組織負荷偏樂觀 ⇒ 送審前必過。
- **P1**：顯示錯誤、雙平台缺口、對外文案 ⇒ 送審前必過。
- **P2**：效能、邊角輸入、維護性 ⇒ 盡量做，可列已知限制。

## 一、稽核發現（先列風險，再排測試）

| # | 發現 | 依據 | 嚴重度 |
|---|---|---|---|
| F1 | ✅（10/26 修正並實測，見 T1–T3）~~跳版升級未測~~：v1.2（或更早）使用者若跳過 v1.3 直接裝 v1.4，store 模型雜湊對不上 `DiveLogSchemaV1`。v1.3 以前靠 SwiftData 隱式推斷遷移；**改用 `SchemaMigrationPlan` 後，未列在計劃內的舊版 store 能否開檔，未查證**。若失敗會進 `DatabaseOpenErrorView`（資料不刪，但打不開）。 | `DiveLogDatabase.swift` 改帶 `migrationPlan`；v1.2 送審 commit `3ba4bd2` 可簽出 | P0 |
| F2 | V1 凍結拷貝的欄位與 v1.3 `DiveLog` 逐欄一致（`diveMode` 預設值寫法不同但值相同；比對時 `gasMixJSON` 因行尾註解被 regex 漏抓、`waterTemp` 屬另一個 struct）——**機器比對＋v1.3 真實 store 實測（1.0.0→2.0.0、6 筆全欄位不變）雙重確認** | 決策檔 §四之三 | 已驗 |
| F3 | 舊標籤閘門只擋**目標潛水**；舊標籤高海拔（1.0 bar）若是**前導潛水**，仍以 1.0 bar 進殘氮鏈，後一支潛水的組織負荷可能偏樂觀。PM 未裁示。 | `DiveAnalysisView.swift` `.task`；`DiveReplayChainQuery.precedingDives` 未過濾 | P0（待 PM 裁示） |
| F4 | **macOS 完全未實機看過**：編輯頁 Picker、詳細頁環境列、組織負荷原因句、搜尋欄提示（macOS 走 `TextField` 分支） | 只截了 iOS | P1 |
| F5 | **地圖面板**（`DiveSiteSheetView`）環境列改用共用函式，未截圖 | — | P1 |
| F6 | 4 個新字串只有 en／en-GB／zh-Hant／ja；其餘 14 語顯示英文。術語未比對 F-10 術語表；「Search location…」為 App-u 共用鍵，App-lb 已不再使用 ⇒ 需回報總指揮 | `Localizable.xcstrings` | P1 |
| F7 | 未知 `environmentType` 值（例如手錶日後寫入新值）：顯示「未記錄」、編輯頁 Picker 空白、存檔應原樣寫回——**只有「altitude」實測過原樣寫回** | `DiveLogEditSheet.swift:796/835` | P1 |
| F8 | `surfacePressureBar` 異常值（0、負數、NaN、>1.1）時的徽章與閘門行為未定義；0 會被判成高海拔 | `DiveLog.isHighAltitude` | P2 |
| F9 | 搜尋每次按鍵對每筆潛水解碼一次 `importExtrasJSON`；大量資料下的打字延遲未量 | `DiveLog+Search.swift` | P2 |
| F10 | `importExtras` 以 `[String: String]` 解碼；若某筆 JSON 含非字串值，整筆的潛伴／標籤都搜不到（地點照常）。寫入端（Adapter／備份）目前都只寫字串 | `DiveLog.importExtras` | P2 |
| F11 | 手動新增的潛水**沒有潛伴／標籤欄位可填**，搜尋擴充只對匯入紀錄有效（產品限制，需寫進說明或排後續） | 編輯頁無 buddy 欄位 | P2（產品決策） |
| F12 | `localizedCaseInsensitiveContains` 不忽略重音（Café ≠ Cafe）、全形／半形不等價——與 A2 前行為相同 | — | P2（記錄即可） |
| F13 | v1.4 匯出的備份若含 nil 環境，**v1.3 讀不回整份備份**（v1.3 該欄非可選）——與 C2 水溫同一類取捨 | `DiveLogBackup.swift` | 已知，需 PM 知悉 |

## 二、邊界測試矩陣

方法：**U**＝單元測試（`run_tests.sh`）、**S**＝模擬器（專用「JD2-LB-UpgradeTest」）、**M**＝macOS build＋截圖、**R**＝讀碼／grep。

### A1 資料與遷移

| ID | 案例 | 方法 | 預期 | 優先 | 狀態 |
|---|---|---|---|---|---|
| T1 | v1.2 store（`3ba4bd2` build）覆蓋安裝 v1.4 | S | 開檔成功、全欄位不變 | P0 | ✅ **修正後通過（2026-10-26）**：初測失敗（錯誤頁，資料未動；截圖 11）⇒ PM 裁示 A 方案補齊歷代 schema（V1_0／V1_2／V1_3／V1_4）⇒ 重測：4 筆全欄位不變、新增 `ZDIVEMODE`、store 1.0.0（雜湊 `e29d88bc`）→ 1.4.0（`f1c58c3f`）、列表正常（截圖 12）。v1.2 以當時 Kit（DiveKit `ef469ca`／DIK `9e09f11`）編譯 |
| T2 | v1.0 store（`d54966b` build，1.0(2)）覆蓋安裝 v1.4 | S | 同 T1 | P0 | ✅ **通過**：3 筆全欄位不變、新增 `ZIMPORTEXTRASJSON`／`ZAVGDEPTH`／`ZDIVEMODE`（預設值）、雜湊 `598c4f7f` → `f1c58c3f`（截圖 13）。v1.1 未上架，不測 |
| T3 | v1.3 → v1.4（全新 v1.3 store，含 nil 水溫、free 模式、tags）；升級後再開第二次 | S | 版本維持、資料不變 | P0 | ✅ **通過**：3 筆全欄位不變、`48ac84ec` → `f1c58c3f`（截圖 14）；T1 模擬器升級後重開一次正常（不重複遷移） |
| T4 | 遷移後新增一筆未記錄 ⇒ 重開 ⇒ 仍為 nil | S | nil | P1 | 單元測試已有（V2 store），模擬器未做 |
| T5 | 空資料庫（全新安裝）啟動 | S | 正常、store 2.0.0 | P1 | 未做 |
| T6 | 備份：v1.3 匯出 → v1.4 還原；v1.4（含 nil）匯出 → v1.4 還原 | U＋S | 原值保留；nil 往返 | P1 | 單元測試已有，實檔未做 |
| T7 | 備份：v1.4（含 nil）→ v1.3 還原 | S | 預期整份失敗（F13），確認錯誤訊息不閃退 | P2 | 未做 |
| T8 | 匯入：無環境欄位的真實樣本（UDDF／FIT 各一）⇒ 未記錄；DIK 若帶值 ⇒ 原樣 | U | 同 | P1 | 只有合成資料測試 |

### A1 顯示與編輯

| ID | 案例 | 方法 | 預期 | 優先 | 狀態 |
|---|---|---|---|---|---|
| T9 | 環境值 × 氣壓組合表：{nil, seawater, freshwater, altitude, 未知值, ""} × {1.0, 0.95, 0.9499, 0.8, 0, -1, NaN} | U | 水域：只有 seawater／freshwater 有名稱；徽章：只有 `< 0.95`；NaN 不判高海拔；0／負數行為**先記錄現況再交 PM** | P1 | 部分（無 ""、0、負數、NaN） |
| T10 | 未知值紀錄開編輯頁 ⇒ Picker 空白 ⇒ 不動直接存 ⇒ 值不變 | S＋U | 原值 | P1 | 未做 |
| T11 | 舊標籤紀錄改成未記錄／淡水 ⇒ 存 ⇒ 舊標籤選項消失、閘門解除 | S | 同 | P1 | 改海水已做；未記錄／淡水未做 |
| T12 | 地圖面板環境列（3 種代表值） | S | 與詳細頁一致 | P1 | 未做 |
| T13 | 18 語各切一次：詳細頁環境列、編輯頁 Picker、原因句、揭露句、搜尋提示 | S | 無截斷、無遺漏鍵（14 語顯示英文為已知） | P1 | 未做 |
| T14 | 最大字級（Dynamic Type AX5）＋深色模式：原因句與「· 高海拔潛水」換行 | S | 不截斷、不重疊 | P1 | 未做 |
| T15 | VoiceOver 讀環境列與原因句 | S | 讀得出完整句 | P2 | 未做 |
| T16 | macOS：T10–T14 的代表案例＋編輯頁 Picker | M | 同 iOS | P1 | 未做 |

### A1 重放閘門

| ID | 案例 | 方法 | 預期 | 優先 | 狀態 |
|---|---|---|---|---|---|
| T17 | 閘門邊界：altitude × {1.0, 0.9999, 1.0001, 0.8}；非 altitude × 1.0 | U | 只有 altitude＋1.0 擋 | P0 | ✅ 已有 |
| T18 | 舊標籤 1.0 bar 作為**前導潛水**（F3）：記錄現況輸出（前導是否進鏈、後一支組織負荷數值） | U | **只記錄事實、不改程式**，交 PM 裁示 | P0 | 未做 |
| T19 | 閘門與 Kit 拒算同時成立時，只顯示 App 原因句（不重複） | U／讀碼 | 同 | P2 | 讀碼成立，未測 |
| T20 | 原因句接法：中日文全形句號不加空格、其他語言加空格；14 語回退英文時 | U | 同 | P1 | 中日英已測 |

### A2 搜尋

| ID | 案例 | 方法 | 預期 | 優先 | 狀態 |
|---|---|---|---|---|---|
| T21 | 欄位：潛點、備註、潛伴、標籤各自命中；鍵名不命中；其他 extras 不命中 | U | 同 | P1 | ✅ 已有 |
| T22 | 真實樣本：Subsurface XML（潛伴＋標籤）、UDDF 多位潛伴（Kit 以空白串接）、Subsurface CSV、Diving Log | U | 每種格式至少一筆可用潛伴搜到；多位潛伴任一名字可搜到 | P1 | 只有 Subsurface XML |
| T23 | 輸入邊界：前後空白、全空白、單字元、大小寫、中文、emoji、`%`／`*`／`.`／`\`（不是 regex） | U | 只做子字串比對、不崩潰 | P2 | 部分 |
| T24 | 重音／全半形（F12）：記錄現況 | U | 與 A2 前一致 | P2 | 未做 |
| T25 | `importExtrasJSON` 損毀、空字串、含非字串值（F10） | U | 地點照常命中、不崩潰 | P2 | 損毀已測；非字串值未測 |
| T26 | 效能（F9）：2,000 筆（含 extras）逐字輸入，量 `filteredDives` 耗時 | U（measure）＋S | 每次按鍵 < 1 幀（16 ms）為目標；**門檻為本專案決定**，超過就回報、不自行改快取 | P2 | 未做 |
| T27 | 模擬器實際輸入搜尋（iOS）；macOS 搜尋欄 | S＋M | 只剩命中筆數；清除後回全部 | P1 | iOS 輸入受阻（見下）；macOS 未做 |
| T28 | 搜尋中刪除一筆、搜尋中匯入新資料 ⇒ 結果即時更新 | S | 同 | P2 | 未做 |

### 跨項目

| ID | 案例 | 方法 | 預期 | 優先 | 狀態 |
|---|---|---|---|---|---|
| T29 | 全 repo grep：`environmentType`、`"altitude"`、`Search location…`、`importExtras[` 每一處都經過審查 | R | 無遺漏的 switch／default 落海水 | P1 | A1 時做過一次，A2 後再跑 |
| T30 | `check_privacy_manifest.py`、`check_doc_version_sync.sh`、機敏掃描 | R | 皆過 | P1 | 版號／機敏 A1 已過 |
| T31 | Release build（非 Debug）iOS＋macOS 編得過、`#if DEBUG` 的 MockDataSeeder 不進 Release | M | 同 | P1 | 未做 |

## 三、執行順序與停止條件

1. **T1（P0）先做**——它決定 A1 的版本化策略是否要改。失敗即停，交出「失敗訊息＋三個候選做法（補 V0 拷貝／開檔失敗時退回不帶計劃開檔／其他）」給 PM，不自行選。
2. T18（F3 記錄事實）→ 交 PM 裁示前導潛水要不要一併擋。
3. 單元測試批次：T9、T10、T20、T22、T23、T24、T25、T26 ⇒ 一次 `run_tests.sh`。
4. 模擬器批次（iOS）：T3、T4、T5、T6、T11、T12、T13、T14、T27、T28 ⇒ 一次批次截圖，不逐項重截。
5. macOS 批次：T16、T27（macOS）、T31。
6. 收尾：T29、T30；結果回填本檔，更新決策檔與 HANDOFF。

**停止條件**：任一 P0 失敗即停止回報；同一個模擬器操作重試兩次仍不成功即停（T27 iOS 已觸發：simctl 貼上三次、切鍵盤一次皆未進欄位）——改請 PM 手動輸入或改用 UI 測試 target 驅動。

## 四、需要 PM 決定的事（不等執行完）

- **D-A**（F3）：舊標籤高海拔 1.0 bar 當**前導潛水**時，後一支潛水是否也判不支援？
- **D-B**（F11）：手動新增是否要加潛伴／標籤欄位（會動 schema → V3），或列為已知限制？
- **D-C**（F8）：水面氣壓 0／負數是否視為「未記錄」而非高海拔？
- **D-D**（F6）：新字串定稿（4 句）與 14 語翻譯排程。
