# App Store Copy — JoyDive²

---

## App Name (30 characters max)

JoyDive²

---

## Subtitle (30 characters max)

Log Every Dive, Every Story

---

## Promotional Text (170 characters — can update without resubmission)

Start logging your dives by hand from day one. Got a dive computer? Import everything in — UDDF, Garmin, Suunto, Subsurface, and more. One app, every dive.

---

## Description (4000 characters max)

JoyDive² is the dive log that grows with you — from your very first dive to your most advanced ones.

**No Dive Computer? No Problem.**
Start logging right away. Enter depth, dive time, water temperature, gas, and notes by hand. JoyDive² is built for divers at every stage — you don't need a dive computer to keep a proper logbook.

**Got a Dive Computer? Bring Everything In.**
Supports major brands including UDDF, Subsurface, Suunto, Garmin, Shearwater, ATMOS, Seabear, and more. Import your computer logs and they merge seamlessly alongside your manual entries — one complete, unified logbook.

**Every Detail, At a Glance**
Each entry can hold depth profile, max & average depth, dive time, gas mix (Air / Nitrox / Trimix), water temperature and conditions, equipment (wetsuit, weights, cylinder), GPS coordinates, and notes. A clean list view and calendar make it easy to browse your full dive history.

**Interactive Profile, With Tissue Loading (Limited Support)**
Tap and drag anywhere on the dive profile chart to inspect that exact moment — depth, elapsed time, and an estimated tissue loading level from the Bühlmann ZHL-16C model. A clearer picture of every dive, not a replacement for your dive computer. Tissue loading supports single-gas air and nitrox dives; it isn't available for trimix, multi-gas or rebreather dives, or for logs with discontinuous imported data — the depth profile itself always displays normally.

**Dive Site Map**
GPS coordinates are automatically plotted on a map so you can see every dive site you've visited. Cluster display keeps the map readable no matter how many dives you've logged.

**Go Ad-Free, Stay Focused (iOS)**
Core features are completely free. On iOS, a one-time purchase of "Remove Ads" ($1.99 USD) removes all ads permanently.

**Privacy First**
All dive data is stored exclusively on your device and never uploaded to a server. Your dive log is yours alone.

**18 Languages · iOS 17+ · macOS 14+**
Traditional Chinese, Simplified Chinese, English, Japanese, Korean, French, German, Spanish, Italian, Dutch, Portuguese, Indonesian, Malay, Vietnamese, Thai, Greek, Croatian, British English.

---

## Keywords (100 characters, comma-separated, no words already in App Name)

dive log,divelog,Tauchlogbuch,duiklogboek,plongée,buceo,bitácora,immersioni,mergulho,다이빙로그,selam,lặn

> ✅ **v1.3（2026-10-03，PM 裁示）**：移除品牌名（2.3.7＋艦隊紅線）；台灣／日本在地化，其他 storefront 用英文組。依據 `docs/KEYWORDS_NEXT_DRAFT.md`。舊組（v1.2）：`dive log,scuba,logbook,Shearwater,UDDF,Garmin,Suunto,Subsurface,nitrox,dive computer,freediving`

> ✅ **v1.3 再修訂（PM 2026-10-10）**：英文組**只放各國「潛水日誌」用詞**（不放品牌、不放泛用詞）——英 dive log／divelog、德 Tauchlogbuch、荷 duiklogboek、法 plongée、西 buceo／bitácora、義 immersioni、葡 mergulho、韓 다이빙로그、印尼／馬來 selam、越 lặn。片語拆成單字（App Store 會自動組合搜尋），18 語全放約 200 字元放不下，PM 選此組（未涵蓋：泰、希、克、簡中）。10/03 那組（logbook,scuba,diving,…,depth）已換掉。
> ⚠️ 100 characters / 114 bytes (no spaces after commas). Apple limit: 100 — ✅ **ASC 以字元計（2026-10-10 實測：100 字元／114 bytes 完整接受、剩餘 0）**，不必拿掉 lặn 或 selam。
> 📜 History: the v1.2 set (brand names such as Shearwater/Garmin/Suunto/Subsurface) was found unsearchable after launch
>   (2026-07-29); replaced in v1.3 per PM 2026-10-03. Details: `docs/KEYWORDS_NEXT_DRAFT.md`.

