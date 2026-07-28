# 潛水日誌 App 語系翻譯校對報告

**審核檔案**：`JD2-Logbook_語系全審核_260筆_0726.csv`
**校對重點**：18 種語系，特別針對專業潛水術語（包含 NDL、減壓、配重、氣瓶、能見度等），並特別針對 "Visibility" 的印尼文/馬來文翻譯進行查證。

## 總評

在跨 18 種語系的「全盤校對」中，大部分的日常與 UI 詞彙翻譯得相當不錯。然而，在**專業潛水術語**方面，機器翻譯或非母語者的翻譯容易流於字面直譯，這可能導致當地潛水員無法直覺理解，甚至在緊急狀況下（如減壓上限、上升速率警報）造成安全疑慮。

---

## 🚨 翻譯修正建議清單

| 行 | Key | 語言 | 目前 | 建議 | 原因 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **259~262** | Visibility | `id` (印尼文) | Visibilitas | **Jarak pandang** | "Visibilitas" 雖然存在於印尼文字典，但在潛水實務上，不論是 PADI 教材或當地導潛，都習慣使用 "Jarak pandang"（視線距離）來表達能見度。 |
| **259~262** | Visibility | `ms` (馬來文) | Visibilitas | **Jarak penglihatan** | "Visibilitas" 對馬來西亞人來說非常生硬，更偏向印尼文的借詞。馬來語中表達能見度最標準的用法是 "Jarak penglihatan"。 |
| **41** | Ceiling | `id` (印尼文) | Plafon dekompresi | **Batas dekompresi** 或直接用 **Ceiling** | "Plafon" 在印尼文裡專指「建築物的天花板」。潛水電腦錶的減壓上限通常譯為 "Batas dekompresi" (減壓界線) 或是直接沿用英文 "Ceiling"。 |
| **41** | Ceiling | `ms` (馬來文) | Siling deko | **Had deko** 或直接用 **Siling** | 同上，"Siling" 容易讓人聯想到房屋天花板。"Had" (限制/界限) 更符合減壓上限的語境。 |
| **47** | Cylinder Material | `id` (印尼文) | Material silinder | **Bahan tabung** | 在印尼潛水界，氣瓶幾乎一律稱為 "Tabung" (例如 Tabung Scuba)，極少稱為 "silinder"。 |
| **48** | Cylinder Size | `id` (印尼文) | Ukuran silinder | **Ukuran tabung** | 同上，為了符合當地潛水員的習慣用語，應將 silinder 改為 tabung。 |
| **47** | Cylinder Material | `ms` (馬來文) | Bahan silinder | **Bahan tangki** | 馬來西亞潛水圈較常使用 "Tangki" 來指稱潛水氣瓶，而非 "silinder"。 |
| **48** | Cylinder Size | `ms` (馬來文) | Ukuran silinder | **Saiz tangki** | 理由同上，且馬來文通常將 Size 譯為 "Saiz"。 |
| **269** | Weight | `id` (印尼文) | Berat | **Pemberat** | "Berat" 是名詞/形容詞的「重量」（如幾公斤），而潛水用的配重鉛塊物件應稱為 "Pemberat"。請注意，您在第 271 行 (`Weight: %.1f kilograms`) 已經正確使用了 "Pemberat"，此處應統一。 |
| **269** | Weight | `ms` (馬來文) | Berat | **Pemberat** | 理由同上，馬來文的配重物件也是 "Pemberat"。 |
| **272** | Wetsuit | `id` / `ms` | Pakaian Menyelam | **Wetsuit** 或 **Baju selam** | "Pakaian Menyelam" (潛水服裝) 過於冗長且生硬。新馬印的潛水員多半直接使用 "Wetsuit" 或口語的 "Baju selam"。且您在第 273 行 (`Wetsuit Thickness`) 就是用 "Ketebalan wetsuit"，這裡改為 "Wetsuit" 可保持專有名詞一致性。 |
| **30** | Ascent Rate Alert | `id` (印尼文) | Peringatan Laju Ascent | **Peringatan Kecepatan Naik** | 這是英文跟印尼文的混雜錯誤。且在第 203 行的翻譯中已經正確使用了 "kecepatan naik" (上升速度)，此處應統一。 |
| **30** | Ascent Rate Alert | `ms` (馬來文) | Amaran Kadar Ascent | **Amaran Kadar Naik** | 同上，"Ascent" 並未被翻譯到，應改為馬來文的 "Naik" (上升)。 |
| **131** | Min NDL | `zh-Hant` (繁中) | 最短免停留極限 *(待裁定)* | **最短免減壓極限** 或直接用 **最短 NDL** | 針對此行備註的待裁定事項：在台灣/香港的潛水界，NDL 最通用的中文是「免減壓極限」，或者大家口語早已習慣直接說「NDL」。「免停留」雖然意思也對，但「免減壓」更顯專業與常見。 |

---

## 💡 架構師與稽核建議

1. **專業術語縮寫保留**：在 UI 介面顯示上，某些國際通用的潛水縮寫（如 **NDL**, **Deco**, **O2**, **SAC**）在東南亞語系中，強烈建議直接保留英文原文。這不僅能節省智慧型手機或手錶螢幕的顯示空間，也更符合當地潛水員受訓時使用 PADI/SSI 英文教材的習慣，不會造成認知負擔。
2. **名詞一致性**：如前述提到的 "Weight" 在同一語系中出現兩種不同的翻譯（Berat / Pemberat），在導入 App 時務必確保 String Key 在不同情境下的呼叫邏輯，以免影響使用者體驗。
