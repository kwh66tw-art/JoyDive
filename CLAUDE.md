# CLAUDE.md — JD2-Logbook 工作指引

> Claude agent 接手前必讀。快速定位專案狀態與文件。

---

## 現況速覽

- **狀態**：v1.0 已提審 App Store（iOS + macOS）；iOS 審核逾期未回覆，PM 決定不再等待，**2026-07-14 啟動 v1.1 開發，2026-07-17 完工 13/14 項**（詳見 `V1_1_BACKLOG.md`）
- **目標上線**：2026 年 8 月 18 日
- **平台**：iOS 17.0+ / macOS 14.0+，Swift 6
- **Bundle ID**：`com.jd2logbook.JD2-Logbook`
- **Apple Team**：HUA SHENG Huang（77UHM3NN7J）
- **最新 commit**：（本次 v1.1 完工 commit，見 `git log`）

### 審核狀態（截至 2026-07-14）
- **macOS App 1.0**：✅ 已通過審核
- **iOS App 1.0**：⏳ Waiting for Review（等待超過一個月無回應，不阻塞 v1.1 開發）
- **Build**：iOS + macOS 均為 Build 2（`CURRENT_PROJECT_VERSION = 2`；下次發布需 +1 → 3）
- **IAP**：`com.jd2logbook.premium`，Non-Consumable，$1.99，已隨版本送審

### v1.1 開發（2026-07-14 啟動，2026-07-17 完工 13/14 項）
- 詳細紀錄見 `V1_1_BACKLOG.md`、`CHANGELOG.md` 2026-07-17 條目
- 已完成：#1–8、#11–14（技術債 3 項 + importExtrasJSON/avgDepth/裝置欄位 + DiveKit 互動剖面圖/組織艙飽和度 + Garmin Connect JSON + 測試覆蓋率 89.1% + Export/Import 備份 + 地圖 recenter + 語言切換）
- **#9/#10（iOS 18 Widget）PM 確認不需要，終止規劃**，不會排入後續版本
- **重要架構變更**：本地 `JD2Core/Algorithm/{Buhlmann,DiveEngine}.swift`、`Constants/AlgorithmConstants.swift`、`Models/{GasMix,DiveEnvironment}.swift` 已整包替換為 Ultra 的 `DiveKit` 版本（原本是零呼叫端的死碼，含 9 項已知安全問題）；`JD2Core/Algorithm/` 新增 `DecoCalculator`/`DivePlanner`/`FreeDive`/`GuidanceBanner`/`OxygenToxicity`/`DiveReplayEngine`，`JD2Core/State/` 為新資料夾（`DiveComputerState`/`LogSummary`/`SurfaceStatus`）
- **待決策**：macOS `LSApplicationCategoryType` 誤觸發遊戲模式，PM 決定延後到上架前拍板，見 `Docs/KNOWN_ISSUES.md`「待決策事項」
- 解法參考：`V1_1_BACKLOG_解法參考_from_JD2-Ultra.md`（Ultra 單向提供，不會再更新）

---

## 關鍵文件

| 文件 | 用途 |
|------|------|
| `JD2-Logbook_文件登錄表_v1.5.md` | **全專案文件唯一索引**（狀態、版本、里程碑對照），新增/更新文件時同步維護 |
| `README.md` | 專案介紹、編譯方式、結構說明 |
| `ARCHITECTURE.md` | 模組設計、SwiftData schema、解析器一覽 |
| `CHANGELOG.md` | 版本異動紀錄 |
| `V1_RELEASE_CHECKLIST.md` | **上線前驗證清單**（逐項確認） |
| `logbook/privacy.md` | 隱私政策正文（EN / 繁中 / 日文），同時為 GitHub Pages 線上版本的唯一來源 |
| `UI_UX_SPEC.md` | UI/UX 規格 |
| `WCAG_2.1_AA_AUDIT_CHECKLIST.md` | 可達性合規查核表 |
| `Docs/ADMOB_IAP_SETUP.md` | AdMob App ID / Ad Unit ID / IAP 設定 |
| `Docs/LOCALIZATION_GUIDE.md` | 多語系維護流程、用詞規範 |
| `Docs/KNOWN_ISSUES.md` | 已知問題、技術雷區、v1.1 規劃 |

---

## 重要慣例

- **勿手動腳本編輯 `project.pbxproj`**
- `fileSystemSynchronizedGroups`：新增/刪除 `.swift` 自動進出 build
- `git index.lock` 殘留：`rm -f .git/index.lock .git/HEAD.lock`（在 Mac 端執行）
- 改 code 後先停下，等 PM build 確認再 commit
- 雙平台改動需明確標註
- Settings 頁「Developer Tools」區塊（Inject Mock Dives / Clear All Dives / Simulate Premium）包在 `#if DEBUG`，Release build 不會出現，不需移除

## SwiftData 雷區

- `buddy` 欄位已移除，模擬器舊資料需 Erase All Content
- 未來 schema 變更需處理 migration

---

## 下次發布流程

1. 改 code，commit
2. `CURRENT_PROJECT_VERSION` +1（下次應改為 3）
3. Xcode → Product → Archive（iOS 選 Any iOS Device，macOS 選 Any Mac）
4. Distribute App → App Store Connect
5. App Store Connect → 對應版本頁面 → Add Build → Add for Review

**Export Compliance**：每次上傳都選 **None of the algorithms mentioned above**（app 只用 Apple HTTPS）

---

## Xcode 專案位置

```
JD2-Logbook/JD2-Logbook/JD2-Logbook.xcodeproj
```

---

## v1.0 提審完成事項（2026-06-17 完成）

- W-8BEN 稅務表格填寫完成（Taiwan，Article 12，10% withholding）
- Paid Apps Agreement 簽署完成
- IAP 建立：`com.jd2logbook.premium`，Non-Consumable，$1.99 Remove Ads
- iOS Build 2 上傳（iPhone only，`TARGETED_DEVICE_FAMILY = "1"`）
- macOS Build 2 上傳（含 `LSApplicationCategoryType = public.app-category.sports-games`）
- iOS + macOS 均已 Add for Review

## v1.0 上線後待辦

- 真機驗證 AdMob 廣告（Logbook / Import / Settings）
- 真機驗證 IAP 購買流程（$1.99 Remove Ads）
- 真機驗證 Restore Purchase
- 詳細 backlog 見 `V1_1_BACKLOG.md`

## Git Remote

```
https://github.com/kwh66tw-art/JoyDive.git
```
（注意：GitHub repo 名稱是 `JoyDive`，不是 `JD2-Logbook`）