---

## What's New — v1.3（✅ PM 2026-10-05 定稿：籠統寫法，保留「提升準確度」；10-06 PM 同意加時區修正句；10-10 PM 加 ATMOS FIT）

Improved accuracy of decompression estimates. Added import of FIT files from ATMOS dive computers. Fixed dive times from several import formats being shifted by your time zone. Plus multiple minor bug fixes and improvements.

> ⚠️ 定稿不提 NDL 變短與連續潛水（PM 10/03 起的籠統方向）。日後若要補寫，兩件事**並列、不寫因果**：單筆潛水 NDL 變短主因是係數改正（v1.2 實為 ZHL-16B a 係數），不是連續潛水——
>   見 `_JD2-family/decisions/2026-10-03_App-lb重放輸出差異回顧-v1.2對現行.md`。不得改寫成「因為連續潛水所以 NDL 變短」。

---

## What's New — v1.2

New in this update:
• Import support for more dive computer formats
• Switch between metric and imperial units anytime
• Interactive dive profile chart with tissue loading detail
• Various bug fixes and stability improvements

---

## App Store Connect Fields

| Field | Value | Notes |
|-------|-------|-------|
| App Name | JoyDive² | English only |
| Subtitle | Log Every Dive, Every Story | Optional |
| Description | See above | |
| Keywords | See above | 100 chars max |
| Primary Category | **Sports**（v1.3 PM 2026-10-10 裁示：對齊其他潛水日誌 App；v1.2 為 Health & Fitness）——ASC 手動改 | Required |
| Support URL | https://kwh66tw-art.github.io/JoyDive/logbook/privacy | Required |
| Marketing URL | (leave blank) | Optional |
| Privacy Policy URL | https://kwh66tw-art.github.io/JoyDive/logbook/privacy | Required |
| Age Rating | 4+ | All questions → No |
| Contains Ads | ✅ Yes (iOS only) | AdMob is present on iOS; macOS build has no ads |
| Version | 1.3 | Build 4 (CURRENT_PROJECT_VERSION)；2026-10-06 Release 產物 `defaults read` 實測 1.3／4 |

---

## Screenshot Sequence (iPhone 6.9" required — iPhone 16 Pro Max, 1320×2868)

| # | Screen | Key message |
|---|--------|-------------|
| 1 | Dive list (multiple entries) | First impression — core function |
| 2 | Dive detail page | Shows full log entry |
| 3 | Map with multiple pins | Visual appeal |
| 4 | Import screen | Multi-format import |
| 5 | Calendar view | Alternative browse |

> Capture in Xcode Simulator (iPhone 16 Pro Max) with ⌘S. Optional: add caption text in Figma or Canva.

---
---

# App Store 文案 — JoyDive²

---

## App 名稱（30 字以內）

JoyDive²

---

## 副標題（30 字以內）

潛水日誌・每一潛都記下

> ✅ v1.3 定稿（PM 2026-10-03：台灣在地化）；v1.2 為英文 "Log Every Dive, Every Story"

---

## 宣傳文字（170 字，可隨時更新不需重新審核）

沒電腦錶也能從第一天開始手動記錄潛水。有了電腦錶？UDDF、Garmin、Suunto、Subsurface 等格式直接匯入，與手動記錄無縫整合。

---

## 描述（4000 字以內）

JoyDive²，陪你從第一次下水到每一次進階潛水的潛水日誌。

**沒有電腦錶？一樣可以開始記錄。**
直接手動建立潛水日誌。輸入深度、潛水時間、水溫、氣體與備註，從第一次下水就開始累積你的潛水歷史。JoyDive² 適合每個階段的潛水員，不需要電腦錶也能擁有一本完整的潛水記錄。

