# Week 1 詳細執行計劃
## 基礎搭建（2026 年 5 月 19-24 日）

**目標**: 建立可編譯的應用框架，為後續解析器開發做準備  
**PM 投入**: 6 小時（每日 1 小時，連續 6 天）  
**交付物**: 可編譯的 Xcode 專案 + 解析器架構

---

## 每日執行計劃

### **Day 1（5 月 19 日，週一）- Xcode 初始化**

**主題**: 項目環境準備  
**PM 時間**: 1 小時  
**時段建議**: 早上 8:00-9:00（開啟新的一週）

#### 任務清單

| 序號 | 任務 | 負責 | 時數 | 交付物 |
|------|------|------|------|--------|
| 1-1 | 確認項目 Git 倉庫位置 & 分支 | PM | 0.1h | GitHub 倉庫確認 |
| 1-2 | Xcode 新建 iOS 專案（Swift, SwiftUI）| PM | 0.2h | Xcode 專案檔案 |
| 1-3 | 設定 iOS 部署目標 (iOS 16.0+) | PM | 0.1h | Build Settings 確認 |
| 1-4 | 初始化 SPM (Swift Package Manager) | Claude | 0.2h | Package.swift |
| 1-5 | 添加必要的 SPM 依賴 | Claude | 0.2h | ZipFoundation, 其他庫 |
| 1-6 | 第一次 `swift build` 驗證 | PM | 0.2h | 編譯通過確認 |

#### 具體步驟

```bash
# PM 操作（在 Xcode 中）

1. File → New → Project
   ├─ iOS App
   ├─ Language: Swift
   ├─ Interface: SwiftUI
   └─ Save: ~/Projects/JD2-Logbook-Dev

2. 設定 Build Settings
   ├─ Minimum Deployment: iOS 16.0
   ├─ Team ID: [你的 Apple Team ID]
   └─ Bundle Identifier: com.joydive.jd2logbook

3. 初始化 Git
   ├─ cd ~/Projects/JD2-Logbook-Dev
   ├─ git init
   ├─ git add .
   └─ git commit -m "Initial Xcode project setup"
```

#### Claude 任務：SPM 配置

**Prompt to Claude:**
```
我已在 Xcode 中新建了 JD2-Logbook iOS 專案。
請生成完整的 Package.swift 文件，包含：
1. 基礎 iOS 應用設定
2. ZipFoundation (用於 UDDF ZIP 處理)
3. 未來解析器的 target 定義

項目位置：~/Projects/JD2-Logbook-Dev
目標 iOS: 16.0+
編程語言：Swift
```

**驗證步驟**:
```bash
$ cd ~/Projects/JD2-Logbook-Dev
$ swift build
# 期望：Build complete! (0 errors, 0 warnings)
```

#### Day 1 里程碑檢查 ✅
- [ ] Xcode 專案能打開？
- [ ] `swift build` 成功編譯？
- [ ] Package.swift 存在且有效？
- [ ] Git 倉庫已初始化？

**預期完成時間**: 9:00-10:00 AM ✅

---

### **Day 2（5 月 20 日，週二）- JoyDiveCore 審查與準備**

**主題**: 理解 JoyDiveCore 結構，準備代碼複製清單  
**PM 時間**: 1 小時  
**時段建議**: 早上 8:00-9:00

#### 任務清單

| 序號 | 任務 | 負責 | 時數 | 交付物 |
|------|------|------|------|--------|
| 2-1 | 打開 JoyDiveCore 倉庫，審查目錄結構 | PM | 0.2h | 目錄結構筆記 |
| 2-2 | 識別需要複製的模組 (Models, Constants, Utilities) | PM | 0.2h | 複製清單（20+ 檔案） |
| 2-3 | 識別關鍵資料結構 (DiveLog, GasMix, Environment) | PM | 0.2h | 模型對應表 |
| 2-4 | 生成複製計劃與映射說明 | Claude | 0.2h | copy_plan.md |
| 2-5 | PM 審核複製計劃，確認無遺漏 | PM | 0.2h | 計劃確認 |

#### Claude 任務：複製計劃生成

**Prompt to Claude:**
```
分析 JoyDiveCore 倉庫結構（或根據已知的結構）。
請生成詳細的「複製清單」，包括：

【第一部分：必須複製的檔案】
Models/
├─ DiveLog.swift
├─ GasMix.swift
├─ DiveEnvironment.swift
└─ ... (全部列出)

Constants/
├─ AppConstants.swift
└─ ...

Utilities/
├─ DateFormatter+Extensions.swift
├─ DepthConverter.swift
└─ ...

【第二部分：檔案映射表】
原路徑 → 新路徑
sources/Models/ → JD2Logbook/Models/

【第三部分：導入調整】
所有 import JoyDiveCore → import JD2Logbook

【第四部分：編譯驗證檢查清單】
複製後應檢查的項目清單
```

