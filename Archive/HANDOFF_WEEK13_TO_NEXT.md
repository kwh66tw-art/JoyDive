# 交接手冊：Week 13 macOS UI + 地圖模組（已完成）

**對話串日期**：2026-05-28
**狀態**：Week 13 macOS UI 修正與地圖模組全數完成並已 commit；定位 recenter 功能 pending 至下一版。
**Build**：PM 已實機 build 成功確認。

---

## 一、本次已完成（已提交）

| Commit | 內容 |
|--------|------|
| `da82923` | feat(macOS): Week13 UI 重構 + 地圖模組修復（本次主體，14 檔） |
| `d874953` | chore: 補提交交接前遺留變更（ImportWizard/AdBanner/Importer/DiveLog 模型/移除舊測試檔/Week9 交接文件） |
| `9a0b2df` | （上一串）Week13 A–F UI layout fixes |

### Week 13 macOS UI（對應舊稽核 ui_ux_audit_report v3.1 的 Diff B–P2）
- **Diff B**：`MacLogbookSplitView` 改雙導航對稱（左右欄各自 NavigationStack），消除頂部空白與不對稱。
- **Diff C**：`DiveCalendarView.onDiveTapped` 改 `((DiveLog?)->Void)?`，點空白日期/取消選取會清空右欄。
- **Diff D**：`SettingsView` macOS 加 `.formStyle(.grouped)` + `.padding(.top,-16)`。
- **P1**：`DiveLogListView` macOS 改 `ScrollView + LazyVStack` 卡片（取代 List，根除藍色 Focus Ring/偏移粗框）；選取以卡片邊框呈現；用 `.onMoveCommand` 補回上下鍵導覽。
- **P2**：iOS 月曆年月改「年 stepper + 12 月網格」popover（雙平台共用），取代攤平 Menu 與半屏滾輪 sheet。

### 額外修正（本次過程累積）
- 新增/編輯潛水 sheet（macOS）版面：`.formStyle(.grouped)` + 尺寸約束；`TextField` 加 `.labelsHidden()` 修掉多餘「0.0」；`@FocusState` 補 tab 導覽。
- `Nitrox` 繁中改「**高氧**」（zh-Hant），簡中不動。
- 視窗縮放：`JD2_LogbookApp` 加 `.windowResizability(.contentMinSize)`；MainTabView 各 detail pane（日誌/地圖/匯入/設定）各自 `minWidth/minHeight`，並改回真正的 `@State columnVisibility`（修好 sidebar toggle 無作用）。
- 文字防換行：DiveRowView、Dive Profile 圖表軸、列表/詳情統計數字加 `lineLimit(1)` + `fixedSize`/`minimumScaleFactor`。
- 月曆：貼頂（`.frame(maxHeight:.infinity, alignment:.top)`）、Today 按鈕、左右滑動切月；macOS 移除底部重複的「選擇日期」區塊。

### 地圖模組（對應舊「Task G」）
- **macOS 潛點詳情**：modal → **推開式 HSplitView 側面板**（地圖分頁 `minWidth 700` 確保不擠壓）；點 pin 後 `setCenter` 把該 pin 平移置中（不被面板遮擋、保留無旋轉）。
- **關閉旋轉**：`mapView.isRotateEnabled = false`、`showsCompass = false`。一舉解決「旋轉後彈回正北」與 iOS/macOS 羅盤不一致（兩平台都不顯示羅盤）。
- **切換鈕**：加 `.buttonStyle(.plain)` 去除 macOS 白色焦點環。
- **漏洞修正**：編輯潛點後同步 annotation title/subtitle；關閉 Sheet 後 `deselectAnnotation` 防 pin 卡死再點不開。
- **iOS 詳情仍為 detent sheet**（0.35/large + 背景可互動），不變。

---

## 二、⚠️ 重要踩雷紀錄（下一棒務必先讀，避免重蹈覆轍）

### 1. 聚合數字消失（花最多時間，最後才修對）
**症狀**：cluster 徽章數字 zoom in/out 後消失成空白。
**真因**：不是徽章「怎麼畫」，而是**單一潛點 `DiveSiteAnnotationView` 被 MapKit「原地重指派 annotation」時 `clusteringIdentifier` 被重置為 nil**，該 pin 退出聚合 → 聚合解體 → 看起來像數字消失。
**正解**（已在 code）：`DiveSiteAnnotationView` 覆寫 `override var annotation { didSet { applyStyle() } }`，在 didSet 重套 `clusteringIdentifier`（含值變更防護）。`annotation` didSet 是**唯一**不論新建/dequeue/原地重指派都必觸發的節點；只靠 `init`/`prepareForDisplay`/`viewFor` 都會被原地重指派路徑繞過。
**已驗證無效、別再試**：自繪 image badge、NSImage drawingHandler、原生 MKMarkerAnnotationView auto-count、viewFor 內設 glyphText。這些全都修不好，因為問題在 site pin 的 clusteringIdentifier，不在徽章繪製。
- 目前 cluster 徽章用 MapKit 原生預設（`viewFor` 對 `MKClusterAnnotation` 回傳 `nil`），外觀為系統預設樣式。