**有了電腦錶？把所有記錄都帶進來。**
支援多種主流品牌，包含 UDDF、Subsurface、Suunto、Garmin、Shearwater、ATMOS、Seabear 等。電腦錶的記錄匯入後，會與你手動建立的日誌無縫整合——從初學到現在，一本完整的記錄，一個 App 管理。

**完整的潛水資訊一目了然**
每筆記錄可保存深度剖面、最大/平均深度、潛水時間、氣體混合（空氣 / Nitrox / Trimix）、水溫與環境條件、裝備（防寒衣、配重、氣瓶），以及 GPS 座標與備註。清晰的列表與日曆視圖，讓你快速回顧每一次下水。

**互動式剖面圖，附組織負荷（有限支援）**
直接在潛水剖面圖上點選拖曳，即可查看任一時刻的深度、經過時間，以及以 Bühlmann ZHL-16C 演算法估算的組織負荷。讓你更清楚看懂整趟潛水過程——僅供參考，不能取代你的潛水電腦錶。組織負荷僅支援單一氣體的空氣與 Nitrox（高氧）潛水；Trimix、多氣體、封閉式循環呼吸器潛水，以及匯入資料不連續的紀錄不提供組織負荷——深度剖面本身一律正常顯示。

**潛點地圖**
自動將 GPS 座標標記在地圖上，一眼看到你去過的每一個潛點。支援聚類顯示，不論累積多少筆記錄都清晰好用。

**移除廣告，專心記錄（iOS 版）**
基礎功能完全免費。iOS 版可選擇一次性購買「移除廣告」（$1.99 美元），即可永久享有無廣告的純淨體驗。

**隱私優先**
所有潛水資料僅儲存於你的裝置，從不上傳至伺服器。你的潛水記錄，只屬於你。

**支援 18 種語言 · iOS 17+ · macOS 14+**
繁體中文、簡體中文、英文、日文、韓文、法文、德文、西班牙文、義大利文、荷蘭文、葡萄牙文、印尼文、馬來文、越南文、泰文、希臘文、克羅埃西亞文、英國英文。

---

## 關鍵字（100 字以內，逗號分隔）

潛水日誌,潛水紀錄,潛水記錄,水肺潛水,自由潛水,潛水,日誌,紀錄,高氧,潛水電腦,潛水錶,深度,剖面,減壓,logbook,scuba,divelog

> ✅ **v1.3（2026-10-03，PM 裁示）**：移除品牌名（2.3.7＋艦隊紅線）；台灣／日本在地化，其他 storefront 用英文組。依據 `docs/KEYWORDS_NEXT_DRAFT.md`。舊組（v1.2）：`dive log,scuba,logbook,Shearwater,UDDF,Garmin,Suunto,Subsurface,nitrox,dive computer,freediving`

> ⚠️ 76 字元／158 bytes（逗號後無空格）。上限 100——✅ ASC 以字元計（2026-10-10 實測，繁中組貼入後剩餘 24＝76 字元）。
> 📜 歷史：v1.2 舊組（含 Shearwater／Garmin／Suunto／Subsurface 等品牌）2026-07-29 上架後確認搜尋不到；v1.3 已依 PM 2026-10-03 裁示更換。
>   詳見 `docs/KEYWORDS_NEXT_DRAFT.md`。

---

## 版本說明（What's New）— v1.3（✅ PM 2026-10-05 定稿；10-06 加時區修正句；10-10 加 ATMOS FIT）

提升減壓估算的準確度；新增匯入 ATMOS 潛水電腦錶的 FIT 檔；修正部分匯入格式的潛水時間因時區而偏移的問題；並修正多項小問題。

---

## 版本說明（What's New）— v1.2

本次更新：
• 新增支援多種潛水電腦錶格式匯入
• 隨時切換公制／英制單位
• 互動式潛水剖面圖，顯示組織艙飽和度資訊
• 多項錯誤修正與穩定性改善

---

## 截圖建議畫面（iPhone 6.9" 必選——iPhone 16 Pro Max，1320×2868）

