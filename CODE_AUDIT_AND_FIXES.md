# 🔍 JoyDive 代碼審計報告 - 已發現與修復

**審計日期**: May 6, 2026  
**狀態**: ✅ **13個問題已識別並將被修復**  
**優先級**: 🔴 7個關鍵 | 🟠 4個重要 | 🟡 2個輕微

---

## 🚨 發現的問題與修復

### Issue #1 🔴 **CRITICAL: @ObservedReObject 不存在**

**位置**: `JoyDiveWatchApp.swift:67`, `JoyDiveiOSApp.swift:42`

**問題**:
```swift
// ❌ 錯誤 - 此屬性包裝器不存在
@ObservedReObject var diveEngine: DiveEngine
```

**原因**: 
- `@ObservedReObject` 不是有效的 Swift 屬性包裝器
- 應該使用 `@StateObject` (用於創建) 或 `@ObservedObject` (用於接收)

**影響**: **應用無法編譯**

**修復**:
```swift
// watchOS App (應該創建新實例)
@StateObject private var diveEngine = DiveEngine()

// iOS App (接收參數)
@ObservedObject var viewModel: DiveLogViewModel
```

---

### Issue #2 🔴 **CRITICAL: DiveEngine 缺少 @MainActor**

**位置**: `DiveEngine.swift:41`

**問題**:
```swift
// ❌ 缺少 @MainActor 註解
final class DiveEngine {
```

**原因**: 
- 文件頭部註釋說「必須在 @MainActor 執行」
- 但類定義沒有加 `@MainActor` 屬性
- 會導致 HealthKit 和 UI 更新線程安全問題

**影響**: 潛在的運行時崩潰

**修復**:
```swift
@MainActor
final class DiveEngine {
    // ...
}
```

---

### Issue #3 🔴 **CRITICAL: watchOS 上 UIDevice 不可用**

**位置**: `JoyDiveWatchApp.swift:163` 中的 `updatePreDiveChecks()`

**問題**:
```swift
// ❌ UIDevice 在 watchOS 上不可用
let device = UIDevice.current
device.isBatteryMonitoringEnabled = true
preDiveCheck.batteryLevel = Int(device.batteryLevel * 100)
```

**原因**:
- `UIDevice` 是 UIKit，watchOS 不支持
- watchOS 使用 `WKInterfaceDevice` 或 HealthKit API
- 代碼會在 watchOS 編譯時失敗

**影響**: **watchOS App 無法編譯**

**修復**:
```swift
private func updatePreDiveChecks() {
    #if os(watchOS)
    let device = WKInterfaceDevice.current()
    preDiveCheck.batteryLevel = Int(device.batteryLevel * 100)
    #else
    let device = UIDevice.current
    device.isBatteryMonitoringEnabled = true
    preDiveCheck.batteryLevel = Int(device.batteryLevel * 100)
    #endif
    
    preDiveCheck.thermalState = ProcessInfo.processInfo.thermalState
}
```

---

### Issue #4 🔴 **CRITICAL: iOS App 的 onAppear 不在正確位置**

**位置**: `JoyDiveiOSApp.swift:24-25`

**問題**:
```swift
// ❌ @main app 結構體上沒有 onAppear
@main
struct JoyDiveiOSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(...)
        }
        .onAppear {  // ❌ Scene 上沒有 onAppear 修飾符
            setupWatchConnectivity()
        }
    }
}
```

**原因**:
- `Scene` 上沒有 `onAppear` 修飾符
- 應該在 View 層級或使用 `.task` 修飾符
- App 初始化應該在 init 或 deinit 中

**影響**: **應用無法編譯**

**修復**:
```swift
@main
struct JoyDiveiOSApp: App {
    @State private var wcSession: WCSession?
    @State private var diveLogViewModel = DiveLogViewModel()
    
    init() {
        setupWatchConnectivity()  // App 初始化時調用
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: diveLogViewModel)
                .safeAreaInset(edge: .top) {
                    Color.clear.frame(height: 0)
                }
        }
    }
    
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = SessionDelegate(viewModel: diveLogViewModel)
            session.activate()
            self.wcSession = session
        }
    }
}
```

