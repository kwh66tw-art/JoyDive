# 多語系維護指南

**支援語言**：繁體中文（`zh-Hant`）、簡體中文（`zh-Hans`）、英文（`en`）

---

## 使用 String Catalog

本專案使用 **Xcode String Catalog**（`Localizable.xcstrings`），位於：

```
JD2-Logbook/JD2-Logbook/Localizable.xcstrings
```

---

## 新增翻譯字串

### 方式一：在 Swift 程式碼直接使用

```swift
// 自動加入 String Catalog（Xcode 會掃描並提示）
Text("Dive Logbook")
Text("Max Depth")
```

### 方式二：手動在 Xcode 編輯

1. 開啟 `Localizable.xcstrings`
2. 點選 `+` 新增 key
3. 分別填寫三個語言的翻譯值

---

## Key 命名規則

- 使用英文原文作為 key（`"Max Depth"`），避免使用縮寫代號
- **空字串問題**：不可使用 `Text("")`，必須改用 `Text(verbatim: "")` 以避免產生空 key（已知 bug 的根治方式）
- NavigationTitle 空字串同理：`navigationTitle(Text(verbatim: ""))`

---

## 用詞規範

| 概念 | 繁體中文 | 簡體中文 | 英文 |
|------|---------|---------|------|
| 潛水日誌 | 潛水日誌 | 潜水日志 | Dive Logbook |
| 最大深度 | 最大深度 | 最大深度 | Max Depth |
| 氣體混合 | 氣體混合 | 气体混合 | Gas Mix |
| 高氧 | 高氧 | 富氧 | Enriched Air / Nitrox |
| 匯入 | 匯入 | 导入 | Import |
| 設定 | 設定 | 设置 | Settings |

---

## 語言切換方式

本 App 使用 **iOS 系統語言設定**（App Language per-app setting，iOS 13+），不在 App 內自行實作切換。

Settings → App Language 入口已在 `SettingsView` 中實作：

```swift
Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
    Label("App Language", systemImage: "globe")
}
```

---

## 新增第四種語言

1. Xcode → Project → Info → Localizations → `+`
2. 選擇新語言，Xcode 自動在 `Localizable.xcstrings` 新增語言欄
3. 逐一翻譯所有 key（可使用 Xcode 的翻譯匯出/匯入 XLIFF 功能）

---

## 備份紀錄

`Archive/JD2-Logbook_i18n_review_V7.2.csv` — V7.2 校訂版對照表（234 行）