### 2. SwiftUI Representable 內不要同步動 MapKit
在 `updateNSView/updateUIView` 的 render 流程裡**同步**呼叫 `setCenter`/`selectAnnotation`/`deselectAnnotation` 會造成 `NSHostingView reentrant layout` + `AttributeGraph cycle` 無窮迴圈（連帶卡頓、數字閃失）。**解法**：這些選取/置中操作一律包 `DispatchQueue.main.async` 延後執行（已在 code）。

### 3. 不要用 @Binding 從 update 內回寫
指北/置中這類「一次性指令」不要用 `@Binding var x: Bool` 在 update 內 async 設回 false（回寫時機不可靠、易重入）。用 **Int token**（每次 +1，coordinator 比對 `lastToken`）。

### 4. console 噪訊
`clip: empty path`、`Failed to locate resource default.csv`、`VectorKit SharedResourcesManager` assertion、`setDrawableSize=0` 都是 macOS MapKit **無害系統噪訊**，與 bug 無關，別被帶偏。

### 5. git index.lock（sandbox 無法 commit）
AI sandbox 無法刪除 `.git/index.lock`（Operation not permitted），所有 commit 都得 PM 在本機終端機跑：`rm -f .git/index.lock` 後再 `git add/commit`。

---

## 三、Pending：定位「回到我的位置」按鈕（下一版做，方案已審核定案）

PM 裁定 pending。以下方案已交叉審核完畢、含修正，下一棒可直接實作，不必重新研究。

**配置（缺一即 P0 閃退）**
1. `project.pbxproj`（專案用 `GENERATE_INFOPLIST_FILE=YES`，無實體 Info.plist）→ Debug+Release 加
   `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "JD2-Logbook 需要您的定位權限，在地圖上顯示您目前的位置。"`
2. `JD2-Logbook.entitlements`（macOS 沙盒）加 `com.apple.security.personal-information.location`。
   （`com.apple.security.network.client` 本次已補。）

**SafeLocationManager（新檔 `Services/SafeLocationManager.swift`，本專案用同步檔案群組，新檔會自動編入，不需手動加進 Xcode）**
- `@MainActor final class ... : NSObject, ObservableObject`，`@Published authorizationStatus`。
- **漸進式授權**：絕不在地圖載入時請求；只在使用者**點按鈕**才 `requestWhenInUseAuthorization()`（macOS 11+ 亦支援；或以 `startUpdatingLocation()` 觸發）。
- 被拒絕：彈 Alert + 「前往設定」（`UIApplication.openSettingsURLString` / `x-apple.systempreferences:...Privacy_LocationServices`），**不要置灰**。

**地圖串接（修正稽核的兩個雷）**
- `showsUserLocation` **只在已授權時才開**（依 authorizationStatus 切換），載入時不開、不彈窗、不閃退。
- recenter 用 **Int token**（非 Bool binding）；coordinator 設 `shouldRecenter`，由 `mapView(_:didUpdate userLocation:)` delegate 在座標到達時 `setRegion` 置中；若當下已有座標則立即置中。
- 按鈕放右上控制鈕組（圖層切換下方），圖示 `location.fill` / 被拒 `location.slash.fill`。

---

## 四、尚未驗證、需確認的項目（非本次範圍）

對照 `JD2_12WEEK_FINAL_PLAN.md`，下列不在本次處理，狀態未知，請確認：
1. **iOS 18 新功能**：Control Center 擴展、Lock Screen Widget、Home Screen 圖示變體（計畫 Week 11）。
2. **WCAG 2.1 AA 可達性審核**（計畫 Week 12）：色彩對比、VoiceOver、觸控目標 44×44、動態字體。
3. **多語系全面性**：本次僅改「高氧」一條；`JD2-Logbook_i18n_review_V3.xlsx/csv` 仍可能有待補字串。
4. **測試覆蓋率 / 7 種格式匯入成功率**：解析器單元測試是否維持 >85%、混合匯入 >95%。

---

## 五、未追蹤（未提交）的非程式碼檔

工作區仍有未追蹤檔，本次**刻意未提交**（備份/審查表/新測試資料），下一棒視需要處理：
`JD2-Logbook_backup_xcodeproj/`、`*.xlsx`/`*.csv` i18n 審查表、`TestFiles/Garmin|Seabear|Seac|Divesoft|Subsurface/...` 新樣本、其餘 `.md` 報告。

---

**下一步建議**：先做第四節的查核（尤其 WCAG 與 i18n 是上線必過項），再排定位 recenter（第三節）。
