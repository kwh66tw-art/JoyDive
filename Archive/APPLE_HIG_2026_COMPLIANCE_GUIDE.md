# Apple HIG 2026 合規指南
## JD2-Logbook 所有 UI/UX 開發須遵循

**最後更新**: 2026 年 5 月 17 日  
**適用版本**: iOS 18 & macOS 15+  
**合規等級**: WCAG 2.1 AA (法規要求)

---

## 1. 架構標準 (Architecture Standards)

### ✅ 必須使用
- **NavigationStack + Router 模式** (2026 iOS 標準)
  - 不再使用 NavigationView (已棄用)
  - 使用 enum 驅動的路由狀態管理
  - 例: `enum DiveLogRoute { case logList, logDetail(DiveLog), importWizard }`

- **環境物件 (@Environment, @StateObject)** 管理全域狀態
  - 數據層與 UI 層分離
  - 支援深層連結 (deep linking)

### ❌ 禁止使用
- NavigationView (已棄用，iOS 16+)
- LazyVStack 不配合 GeometryReader (可能導致性能問題)
- 硬編碼的顏色常數 (必須使用 Color.accentColor 等動態顏色)

---

## 2. 顏色與對比 (Color & Contrast)

### WCAG 2.1 AA 最低要求
- **一般文本**: 4.5:1 對比比
- **大文本** (18pt+ 或 14pt+ bold): 3:1 對比比
- **互動元素邊框**: 3:1 對比比

### ✅ 實現方式
```swift
// 使用系統提供的語義顏色
Text("潛水深度")
    .foregroundColor(.primary)  // 自動適應 Light/Dark 模式
    
// 檢查對比度工具：
// https://webaim.org/resources/contrastchecker/
```

### 必須測試的場景
- [ ] Light Mode 完整對比度驗證
- [ ] Dark Mode 完整對比度驗證
- [ ] High Contrast Mode (輔助功能) 文本可讀性
- [ ] 彩色盲人模式模擬 (Simulator → Features → Color Filters)