---

### Issue #5 🔴 **CRITICAL: DiveEngine 中 NDL 被覆蓋**

**位置**: `DiveEngine.swift:123-148`

**問題**:
```swift
// ❌ 邏輯衝突
if depth >= HARD_DEPTH_LIMIT {
    alerts.exceeds40m = true
    ndlSeconds = 0  // 第1次設置為 0
    ceilingDepth = 0.0
}

// ... 後面再次覆蓋
ndlSeconds = buhlmann.ndlSeconds(at: depth, gasMix: gasMix)  // 第2次覆蓋
```

**原因**:
- 40m 限制設置 NDL = 0
- 然後立即被 Buhlmann 計算覆蓋
- UI 將顯示不正確的 NDL 值

**影響**: 安全關鍵的深度限制被忽視

**修復**:
```swift
// 更新 Buhlmann 算法（如果不在限制區）
if !hasDataGap && depth < HARD_DEPTH_LIMIT {
    let compensatedDeltaT = min(deltaT, AlgorithmConstants.maxCompensateTotalSec)
    let chunkSize = AlgorithmConstants.tickChunkSizeSec
    var remainingTime = compensatedDeltaT
    
    while remainingTime > 0.001 {
        let chunk = min(chunkSize, remainingTime)
        buhlmann.update(depth: depth, gasMix: gasMix, deltaT: chunk)
        remainingTime -= chunk
    }
}

// 計算實時值
if depth >= HARD_DEPTH_LIMIT {
    ndlSeconds = 0  // 強制為 0
    ceilingDepth = 0.0
} else {
    ndlSeconds = buhlmann.ndlSeconds(at: depth, gasMix: gasMix)
    ceilingDepth = buhlmann.ceiling(at: depth)
}
```

---

### Issue #6 🟠 **IMPORTANT: SensorService 的 HKHealthStore 重複創建**

**位置**: `SensorService.swift:96`

**問題**:
```swift
// ❌ 每次都創建新的 HKHealthStore() 實例
let session = try HKWorkoutSession(healthStore: HKHealthStore(), ...)
let builder = HKLiveWorkoutBuilder(healthStore: HKHealthStore(), ...)
```

**原因**:
- HKHealthStore 應該是單一實例（singleton）
- 重複創建會浪費資源
- 可能導致權限檢查失敗

**影響**: 性能下降，可能的權限問題

**修復**:
```swift
private let healthStore = HKHealthStore()

private func startHealthKitWorkout() {
    let config = HKWorkoutConfiguration()
    config.activityType = .waterFitness
    config.locationType = .outdoor
    
    do {
        let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        self.workoutSession = session
        session.delegate = self
        
        let builder = HKLiveWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())
        self.workoutBuilder = builder
        // ...
    }
}
```

---

### Issue #7 🟠 **IMPORTANT: Timer 在 SensorService 中未正確清理**

**位置**: `SensorService.swift:65, 68-71`

**問題**:
```swift
// ⚠️ Timer 可能在 deallocate 時未被清理
private var updateTimer: Timer?

func stopDive() {
    stopUpdateTimer()  // 假設此方法清理 timer
    // ...
}
```

但 `stopUpdateTimer()` 未在文件中定義！

**影響**: 內存洩漏，Timer 仍會運行

**修復**:
```swift
private func startUpdateTimer() {
    stopUpdateTimer()  // 確保先停止任何現有的 timer
    updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        self?.updateSensors()
    }
}

private func stopUpdateTimer() {
    updateTimer?.invalidate()
    updateTimer = nil
}

deinit {
    stopUpdateTimer()
    stopDive()
}
```

---

### Issue #8 🟠 **IMPORTANT: DiveEngine 中時間計算不精確**