| 順序 | 畫面 | 重點說明 |
|------|------|----------|
| 1 | 潛水日誌列表（有多筆資料） | 第一眼印象，展示核心功能 |
| 2 | 潛水詳情頁 | 展示完整記錄內容 |
| 3 | 地圖（有多個潛點 pin） | 地圖功能視覺吸引力強 |
| 4 | 匯入畫面（選擇檔案） | 強調多格式匯入 |
| 5 | 日曆視圖 | 展示另一種瀏覽方式 |

> 在 Xcode 模擬器（iPhone 16 Pro Max）以 ⌘S 截圖後直接上傳。可選：用 Figma 或 Canva 加標語文字。

---
---

# App Store 掲載用テキスト — JoyDive²

---

## App名（最大30文字）

JoyDive²

---

## 副題（最大30文字）

ダイビングログを、すべての潜水に

> ✅ v1.3 定稿（PM 2026-10-03：日本在地化）；v1.2 は英語 "Log Every Dive, Every Story"

---

## プロモーション用テキスト（170文字以内 — アップデート不要で随時更新可能）

ダイコンなしでも初日からダイブログを手動で記録できます。ダイコンをお持ちなら、UDDF、Garmin、Suunto、Subsurfaceなどをインポート。手動ログとシームレスに統合できます。

---

## 説明（最大4000文字）

JoyDive²は、初めてのファンダイビングからステップアップしたダイビングまで、あなたの成長に寄り添うダイビングログブックアプリです。

**ダイブコンピューターがなくても大丈夫**
すぐにログの記録を始められます。水深、潜水時間、水温、ガス、メモなどを手動で入力するだけ。JoyDive²はあらゆるステージのダイバー向けに設計されているため、ダイコンをお持ちでなくても本格的なログブックを作成できます。

**ダイコンをお持ちなら、すべてのデータを集約**
UDDF、Subsurface、Suunto、Garmin、Shearwater、ATMOS、Seabearなど、主要なブランドに幅広く対応。お手持ちのダイコンのログをインポートすれば、手動で作成したエントリーと美しく統合され、これまでのすべての記録を一つのアプリで一元管理できます。

**充実のダイビング情報をひと目で確認**
各ログには、水深プロファイル、最大/平均水深、潜水時間、ガスミックス（空気 / ナイトロックス / トライミックス）、水温とコンディション、装備（ウェットスーツ、ウェイト、タンク）、GPS座標、メモを記録可能。洗練されたリスト表示とカレンダービューにより、過去のダイビング履歴をスムーズに振り返ることができます。

**インタラクティブなプロファイルと組織負荷（限定サポート）**
ダイブプロファイルチャート上をタップ&ドラッグするだけで、その瞬間の水深・経過時間、そしてBühlmann ZHL-16Cモデルによる推定組織負荷を確認できます。ダイビングをより深く理解できますが、ダイブコンピューターの代わりにはなりません。組織負荷は単一ガスの空気およびナイトロックスのダイビングに対応しています。トライミックス、マルチガス、リブリーザーのダイビング、および取り込みデータが不連続なログでは表示されません。ダイブプロファイル自体は常に通常どおり表示されます。

**ダイブサイトマップ**
GPS座標から地図上へ自動的にピンをドロップ。これまで訪れたすべてのダイブサイトを視覚的に確認できます。クラスタリング表示に対応しているため、ログの数が多くなっても地図がすっきりと見やすく保たれます。

**広告を非表示にして、記録に集中（iOS版）**
基本機能は完全に無料でご利用いただけます。iOS版では、一度の「広告非表示」購入（$1.99 USD）で、永久に広告のないクリーンな環境でアプリを使用できます。

**プライバシー最優先**
すべてのダイビングデータはユーザーのデバイス内にのみ保存され、サーバーへアップロードされることは一切ありません。あなたのログデータは、あなただけのものです。

**18の言語に対応 · iOS 17+ · macOS 14+**
日本語、英語、繁体字中国語、簡体字中国語、韓国語、フランス語、ドイツ語、スペイン語、イタリア語、オランダ語、ポルトガル語、インドネシア語、マレー語、ベトナム語、タイ語、ギリシャ語、クロアチア語、イギリス英語。

