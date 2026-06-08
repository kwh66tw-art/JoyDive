# CLAUDE.md — JD2-Logbook 工作指引

> Claude agent 接手前必讀。快速定位專案狀態與文件。

---

## 現況速覽

- **狀態**：可編譯可執行，AdMob 已接入，v1.0 待上線
- **目標上線**：2026 年 8 月 18 日
- **平台**：iOS 17.0+ / macOS 14.0+，Swift 6
- **最新 commit**：`4175638` — chore: remove PRIVACY_POLICY.md (consolidated into logbook/privacy.md)

---

## 關鍵文件

| 文件 | 用途 |
|------|------|
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

## SwiftData 雷區

- `buddy` 欄位已移除，模擬器舊資料需 Erase All Content
- 未來 schema 變更需處理 migration

---

## Xcode 專案位置

```
JD2-Logbook/JD2-Logbook/JD2-Logbook.xcodeproj
```

---

## v1.0 待辦（截至 2026-06-08）

詳見 `V1_RELEASE_CHECKLIST.md`。主要剩：
- App Store Connect 審核通過後建立 IAP 產品（Product ID：`com.jd2logbook.premium`）
- 真機測試 AdMob 廣告顯示
- IAP 購買流程真機驗證
- App Store Connect 提審準備（截圖、填寫欄位）
- 詳細 backlog 見 `V1_1_BACKLOG.md`
