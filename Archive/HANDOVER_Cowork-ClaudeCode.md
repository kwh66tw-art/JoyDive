# JoyDive² 交接文件

**交接日期**：2026-07-04  
**接手角色**：Claude Code（維護 / 更新 / 未來版本發布）

---

## 專案基本資料

| 項目 | 值 |
|------|-----|
| App 名稱 | JoyDive²（JD2-Logbook） |
| Bundle ID | com.jd2logbook.JD2-Logbook |
| 平台 | iOS 17.0+ / macOS 14.0+，Swift 6 |
| Xcode 專案 | `JD2-Logbook/JD2-Logbook.xcodeproj` |
| GitHub | https://github.com/kwh66tw-art/JoyDive.git |
| 最新 commit | `d54966b` |
| Apple Team | HUA SHENG Huang（77UHM3NN7J） |

---

## 目前狀態（2026-07-04）

- **macOS App 1.0** ✅ 審核通過
- **iOS App 1.0** ⏳ Waiting for Review
- **Build**：iOS + macOS 均為 Build 2（Version 1.0，Build Number 2）
- **IAP**：`com.jd2logbook.premium`，Non-Consumable，$1.99，已隨版本送審

---

## 上線後第一件事

iOS 審核通過後，在真機上驗證：
1. AdMob 廣告正常顯示（Logbook 列表頁、Import 頁、Settings 頁）
2. IAP 購買流程（$1.99 Remove Ads）完整可用
3. Restore Purchase 可恢復

---

## 關鍵技術細節

### Build 設定（project.pbxproj）
- `TARGETED_DEVICE_FAMILY = "1"` — iPhone only（不支援 iPad）
- `CURRENT_PROJECT_VERSION = 2` — 下次發布需改為 3
- iOS Deployment Target：17.0
- macOS Deployment Target：14.0

### AdMob
- App ID（iOS）：`ca-app-pub-9582822701117167~2224926394`（Info.plist）
- Ad Unit ID 等詳見 `Docs/ADMOB_IAP_SETUP.md`

### IAP
- Product ID：`com.jd2logbook.premium`
- 類型：Non-Consumable
- 價格：$1.99（Tier 2）

### Info.plist（macOS）
- `LSApplicationCategoryType`：`public.app-category.sports-games`
- 這個 key 是 macOS App Store 必要欄位，iOS 不需要

### Debug-only 功能
- Settings 頁的「Developer Tools」區塊（Inject Mock Dives / Clear All Dives / Simulate Premium）包在 `#if DEBUG`，Release build 不會出現，不需移除

---

## 下次發布流程

1. 改 code，commit
2. `CURRENT_PROJECT_VERSION` +1（下次應改為 3）
3. Xcode → Product → Archive（iOS 選 Any iOS Device，macOS 選 Any Mac）
4. Distribute App → App Store Connect
5. App Store Connect → 對應版本頁面 → Add Build → Add for Review

### Export Compliance
每次上傳都選 **None of the algorithms mentioned above**（app 只用 Apple HTTPS）

---

## 重要文件索引

| 文件 | 內容 |
|------|------|
| `CLAUDE.md` | 專案慣例、雷區、架構快速索引 |
| `ARCHITECTURE.md` | 模組設計、SwiftData schema |
| `CHANGELOG.md` | 版本紀錄 |
| `V1_RELEASE_CHECKLIST.md` | v1.0 驗證清單 |
| `Docs/ADMOB_IAP_SETUP.md` | AdMob / IAP 設定細節 |
| `Docs/KNOWN_ISSUES.md` | 已知問題 / v1.1 規劃 |

---

## Git 注意事項

- Remote：`https://github.com/kwh66tw-art/JoyDive.git`（repo 名是 `JoyDive`，非 `JD2-Logbook`）
- 目前 branch：`main`
- Push 前確認在專案目錄內再執行 `git push`
