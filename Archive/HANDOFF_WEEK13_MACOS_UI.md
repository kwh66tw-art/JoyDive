# 交接文件：Week 13 macOS UI 修正（未完成）

**對話串日期**：2026-05-24  
**交接原因**：本對話串耗時過長、Token 消耗過多，實質產出僅完成 A-F 六項修改，尚有大量 UI 問題待修，移交新對話串執行。

---

## ⚠️ 待執行的 Git Commit（請在終端機手動操作）

本對話串的 sandbox 因 index.lock 無法執行 commit，請你自行操作：

```bash
cd ~/Documents/Claude/Projects/JD2-Logbook

# 清除 lock（若存在）
rm -f .git/index.lock

# Stage 本次修改（A-F 已部分 staged，其餘視需要補上）
git add JD2-Logbook/JD2-Logbook/Views/MainTabView.swift
git add JD2-Logbook/JD2-Logbook/Views/Logbook/DiveCalendarView.swift
git add JD2-Logbook/JD2-Logbook/Views/Logbook/DiveLogListView.swift

git commit -m "fix(macOS): Week13 A-F UI layout — inline search, calendar callback, year/month picker, empty state, HSplitView custom header"
```

---

## ✅ 本對話串已完成的修改（A-F）

| 項目 | 說明 | 檔案 |
|------|------|------|
| A | 修 MacLogbookSplitView 雙重空狀態 — 加 @Query dives，空時顯示單一 ContentUnavailableView | MainTabView.swift |
| B | 移除左欄 NavigationStack，改自訂 VStack + HStack header | MainTabView.swift |
| C | DiveLogListView macOS 搜尋列改內嵌 HStack（移除 .searchable toolbar） | DiveLogListView.swift |
| D | DiveCalendarView 點選日期自動同步右側 onDiveTapped（macOS） | DiveCalendarView.swift |
| E | DiveLogDetailView toolbar 右欄加 `.frame(minWidth: 300)` | MainTabView.swift |
| F | DiveCalendarView macOS 加年/月快速跳選 Picker（yearBinding + monthBinding） | DiveCalendarView.swift |

---

## ❌ 尚未修正的問題（新對話串接手）

以下問題均已完成根因分析與對應 Diff，參考稽核報告直接執行即可。

### 圖 1：空狀態 VStack 懸浮置中（未頂天）
- **根因**：VStack 無 frame 約束，被 NavigationSplitView detail 欄置中
- **修法**：稽核報告 Diff A（若採 Diff B 則此項自動解決，不需另外處理）

### 圖 3 + 4：Settings 頂部大空白 & 日誌左欄頂部空白
- **根因**：Nested Navigation Inset — 左欄無 NavigationStack、右欄有，造成頂部高度不對稱
- **修法**：稽核報告 **Diff B（最優先）**— 雙導航對稱對齊
  - 左欄包 NavigationStack + `.navigationTitle("Dive Logbook")` + `.toolbar` 放切換/新增按鈕
  - 右欄保留 NavigationStack + `.navigationTitle("")`（空標題確保高度對稱）
  - 空狀態改用 `NavigationStack { ContentUnavailableView }` + `.toolbar`
  - ⚠️ Build 後需截圖確認左欄工具列按鈕與右欄 Edit/Export 按鈕是否都正常顯示

### Settings 頂部補丁（配合 Diff B 一起做）
- **修法**：稽核報告 **Diff D** — SettingsView settingsForm 加 `.formStyle(.grouped).padding(.top, -16)`（macOS only）

### 圖 7：選取框過大 + 藍色 Focus Ring
- **根因**：`.listStyle(.plain)` + 手動 `.listRowBackground` 衝突
- **修法**：稽核報告 **P1** — 改 `.listStyle(.sidebar)`，移除 `.listRowBackground`，列表行加 `.focusable(false)`

### 月曆右側清空失效（切換日期右側不更新）
- **根因**：`onDiveTapped` 簽章為 `(DiveLog) -> Void`，不接受 nil，取消選取時無法清空右側
- **修法**：稽核報告 **Diff C**
  - `DiveCalendarView.onDiveTapped` 改為 `((DiveLog?) -> Void)?`
  - onTapGesture 補上 else 分支：無潛水日期 / 取消選取 → `onDiveTapped?(nil)`
  - `MacLogbookSplitView` 的 callback 無需改動（`selectedDive = dive` 直接接受 `DiveLog?`）

### iOS Calendar 無年月快速跳選
- **修法**：稽核報告 **P2** — 月份標題包 `Menu { yearPicker + monthPicker }`（iOS only）

---

## 📋 稽核報告位置

```
~/Documents/Claude/Projects/JD2-Logbook/ui_ux_audit_report.md
```

**版本**：v3.1（終極版，已整合開發團隊的 Toolbar propagation 風險反饋）

報告包含：
- 每個問題的根因分析
- 精確的 `<<<<` / `====` / `>>>>` diff 格式代碼，可直接對位貼入
- 執行優先順序建議

---

## 🗺️ 地圖模組（Task G，獨立任務，未開始）

稽核報告第六節有完整設計方案：

1. **MapCameraAction 消耗式架構**：
   ```swift
   enum MapCameraAction: Equatable { case recenter; case compassNorth }
   ```
   `DiveMapRepresentable` 加 `@Binding var cameraAction: MapCameraAction?`，執行後設為 nil

2. **macOS**：放棄 Modal/Popover，改用 HSplitView 右側固定寬度 300pt 側邊欄

3. **iOS**：懸浮按鈕高度改用 `GeometryReader` 動態計算，取代 magic number `.padding(.bottom, 280)`

---

## 執行建議給新對話串

1. 先閱讀 `ui_ux_audit_report.md`（v3.1）全文
2. 依序執行：**Diff B → Diff C → Diff D → P1 → P2**
3. 每個 Diff 執行後停下來，等 PM build 確認截圖，再繼續下一個
4. Diff B 執行後重點截圖：左欄「切換/新增」按鈕 + 右欄「Edit/Export」按鈕是否都顯示正常
5. Task G（地圖按鈕）另立獨立開發任務

---

## 其他未 commit 的變更（本對話串之前遺留）

以下檔案有未 commit 的修改，與本次 UI 修正無關，新對話串視情況處理：

- `Localizable.xcstrings` — i18n 相關
- `ImportWizardView.swift`
- `DiveLogDetailView.swift`
- `DiveLogEditSheet.swift`
- `MapView.swift`
- `SettingsView.swift`
- `AdBannerView.swift`
- `DiveLogImporter.swift`
- `DiveLog.swift`
- 刪除的測試檔：`TestFiles/CSV/test41.csv`、`TestFiles/Suunto/*.json` x3
