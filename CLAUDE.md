# CLAUDE.md — JD2-Logbook 工作指引

> Claude agent 接手前必讀。快速定位專案狀態與文件。

---

## 現況速覽

- **狀態**：v1.0 已提審 App Store（iOS + macOS）
- **目標上線**：2026 年 8 月 18 日
- **平台**：iOS 17.0+ / macOS 14.0+，Swift 6
- **Bundle ID**：`com.jd2logbook.JD2-Logbook`
- **Apple Team**：HUA SHENG Huang（77UHM3NN7J）
- **最新 commit**：`d54966b` — chore(release): iPhone-only build, bump build number to 2, add macOS LSApplicationCategoryType

### 審核狀態（截至 2026-07-04）
- **macOS App 1.0**：✅ 已通過審核
- **iOS App 1.0**：⏳ Waiting for Review
- **Build**：iOS + macOS 均為 Build 2（`CURRENT_PROJECT_VERSION = 2`；下次發布需 +1 → 3）
- **IAP**：`com.jd2logbook.premium`，Non-Consumable，$1.99，已隨版本送審

---

## 關鍵文件

| 文件 | 用途 |
|------|------|
| `JD2-Logbook_文件登錄表_v1.3.md` | **全專案文件唯一索引**（狀態、版本、里程碑對照），新增/更新文件時同步維護 |
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