#### Day 2 里程碑檢查 ✅
- [ ] 識別出所有必須複製的模組？
- [ ] 複製清單完整（20+ 檔案）？
- [ ] 模型對應表清晰？
- [ ] 複製計劃無遺漏？

**預期完成時間**: 9:00-10:00 AM ✅

---

### **Day 3（5 月 21 日，週三）- JoyDiveCore 複製與編譯驗證**

**主題**: 實際複製代碼，第一次編譯驗證  
**PM 時間**: 1 小時  
**時段建議**: 早上 8:00-9:00

#### 任務清單

| 序號 | 任務 | 負責 | 時數 | 交付物 |
|------|------|------|------|--------|
| 3-1 | 建立目錄結構 (Models, Constants, Utilities) | PM | 0.1h | 資料夾建立 |
| 3-2 | 根據清單複製檔案（或 Claude 生成複製腳本）| PM/Claude | 0.2h | 20+ 檔案複製完成 |
| 3-3 | 調整 import 語句（JoyDiveCore → JD2Logbook）| Claude | 0.2h | 所有 import 修正 |
| 3-4 | 第一次 `swift build` 編譯驗證 | PM | 0.2h | 編譯通過或報錯清單 |
| 3-5 | 修復編譯誤 | PM/Claude | 0.2h | 編譯成功 ✅ |

#### Claude 任務：複製腳本生成

**Prompt to Claude:**
```
根據之前的複製清單，請生成一個 bash 腳本。
該腳本應該：
1. 複製 JoyDiveCore 的 Models/, Constants/, Utilities/ 到 JD2Logbook/
2. 自動調整所有 import 語句
3. 報告複製狀態

腳本位置：~/scripts/copy_joydicore.sh
執行：bash ~/scripts/copy_joydicore.sh
```

**執行步驟**:
```bash
$ bash ~/scripts/copy_joydicore.sh
$ cd ~/Projects/JD2-Logbook-Dev
$ swift build
# 期望：編譯成功或明確的錯誤清單
```

#### Day 3 里程碑檢查 ✅
- [ ] 所有必要檔案都複製了？
- [ ] import 語句都修正了？
- [ ] `swift build` 能編譯通過？
- [ ] 無編譯警告？

**預期完成時間**: 9:00-10:00 AM ✅

---

### **Day 4（5 月 22 日，週四）- 多格式解析器架構設計**

**主題**: 設計支援 7 種格式的解析器架構  
**PM 時間**: 1 小時  
**時段建議**: 上午 8:00-9:00

#### 任務清單

| 序號 | 任務 | 負責 | 時數 | 交付物 |
|------|------|------|------|--------|
| 4-1 | PM 確認解析器架構設計（Protocol 模式）| PM | 0.2h | 架構確認 |
| 4-2 | Claude 生成 DiveLogImporter Protocol | Claude | 0.2h | Protocol.swift |
| 4-3 | Claude 生成 DiveLogImportCoordinator | Claude | 0.2h | Coordinator.swift |
| 4-4 | Claude 生成 ImportError enum | Claude | 0.1h | ErrorTypes.swift |
| 4-5 | PM 審核架構，進行編譯驗證 | PM | 0.3h | 編譯通過確認 |

#### Claude 架構設計 Prompt

**Prompt to Claude:**
```
請設計一個支援 7 種潛水日誌格式的統一解析器架構。

【需求】
1. 支援格式：UDDF, SHEARWATER, Peregrine, Cressi, Garmin, Suunto, Oceanic
2. 設計模式：Protocol-based 工廠模式
3. 統一介面：無論哪種格式，都使用同一個 parse() 和 validate() 方法

【輸出】
生成以下 4 個檔案（Swift）：

1. DiveLogImporter.swift - 核心 Protocol
   ├─ func parse(fileURL: URL) throws -> [DiveLog]
   └─ func validate(logs: [DiveLog]) -> ImportValidation

2. DiveLogImportCoordinator.swift - 協調器
   ├─ 檢測檔案格式
   ├─ 選擇正確的解析器
   └─ 統一的匯入流程

3. ImportError.swift - 錯誤類型
   ├─ fileNotFound
   ├─ invalidFormat
   ├─ parsingFailed
   └─ unsupportedFormat

4. ImportValidation.swift - 驗證結果
   ├─ isValid: Bool
   ├─ errors: [String]
   ├─ warnings: [String]
   └─ successCount, failureCount

【關鍵點】
- Protocol 應易於被各解析器實現
- Coordinator 應自動檢測格式（基於副檔名和內容）
- 錯誤處理應詳細（便於 UI 顯示）
- 驗證結果應支援警告和錯誤分開
```