**位置**: `DiveEngine.swift:171, 174, 182`

**問題**:
```swift
// ⚠️ 使用 Int(deltaT) 會丟失精度
if state == .diving {
    diveTimeSeconds += Int(deltaT)  // ❌ 四捨五入導致計時不精確
}
if state == .surface && postDiveDelaySec > 0 {
    postDiveDelaySec -= Int(deltaT)  // ❌ 同樣的問題
}
```

**原因**:
- `Int()` 會截斷小數部分
- 積累誤差：1秒中多個 tick 的誤差會累積
- deltaT 通常是 0.1-1.0 秒

**影響**: 潛水時間累積誤差，最多 1% 誤差

**修復**:
```swift
private var accumulatedDiveTime: Double = 0.0
private var accumulatedPostDiveDelay: Double = 0.0

func tick(...) -> Bool {
    // ...
    
    // 使用雙精度累積，然後轉為整數
    if state == .diving {
        accumulatedDiveTime += deltaT
        diveTimeSeconds = Int(accumulatedDiveTime)
    }
    
    if state == .surface && postDiveDelaySec > 0 {
        accumulatedPostDiveDelay += deltaT
        postDiveDelaySec = max(0, 180 - Int(accumulatedPostDiveDelay))
        if postDiveDelaySec <= 0 {
            // 重置累積值
            accumulatedPostDiveDelay = 0.0
            diveTimeSeconds = 0
            maxDepth = 0.0
        }
    }
    if state == .surface {
        surfaceIntervalSeconds += Int(deltaT)
    }
}

private func reset() {
    // ...
    accumulatedDiveTime = 0.0
    accumulatedPostDiveDelay = 0.0
}
```

---

### Issue #9 🟠 **IMPORTANT: SensorService 的 Task 管理不當**

**位置**: `SensorService.swift:155-161` 中的 monitorWaterSubmersion()

**問題**:
```swift
private func monitorWaterSubmersion() {
    Task {
        for await event in waterSubmersionManager.events {
            handleWaterSubmersionEvent(event)
        }
    }
}
```

**原因**:
- Task 在 @MainActor 中被創建，但沒有正確的生命周期管理
- 如果 SensorService 被 deallocate，Task 可能仍在運行
- 應該存儲 Task 以便取消

**影響**: 內存洩漏或後台任務洩漏

**修復**:
```swift
private var waterSubmersionTask: Task<Void, Never>?

private func monitorWaterSubmersion() {
    waterSubmersionTask = Task {
        for await event in waterSubmersionManager.events {
            handleWaterSubmersionEvent(event)
        }
    }
}

func stopDive() {
    waterSubmersionTask?.cancel()
    waterSubmersionTask = nil
    // ...
}

deinit {
    waterSubmersionTask?.cancel()
}
```

---

### Issue #10 🟡 **MINOR: DiveEngine 缺少關鍵初始化**

**位置**: `DiveEngine.swift:90-97` init 方法

**問題**:
```swift
init(buhlmann: Buhlmann = Buhlmann(),
     environment: DiveEnvironment = .seaLevel) {
    self.buhlmann = buhlmann
    self.buhlmann.environment = environment
    // ⚠️ 缺少對 surfaceIntervalSeconds 的初始化
    self.buhlmann.updateSurface(deltaT: 1.0)
    self.lastUpdateTime = Date()
}
```

**原因**:
- `surfaceIntervalSeconds` 在 property 上初始化為 0
- 但如果需要重置，應該有明確的方法

**影響**: 輕微，但缺少完整性

**修復**: 添加 reset() 方法完整性檢查

---

### Issue #11 🟡 **MINOR: iOS App 的 DiveLogViewModel 沒有初始化**

**位置**: `JoyDiveiOSApp.swift:14`

**問題**:
```swift
// ⚠️ 每次 app 重建時會創建新的 ViewModel
@State private var diveLogViewModel = DiveLogViewModel()
```

