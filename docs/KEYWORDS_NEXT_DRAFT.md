# App Store 關鍵字草稿（下一版，2026-10-03）——**待 PM 審，尚未改 ASC**

PM 指示（2026-10-03）：移除品牌名稱；各語系用當地「潛水日誌」的主要用詞（例：台灣「潛水日誌」）。

## 現況診斷（v1.2）

1. **品牌名**：Shearwater、Garmin、Suunto 是潛水電腦品牌，Subsurface 是另一個 App 的名稱——
   App Review Guidelines 2.3.7 不允許把他人商標／其他 App 名放進中繼資料，也違反艦隊「對外不提品牌」紅線。**全部移除。**
   UDDF 是開放的檔案格式名稱（不是品牌），保留在英文組。
2. **繁中、日文 storefront 用的是同一組英文關鍵字**——在台灣打「潛水日誌」、在日本打「ダイビングログ」本來就不會命中。
   7/29 的紀錄把原因歸給「品牌詞擠掉 dive log」，但 dive log 其實一直在關鍵字裡；**主因比較可能是這一條**（加上新 App 排名低）。
3. 副標「Log Every Dive, Every Story」已讓 log／dive／every／story 被索引 ⇒ 關鍵字不必再放 dive、log（Apple 會跨欄位組合）。

## 草稿（字數＝含逗號；上限 100）

| 語系 | 關鍵字 | 字數 |
|---|---|---|
| en | `logbook,scuba,diving,divelog,diary,nitrox,freediving,UDDF,import,record,tracker,profile,deco,depth` | 98 |
| zh-Hant | `潛水日誌,潛水紀錄,潛水記錄,水肺潛水,自由潛水,潛水,日誌,紀錄,高氧,潛水電腦,潛水錶,深度,剖面,減壓,logbook,scuba,divelog` | 76 |
| ja | `ダイビングログ,ダイブログ,ログブック,スキューバ,ダイビング,潜水,記録,ナイトロックス,フリーダイビング,ダイブコンピュータ,水深,減圧,logbook,scuba` | 84 |

- 繁中同時放「紀錄／記錄」兩種寫法（台灣兩者都常見）。中日文組尾端保留少量英文，給習慣打英文的使用者。
- ⚠️ 副標目前三語都是英文。**繁中／日文副標改成當地語言**（例：「潛水日誌・每一潛都記下」／「ダイビングログを、すべての潜水に」）可再多一組被索引的詞——PM 決定。

## 其他語系（App 內有 18 語；ASC 目前只有上面 3 組 metadata）

若要增加 storefront 在地化（每一組都要有完整名稱／副標／說明），各語系「潛水日誌」主要用詞參考（**需母語者確認**）：
de Tauchlogbuch／fr carnet de plongée／es bitácora de buceo／it logbook immersioni／pt-PT registo de mergulho／nl duiklogboek／
ko 다이빙 로그／zh-Hans 潜水日志／th บันทึกการดำน้ำ／vi nhật ký lặn／id log selam／ms log selam／el ημερολόγιο κατάδυσης／hr dnevnik ronjenja。