#### Day 4 里程碑檢查 ✅
- [ ] DiveLogImporter Protocol 清晰？
- [ ] Coordinator 邏輯完整？
- [ ] 所有結構都能編譯？
- [ ] 無編譯警告？

**預期完成時間**: 8:00-9:00 AM ✅

---

### **Day 5（5 月 23 日，週五）- SwiftData 模型定義**

**主題**: 定義本地存儲的 DiveLog 資料模型  
**PM 時間**: 1 小時  
**時段建議**: 上午 8:00-9:00

#### 任務清單

| 序號 | 任務 | 負責 | 時數 | 交付物 |
|------|------|------|------|--------|
| 5-1 | PM 確認 DiveLog 擴展欄位（基於 JoyDiveCore） | PM | 0.2h | 欄位清單 |
| 5-2 | Claude 生成 SwiftData @Model DiveLog | Claude | 0.2h | DiveLog.swift |
| 5-3 | Claude 生成 DiveLogDatabase 類別 | Claude | 0.2h | Database.swift |
| 5-4 | Claude 生成簡單 CRUD 方法 | Claude | 0.2h | CRUD 方法 |
| 5-5 | PM 測試 SwiftData 初始化 | PM | 0.2h | 測試通過確認 |

#### Claude SwiftData 設計 Prompt

**Prompt to Claude:**
```
請生成 JD2-Logbook 的 SwiftData 資料層。

【基礎欄位】(來自 JoyDiveCore)
- id: UUID
- diveNumber: Int
- diveDate: Date
- gasMix: GasMix
- environment: DiveEnvironment

【擴展欄位】(Logbook 特定)
- location: String?
- maxDepth: Double
- diveTime: TimeInterval
- waterTemp: Double?
- notes: String?
- photo: Data? (JPEG, max 5MB)
- buddyName: String?
- certificationLevel: String?

【管理欄位】
- isManualEntry: Bool
- importSource: String? ("UDDF", "SHEARWATER" 等)
- lastModified: Date

【輸出】

1. DiveLog.swift - SwiftData 模型
   ├─ @Model 修飾符
   ├─ @Attribute(.unique) id
   ├─ 所有欄位定義
   ├─ 計算屬性 (formattedDate, avgDepth)
   └─ 簡單方法

2. DiveLogDatabase.swift - 存儲層
   ├─ class DiveLogDatabase: ObservableObject
   ├─ @Published @ModelContext
   ├─ func saveDiveLog(_ log: DiveLog)
   ├─ func fetchAllDives() -> [DiveLog]
   ├─ func updateDiveLog(_ log: DiveLog)
   ├─ func deleteDiveLog(_ id: UUID)
   └─ func iCloudSync()

【關鍵需求】
- @Model 必須能被 SwiftUI 視圖使用
- 支援 iCloud 同步（CloudKit 基礎）
- 支援排序與篩選
```

#### Day 5 里程碑檢查 ✅
- [ ] DiveLog @Model 能編譯？
- [ ] 所有欄位都定義了？
- [ ] CRUD 方法完整？
- [ ] SwiftData 初始化無誤？

**預期完成時間**: 8:00-9:00 AM ✅

---

### **Day 6（5 月 24 日，週六）- 初始 UI 框架與最終驗證**

**主題**: 建立基本 UI 框架，完成 Week 1  
**PM 時間**: 1 小時  
**時段建議**: 上午 8:00-9:00

#### 任務清單

| 序號 | 任務 | 負責 | 時數 | 交付物 |
|------|------|------|------|--------|
| 6-1 | Claude 生成 TabView 主框架 | Claude | 0.2h | ContentView.swift |
| 6-2 | Claude 生成 DiveLogListView 骨架 | Claude | 0.2h | List.swift |
| 6-3 | Claude 生成導航結構 | Claude | 0.1h | 導航邏輯 |
| 6-4 | PM 在模擬器中驗證運行 | PM | 0.2h | 運行確認 |
| 6-5 | 最終 Git commit & 里程碑檢查 | PM | 0.2h | Week 1 完成確認 |

#### Claude UI 框架 Prompt