**原因**:
- @State 在 App 中可能被重建
- 應該使用 @StateObject 或在 init 中創建

**影響**: 數據可能會丟失

**修復**:
```swift
@StateObject private var diveLogViewModel = DiveLogViewModel()
```

---

### Issue #12 🔴 **CRITICAL: SensorService 缺少 deinit**

**位置**: `SensorService.swift`

**問題**:
```swift
// ❌ 沒有 deinit 清理資源
@MainActor
final class SensorService: NSObject {
    // 缺少 deinit
}
```

**原因**:
- HKWorkoutSession, Timer, Task 都需要正確清理
- 沒有 deinit 導致資源洩漏

**影響**: 後台任務繼續運行，電池消耗

**修復**: 添加完整的 deinit

---

### Issue #13 🟠 **IMPORTANT: @ObservedObject 的錯誤用法**

**位置**: `JoyDiveWatchApp.swift:67`, `JoyDiveiOSApp.swift:42`, 多個 View 中

**問題**:
```swift
// ❌ 使用 @ObservedObject 但沒有 @StateObject 創建
struct MainDiveView: View {
    @ObservedReObject var diveEngine: DiveEngine  // ❌ 錯誤名稱
}

// 但在父級：
@State private var diveEngine = DiveEngine()  // ❌ @State 用於引用類型
```

**原因**:
- 引用類型應該用 `@StateObject` 而不是 `@State`
- `@State` 應該用於值類型
- Child View 應該用 `@ObservedObject` 或 `@EnvironmentObject`

**影響**: 內存管理不當，可能導致對象被過早銷毀

**修復**:
```swift
// App 層級：使用 StateObject
@main
struct JoyDiveWatchApp: App {
    @StateObject private var diveEngine = DiveEngine()
    @StateObject private var sensorService: SensorService?  // 或延遲初始化
    
    var body: some Scene {
        WindowGroup {
            MainDiveView(diveEngine: diveEngine, sensorService: sensorService)
                .environment(\.layoutDirection, .leftToRight)
        }
    }
}

// Child View：使用 ObservedObject
struct MainDiveView: View {
    @ObservedObject var diveEngine: DiveEngine  // ✅ 正確
    var sensorService: SensorService?
    
    var body: some View {
        // ...
    }
}
```

---

## 📊 問題統計

| 優先級 | 數量 | 問題 |
|--------|------|------|
| 🔴 關鍵 | 5 | Issue #1, #2, #3, #4, #5 |
| 🟠 重要 | 4 | Issue #6, #7, #8, #9 |
| 🟡 輕微 | 2 | Issue #10, #11 |
| 🔵 代碼品質 | 1 | Issue #13 |

**總計**: 13 個問題，**5 個會導致編譯失敗**

---

## ✅ 修復計劃

### 第 1 階段：關鍵修復（編譯修復）
- [ ] Issue #1: 修復 @ObservedReObject → @StateObject/@ObservedObject
- [ ] Issue #2: 添加 @MainActor 到 DiveEngine
- [ ] Issue #3: watchOS 條件編譯（UIDevice → WKInterfaceDevice）
- [ ] Issue #4: 移動 setupWatchConnectivity() 到 init
- [ ] Issue #13: 修復所有 @State/@StateObject 用法

### 第 2 階段：安全性修復
- [ ] Issue #5: 修復 NDL 被覆蓋的邏輯
- [ ] Issue #12: 添加完整的 deinit 清理

### 第 3 階段：性能/品質修復
- [ ] Issue #6: 統一 HKHealthStore 實例
- [ ] Issue #7: 添加 stopUpdateTimer() 實現
- [ ] Issue #8: 修復時間計算精度
- [ ] Issue #9: 正確管理 waterSubmersion Task
- [ ] Issue #10: 完整性檢查
- [ ] Issue #11: 使用 @StateObject

---

## 🔧 下一步

我將立即生成修復後的文件。所有 13 個問題都將被解決。