### Dark Mode 支援
- 所有顏色必須在 Light + Dark Mode 下驗證
- 使用 `ColorSet` (不是硬編碼的 RGB)
- 避免使用純黑 (#000000)、純白 (#FFFFFF)

---

## 3. 無障礙 / VoiceOver (Accessibility)

### WCAG 2.1 AA 要求

#### 3.1 標籤 (Labels)
```swift
// ✅ 好的做法
Button(action: { addDive() }) {
    Image(systemName: "plus.circle")
}
.accessibilityLabel("新增潛水日誌")
.accessibilityHint("雙擊以建立新的潛水記錄")

// ❌ 不好的做法
Button(action: { addDive() }) {
    Image(systemName: "plus.circle")
}
// 沒有 accessibilityLabel，VoiceOver 無法讀出
```

**應用規則**:
- 每個互動元素 (Button, Link, TextField) **必須有** `accessibilityLabel`
- 複雜互動需要 `accessibilityHint`
- 重複元素可使用 `accessibilityIdentifier` 區分

#### 3.2 結構與順序 (Structure & Order)
```swift
// ✅ 使用語義化 HTML 結構等同物
VStack {
    // 標題應該第一個讀出
    Text("潛水日誌")
        .font(.title)
        .accessibilityAddTraits(.isHeader)
    
    // 列表項目按邏輯順序
    ForEach(dives) { dive in
        DiveRow(dive: dive)
    }
}
.accessibilityElement(children: .combine)  // 將 VStack 視為單一元素
```

#### 3.3 顏色不是唯一表達方式
```swift
// ❌ 不好的做法 - 僅用顏色表達狀態
if isConnected {
    Circle()
        .fill(Color.green)  // 色盲者無法區分
}

// ✅ 好的做法 - 文字 + 圖標 + 顏色
if isConnected {
    HStack(spacing: 8) {
        Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
        Text("已連接")
    }
    .accessibilityLabel("裝置已連接")
}
```

#### 3.4 動畫與過渡
```swift
// ✅ 遵守 prefersReducedMotion 使用者偏好
@Environment(\.accessibilityReduceMotion) var reduceMotion

.withAnimation(reduceMotion ? nil : .easeInOut)
```

#### 3.5 對焦順序 (Focus Order)
```swift
// 明確定義焦點順序
VStack {
    TextField("日誌標題", text: $title)
        .accessibilityFocused($focusedField, equals: .title)
    
    TextField("位置", text: $location)
        .accessibilityFocused($focusedField, equals: .location)
}
```

---

## 4. 觸控目標 & 點擊區域 (Touch Targets)

### 最小尺寸
- **44×44 點** (iOS 標準)
- macOS: 最少 16×16 (建議 24×24)

```swift
// ✅ 充足的觸控目標
Button(action: { /* ... */ }) {
    Image(systemName: "plus")
        .font(.title2)
}
.frame(minWidth: 44, minHeight: 44)  // 明確設定

// ❌ 太小的觸控目標
Button(action: { /* ... */ }) {
    Image(systemName: "x.small")  // 16×16，太小
}
```

### 間距
- 多個按鈕之間至少 8pt 間距
- 避免相鄰按鈕誤觸

```swift
HStack(spacing: 12) {  // 至少 8pt
    Button("取消") { /* ... */ }
        .frame(minHeight: 44)
    
    Button("確認") { /* ... */ }
        .frame(minHeight: 44)
}
```

---

## 5. 動態類型 (Dynamic Type)

### 支援所有文本尺寸 (xSmall → xxxLarge)

```swift
// ✅ 使用語義化字體尺寸
Text("潛水深度")
    .font(.body)  // 自動按 Dynamic Type 調整

Text("標題")
    .font(.title)  // xSmall ~ xxxLarge 自動調整

// ❌ 硬編碼尺寸
Text("潛水深度")
    .font(.system(size: 17))  // 不會隨 Dynamic Type 改變

// ✅ 自訂但仍支援 Dynamic Type
Text("潛水深度")
    .font(.system(size: 17, weight: .semibold, design: .default))
    .dynamicallyScaledFont(baseSize: 17)
```

### 測試方法
1. Simulator → Settings → Accessibility → Display & Text Size
2. 測試 xSmall, Small, Medium, Large, extraLarge, xxxLarge
3. 確認文本不被截斷，版面不重疊

---

## 6. Safe Area & Dynamic Island (iOS 18)

```swift
// ✅ 使用 SafeAreaInsets
VStack {
    DiveListView()
}
.ignoresSafeArea(edges: [])  // 預設尊重 Safe Area

// ✅ 處理 Dynamic Island (iPhone 14+)
.safeAreaInset(edge: .top) {
    // 如果有自訂標題欄，應該在 Safe Area 內
}

// ❌ 忽視 Safe Area (可能被 Dynamic Island/notch 遮擋)
VStack {
    Image("background")
        .ignoresSafeArea()  // 危險！
}
```

### Dynamic Island 考量
- 避免在 Dynamic Island 區域放置關鍵 UI
- Activity 更新應該非阻塞式
- Lock Screen Widget 尺寸: 170×170 (小) 或 340×170 (中)

---

## 7. Dark Mode 完整實現

### 色彩集定義 (Asset Catalog)
```swift
// 在 Assets.xcassets 中建立 ColorSet:
// 1. 設定 "Appearance" = "Any, Dark"
// 2. Light 版本色彩
// 3. Dark 版本色彩

Color("DiveLogBackground")  // 自動適應

// ✅ 或程式化定義
Color(
    light: Color(red: 1.0, green: 1.0, blue: 1.0),
    dark: Color(red: 0.11, green: 0.11, blue: 0.12)
)
```

### 測試 Dark Mode
1. Simulator → Apperance → Dark
2. 驗證所有文本、按鈕、圖標可見且美觀
3. 圖片不應該在 Dark Mode 中變成全黑或全白

---

## 8. 多語言 & 區域設定 (i18n/L10n)

### String Catalog (推薦 Xcode 15+)
```swift
// ✅ 使用 String Catalog (自動收集待翻譯字符串)
Text("新增潛水")  // 自動加入 String Catalog

// 或傳統方式
Text("Add Dive")  // 會尋找 Localizable.strings
```

### 必須本地化的元素
- [ ] 所有使用者可見的文本 (UI 標籤、按鈕、訊息)
- [ ] 日期格式 (使用 DateFormatter，遵守地區設定)
- [ ] 時間格式 (24h vs 12h，取決於地區)
- [ ] 數字格式 (千位分隔符、小數點)
- [ ] 貨幣 ($1.99 USD, ¥ NT$1,999)

```swift
// ✅ 日期本地化
let formatter = DateFormatter()
formatter.dateStyle = .medium
formatter.timeStyle = .short
formatter.locale = Locale.current  // 自動使用系統語言

Text(formatter.string(from: dive.date))

// ✅ 數字本地化
let formatter = NumberFormatter()
formatter.locale = Locale.current
Text(formatter.string(from: NSNumber(value: depth)) ?? "")
```

### 繁體中文、簡體中文、英文
- [ ] 繁中: `zh-Hant` (台灣: `zh-Hant_TW`)
- [ ] 簡中: `zh-Hans` (中國: `zh-Hans_CN`)
- [ ] 英文: `en` (美國: `en_US`)

---

## 9. iOS 18 新功能整合

### 9.1 Control Center (WidgetKit)
```swift
// ✅ Control Center 按鈕：快速存取潛水日誌
struct LogDiveControlWidget: ControlWidgetConfiguration {
    var body: some ControlWidgetConfiguration {
        StaticControlWidgetConfiguration(
            kind: "com.jd2logbook.logdive",
            provider: LogDiveProvider()
        ) { state in
            ControlWidgetButton(action: LogDiveIntent()) {
                Label("記錄潛水", systemImage: "diver.hand.raised")
            }
        }
    }
}
```

### 9.2 Lock Screen Widgets
```swift
// ✅ Lock Screen 顯示最近潛水
struct DiveLogLockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "com.jd2logbook.lockscreen",
            provider: DiveProvider()
        ) { entry in
            VStack(alignment: .leading) {
                Text("最近潛水")
                    .font(.caption)
                Text(entry.dive.location)
                    .font(.body)
                    .fontWeight(.semibold)
            }
            .containerBackground(.fill.secondary, for: .lock)
        }
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}
```

### 9.3 Home Screen Icon Variants
```swift
// ✅ 提供 light/dark/tinted 圖示變體
// 在 Assets.xcassets 建立 App Icon Set，選擇:
// - Monochrome (用於 tinted)
// - Multicolor (用於 light/dark)

// Assets 結構:
// AppIcon-light.png (1024×1024)
// AppIcon-dark.png (1024×1024)  
// AppIcon-tinted.png (1024×1024, 單色)
```

---

## 10. 性能與可靠性

### ✅ UI 相應性
- 主執行緒操作 < 16ms (60fps)
- 列表滑動應該平順無卡頓

```swift
// ✅ 避免在 UI 執行緒進行重工作
@State var dives: [DiveLog] = []

func loadDives() {
    Task {
        let result = await fetchDivesAsync()  // 背景執行
        await MainActor.run {
            self.dives = result  // UI 更新
        }
    }
}
```

### ✅ 記憶體管理
- SwiftUI 視圖應該是輕量級的
- 大列表使用 LazyVStack 或 List
- 圖片應該縮放適當尺寸 (不在記憶體中存儲 4K 圖片)

### ✅ 電池消耗
- GPS 追蹤應該可控 (精度 vs 電池)
- 地圖更新應該節流 (不要每幀都更新)
- 背景作業應該使用 BackgroundTasks 框架

---

## 11. Week 9-11 UI 生成提示詞範本

每次生成 UI 時，將以下內容加入 Claude Code 提示詞：

```
【Apple HIG 2026 要求】
- NavigationStack + Router 模式，不使用 NavigationView
- 色彩對比: 4.5:1 (正常文本) / 3:1 (大文本)
- 所有互動元素 accessibilityLabel + 必要時 accessibilityHint
- 觸控目標最小 44×44pt，間距 ≥ 8pt
- 支援 Dynamic Type (xSmall ~ xxxLarge)
- Dark Mode 完整支援
- 多語言本地化 (繁中、簡中、英文)
- SafeArea + Dynamic Island 考量
- WCAG 2.1 AA 可達性合規

【iOS 18 新功能】
- Control Center 快速存取 (Week 11)
- Lock Screen Widget 整合 (Week 11)
- Home Screen 圖示三版本 (light/dark/tinted) (Week 11)

【性能要求】
- 列表滑動 60fps
- 地圖聚類運算 < 200ms
- 記憶體使用 < 150MB

【測試驗證】
- 在 Light/Dark Mode 下驗證
- VoiceOver 可讀性測試
- 對比度檢查工具驗證
- Dynamic Type 尺寸範圍測試
```

---

## 12. Week 12 WCAG 2.1 AA 最終審核清單

| 項目 | 檢查方式 | 通過標準 |
|------|--------|--------|
| **色彩對比** | WebAIM Contrast Checker | 4.5:1 (文本) / 3:1 (大文本/邊框) |
| **VoiceOver** | Simulator → Accessibility → VoiceOver | 每個互動元素有 label，流程清晰 |
| **觸控目標** | 檢查 Button/Link 尺寸 | ≥ 44×44pt |
| **Dynamic Type** | 設定 xSmall/xxxLarge，驗證版面 | 文本不截斷，版面不重疊 |
| **Dark Mode** | 切換到 Dark，全面驗證 | 所有元素可見，美觀 |
| **多語言** | 切換語言，驗證日期/時間/數字 | 格式正確，文本完整 |
| **SafeArea** | 檢查 notch/Dynamic Island | 關鍵 UI 未被遮擋 |
| **KeyBoard** | iPad + Magic Keyboard | Tab 順序邏輯，焦點明確 |
| **縮放模式** | 200% 放大測試 | 版面不破損，文本可讀 |
| **減少動畫** | 啟用 prefersReducedMotion | 動畫被禁用或改為靜態過渡 |

---

## 13. 參考資源

### Apple 官方文檔
- [iOS 18 Design Guide](https://developer.apple.com/design/ios)
- [Accessibility for iOS](https://developer.apple.com/accessibility/ios/)
- [WCAG 2.1 標準](https://www.w3.org/WAI/WCAG21/quickref/)

### 測試工具
- **Simulator Accessibility Inspector**: Cmd+Option+Z
- **Contrast Checker**: https://webaim.org/resources/contrastchecker/
- **Color Filter Simulator**: Accessibility → Display & Text Size → Color Filters
- **VoiceOver**: Cmd+F5 (Mac) 或 Settings → Accessibility → VoiceOver (iOS)

### 設計工具
- **Apple Design Resources**: https://developer.apple.com/design/resources/
- **SF Symbols**: 3,000+ 官方圖標

---

**維護者**: Claude Code Agent  
**最後驗證日期**: 2026 年 5 月 17 日  
**下次審核**: v1.0.1 規劃時