**Prompt to Claude:**
```
生成 JD2-Logbook 的初始 UI 框架（SwiftUI）。

【UI 結構】
TabView (3 個 Tab):
├─ Tab 1: 日誌列表 (DiveLogListView)
├─ Tab 2: 地圖 (MapView - 先放空)
└─ Tab 3: 設定 (SettingsView - 先放空)

【主要視圖】
1. ContentView.swift - App 入口
   ├─ TabView 結構
   ├─ Navigation 整合
   └─ @StateObject DiveLogDatabase

2. DiveLogListView.swift
   ├─ List 顯示所有潛水記錄
   ├─ 日期倒序排列
   ├─ 每行顯示：日期、地點、深度
   ├─ 點選導航到詳情
   └─ 添加 Button 導航到匯入

3. ImportView.swift (先放空)
   └─ 導航占位符

【設計需求】
- 簡潔 UI（目標：一屏完成操作）
- 無需複雜動畫或特效
- 支援 Light/Dark Mode
```

#### 最終驗收清單

```swift
【Week 1 交付物檢查清單】

□ 代碼編譯
  ├─ swift build ✅ (0 errors, 0 warnings)
  ├─ Xcode 運行無誤 ✅
  └─ 模擬器啟動成功 ✅

□ 架構完整
  ├─ DiveLogImporter Protocol ✅
  ├─ DiveLogImportCoordinator ✅
  ├─ ImportError enum ✅
  ├─ ImportValidation struct ✅
  └─ DiveLog SwiftData @Model ✅

□ 數據層
  ├─ DiveLogDatabase 類別 ✅
  ├─ CRUD 方法完整 ✅
  ├─ iCloud 基礎框架 ✅
  └─ 簡單查詢方法 ✅

□ UI 層
  ├─ ContentView (Tab 框架) ✅
  ├─ DiveLogListView (基本) ✅
  ├─ 導航結構 ✅
  └─ 模擬器可運行 ✅

□ Git & 文檔
  ├─ 初始 commit ✅
  ├─ Week 1 分支創建 ✅
  ├─ README 更新 ✅
  └─ 進度記錄 ✅

【里程碑檢查】
□ 應用能否編譯？ → ✅ YES
□ 應用能否在模擬器運行？ → ✅ YES
□ Parser protocol 是否清晰？ → ✅ YES
□ SwiftData 是否正確初始化？ → ✅ YES
□ UI 框架是否可用？ → ✅ YES
```

#### Day 6 最終步驟

```bash
# 在 Xcode 中
1. Product → Build → ✅ 編譯成功
2. Product → Run → 模擬器啟動
3. 驗證 TabView 顯示
4. 驗證 DiveLogListView 可見

# Git 提交
$ git add -A
$ git commit -m "Week 1 Complete: Base architecture & UI framework"
$ git push origin main
```

**預期完成時間**: 8:00-9:00 AM ✅

---

## Week 1 總結

```
【完成清單】
✅ 已創建 Xcode iOS 專案
✅ 已複製 JoyDiveCore 模組
✅ 已設計多格式解析器架構
✅ 已定義 SwiftData 資料模型
✅ 已建立基本 UI 框架
✅ 應用可編譯並在模擬器運行

【代碼統計】
├─ 新生成代碼行數：~500+ 行
├─ 複製代碼行數：~1500+ 行（來自 JoyDiveCore）
├─ 總代碼行數：~2000+ 行
└─ 測試代碼：待 Week 2

【人力投入】
├─ PM 實際投入：6 小時
├─ Claude Code 投入：相當於 15+ 小時代碼工作
├─ 效率提升：2.5+ 倍
└─ 計劃達成度：✅ 100% 按計劃完成

【風險評估】
✅ 無明顯風險
✅ 架構清晰，便於後續擴展
✅ 為 Week 3 解析器開發準備充分

【下週準備】
Week 2（5月26-31日）：
├─ UI 框架進一步完善
├─ 日誌詳情視圖實現
├─ 匯入嚮導基本框架
└─ 交付：Week 1-2 基礎搭建完成，可開始解析器開發
```

---

## 週進度追蹤

### 檢查點 1: Day 3 完成後
```
驗證項目：
□ 代碼編譯通過
□ 沒有編譯錯誤或警告
□ Git 倉庫更新

若失敗：
└─ 立即聯絡 Claude 修復，確保 Day 4 不受影響
```

### 檢查點 2: Day 6 完成後
```
最終驗收：
□ 應用在模擬器能運行
□ TabView 顯示正常
□ 所有架構都已實現
□ 無編譯警告

成功條件：
└─ Week 1 完全達成，Week 2 可順利開始
```

---

**Week 1 正式啟動日期**: 2026 年 5 月 19 日（週一）  
**PM 總投入**: 6 小時（每日 1 小時）  
**預期完成**: 2026 年 5 月 24 日（週六）