---

## キーワード（最大100文字、カンマ区切り、App名にある単語は除外）

ダイビングログ,ダイブログ,ログブック,スキューバ,ダイビング,潜水,記録,ナイトロックス,フリーダイビング,ダイブコンピュータ,水深,減圧,logbook,scuba

> ✅ **v1.3（2026-10-03，PM 裁示）**：移除品牌名（2.3.7＋艦隊紅線）；台灣／日本在地化，其他 storefront 用英文組。依據 `docs/KEYWORDS_NEXT_DRAFT.md`。舊組（v1.2）：`dive log,scuba,logbook,Shearwater,UDDF,Garmin,Suunto,Subsurface,nitrox,dive computer,freediving`

> ⚠️ 84文字／202 bytes（カンマの後にスペースなし）。上限100——**ASCは文字数で数える（2026-10-10 実測：日本語組は貼り付け後の残り16＝84文字）**。
> 📜 履歴：v1.2の旧セット（Shearwater／Garmin／Suunto／Subsurface などブランド名）は2026-07-29にリリース後検索されないことが判明。v1.3でPM 2026-10-03の裁示により差し替え済み。
>   詳細は `docs/KEYWORDS_NEXT_DRAFT.md`。

---

## 新機能（What's New）— v1.3（✅ PM 2026-10-05 定稿；10-06 タイムゾーン修正を追加；10-10 ATMOS FIT を追加）

減圧推定の精度を改善しました。ATMOS ダイブコンピューターの FIT ファイルのインポートに対応しました。一部のインポート形式でダイブ時刻がタイムゾーン分ずれる問題を修正しました。そのほか複数の軽微な不具合を修正しました。

---

## 新機能（What's New）— v1.2

今回のアップデート内容：
• 対応フォーマットを追加——より多くのダイブコンピューターのログをインポート可能に
• メートル法／ヤードポンド法をいつでも切り替え可能
• 組織飽和度情報を表示するインタラクティブなダイブプロファイルチャート
• その他バグ修正と安定性の向上

---

## App Store Connect 入力項目

| 項目 | 値 | 備考 |
|------|----|----|
| App名 | JoyDive² | 英語表記のみ |
| 副題 | ダイビングログを、すべての潜水に | オプション |
| 説明 | 上記を参照 | |
| キーワード | 上記を参照 | 最大100文字 |
| プライマリカテゴリ | **スポーツ**（v1.3 PM 2026-10-10：他のダイブログAppに合わせる；v1.2はヘルスケア／フィットネス）——ASCで手動変更 | 必須 |
| サポートURL | https://kwh66tw-art.github.io/JoyDive/logbook/privacy | 必須 |
| マーケティングURL | （空欄のまま） | オプション |
| プライバシーポリシーURL | https://kwh66tw-art.github.io/JoyDive/logbook/privacy | 必須 |
| 年齢制限指定 | 4+ | すべての質問 → いいえ |
| 広告を含む | ✅ はい（iOSのみ） | iOS版はAdMob実装あり／macOS版は広告なし |
| バージョン | 1.2 | ビルド 3（CURRENT_PROJECT_VERSION） |

---

## スクリーンショットの構成案（iPhone 6.9インチ必須——iPhone 16 Pro Max、1320×2868）

| 番号 | 画面 | 主な訴求メッセージ |
|------|------|-----------------|
| 1 | ダイブログリスト（複数データあり） | 第一印象 — コア機能の提示 |
| 2 | ログ詳細ページ | 充実した記録内容の紹介 |
| 3 | 複数ピンのあるマップ | マップ機能による視覚的アピール |
| 4 | インポート画面 | 多彩なフォーマットへの対応 |
| 5 | カレンダービュー | 別パターンのブラウズ機能の提示 |

> Xcodeシミュレーター（iPhone 16 Pro Max）にて ⌘S でスクリーンショットを撮影。オプション：FigmaやCanvaで説明用のキャッチコピーを追加するのも効果的です。
