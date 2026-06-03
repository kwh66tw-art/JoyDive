# 多語系維護指南

**支援語言**：18 種

| # | 語言 | Locale |
|---|------|--------|
| 1 | 繁體中文 | `zh-Hant` |
| 2 | 簡體中文 | `zh-Hans` |
| 3 | 英文 | `en` |
| 4 | 英國英文 | `en-GB` |
| 5 | 日文 | `ja` |
| 6 | 韓文 | `ko` |
| 7 | 法文 | `fr` |
| 8 | 德文 | `de` |
| 9 | 西班牙文 | `es` |
| 10 | 義大利文 | `it` |
| 11 | 荷蘭文 | `nl` |
| 12 | 葡萄牙文（歐洲） | `pt-PT` |
| 13 | 印尼文 | `id` |
| 14 | 馬來文 | `ms` |
| 15 | 越南文 | `vi` |
| 16 | 泰文 | `th` |
| 17 | 希臘文 | `el` |
| 18 | 克羅埃西亞文 | `hr` |

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
3. 填寫各語言翻譯值

---

## Key 命名規則

- 使用英文原文作為 key（`"Max Depth"`），避免使用縮寫代號
- **空字串問題**：不可使用 `Text("")`，必須改用 `Text(verbatim: "")` 以避免產生空 key（已知 bug 的根治方式）
- NavigationTitle 空字串同理：`navigationTitle(Text(verbatim: ""))`

---

## 用詞規範（中文）

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

## 新增第 19 種語言

1. Xcode → Project → Info → Localizations → `+`
2. 選擇新語言，Xcode 自動在 `Localizable.xcstrings` 新增語言欄
3. 逐一翻譯所有 key（可使用 Xcode 翻譯匯出/匯入 XLIFF 功能）

---

## WCAG 驗證重點

- 18 種語言各抽樣驗證 UI 文字不截斷（尤其德文字串較長）
- 泰文（`th`）、越南文（`vi`）注意字元高度，確認行高不截字
- 目前無 RTL 語言（阿拉伯文、希伯來文），無需 RTL 佈局處理

---

## 備份紀錄

`Archive/JD2-Logbook_i18n_review_V7.2.csv` — V7.2 校訂版對照表（234 行）
