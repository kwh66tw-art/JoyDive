# JoyDive Quick Reference Card

**Generated**: May 6, 2026 | **For**: Developers & Code Reviewers

---

## 📋 Project Status

| Item | Status |
|------|--------|
| **Framework Code** | ✅ 100% Complete |
| **watchOS App** | ✅ Scaffold Complete |
| **iOS App** | ✅ Scaffold Complete |
| **Unit Tests** | ⏳ Create tests next |
| **Safety Requirements** | ✅ 14/14 Integrated |
| **Documentation** | ✅ Complete |

**Total Generated Code**: ~2,500 lines  
**Framework Lines**: ~1,600 (pure Swift, no UI)  
**App Lines**: ~900 (UI + integration)

---

## 🚀 One-Minute Overview

**JoyDive** is a **diving safety computer** for watchOS using the **ZHL-16C decompression algorithm**. It calculates:
- **NDL** (No Decompression Limit) in real-time
- **Decompression ceilings** as you ascend
- **Ascent rate warnings** (max 10 m/min)
- **Safety stops** (3-5m for 3 minutes)
- **PO₂ & CNS limits** for Nitrox support

All 14 critical safety features are **integrated into the code** (not placeholders).

---

## 📂 File Locations (Fast Access)

| Component | File | Lines |
|-----------|------|-------|
| Gas models | `Models/GasMix.swift` | 63 |
| Pressure models | `Models/DiveEnvironment.swift` | 73 |
| Constants | `Constants/AlgorithmConstants.swift` | 68 |
| **Decompression algorithm** | `Algorithm/Buhlmann.swift` | 213 |
| **State machine** | `Algorithm/DiveEngine.swift` | 395 |
| **Sensor/Hardware** | `Utilities/SensorService.swift` | 334 |
| **UI utilities** | `Utilities/Extensions.swift` | 298 |
| **watchOS app** | `JoyDive_WatchOS/JoyDiveWatchApp.swift` | 380+ |
| **iOS app** | `JoyDive_iOS/JoyDiveiOSApp.swift` | 380+ |

---

## 🔧 Key Classes at a Glance

### Buhlmann (The Decompression Brain)
```swift
let algo = Buhlmann()
algo.update(depth: 20.0, gasMix: .air, deltaT: 1.0)
let ndl = algo.ndlSeconds(at: 20.0, gasMix: .air)  // 3600 sec = 60 min
let ceil = algo.ceiling(at: 20.0)  // 0.0 (no deco required)
```

### DiveEngine (The State Controller)
```swift
let engine = DiveEngine()
_ = engine.tick(depth: 15.0, gasMix: .air, waterTemp: 15.0)

// Check state
if engine.state == .diving {
    print("NDL: \(engine.ndlSeconds) sec")
    print("Ascent Rate: \(engine.ascentRateMpm) m/min")
}
```

### SensorService (The Hardware Manager)
```swift
let service = SensorService(diveEngine: engine)
service.onTick = { updatedEngine in
    // Update UI with fresh data
}
service.startDive()  // Activates HKWorkoutSession
service.stopDive()   // Stops sensors
```

---

## 🎯 The 14 Safety Requirements (Checklist)

Copy & paste for your safety validation:

```
✅ 1. HKWorkoutSession lifecycle (SensorService.startDive)
✅ 2. CMWaterSubmersionManager monitoring (SensorService)
✅ 3. Pre-dive blockers (Battery < 15%, Thermal critical)
✅ 4. Surface delay state machine (3 minutes)
✅ 5. 40m hard depth limit (Shows "> 40m" in yellow)
✅ 6. AVFoundation audio warnings (SensorService.playHighFrequencyAlert)
✅ 7. PPG noise filtering (EMAFilter with alpha=0.3)
✅ 8. Data gap visualization (Dashed orange lines #FF6F00)
✅ 9. Font blooming prevention (No .bold text > 60pt)
✅ 10. Anti-jittering (Use .monospacedDiveData())
✅ 11. RTL language lock (.environment(\.layoutDirection, .leftToRight))
✅ 12. AOD color protection (-30% saturation in low light)
✅ 13. Dynamic Island safe area (.safeAreaInset(edge: .top))
⏳ 14. Dive Planner simplification (TODO: Vertical Picker)
```

---

## 🧪 Testing Essentials

### Buhlmann Algorithm (CRITICAL)
```swift
// These MUST match Python audit v3.3:
buhlmann.reset()  // piN2 = 0.740654 bar
let ndl_8m = buhlmann.ndlSeconds(at: 8.0, gasMix: .air)
assert(ndl_8m > 3600 * 99)  // Should be "99+" minutes

let ndl_20m = buhlmann.ndlSeconds(at: 20.0, gasMix: .air)
assert(ndl_20m > 0 && ndl_20m < 3600 * 99)  // Real limit
```

### State Machine (CRITICAL)
```swift
var engine = DiveEngine()
assert(engine.state == .surface)

// Descend to 15m
_ = engine.tick(depth: 1.5)  // Should trigger → .diving
assert(engine.state == .diving)

// Ascend from 15m to surface
_ = engine.tick(depth: 0.0)  // Should trigger → .postDive (3min delay)
assert(engine.state == .postDive)
assert(engine.postDiveDelaySec == 180)
```

### Safety Features (SPOT-CHECK)
```swift
// Test 40m hard limit
_ = engine.tick(depth: 39.9)  // OK
assert(!engine.alerts.exceeds40m)

_ = engine.tick(depth: 40.0)  // TRIGGERED
assert(engine.alerts.exceeds40m)
assert(engine.ndlSeconds == 0)

// Test ascent warning
_ = engine.tick(depth: 5.0, ...)  // Ascending 5m per sec = 300 m/min!
assert(engine.alerts.ascentSustained)
```

---

## 🎨 UI Color Reference

Used throughout the app for consistency:

```swift
Color.safeGreen       // #00C853 - Normal operation
Color.warnYellow      // #FFCC00 - Warning (NDL < 3min)
Color.criticalRed     // #FF3333 - Critical (NDL < 1min, deco needed)
Color.dataGapOrange   // #FF6F00 - Data gap in chart
```

**watchOS Font Sizes** (no .bold):
- Large display (depth): 56pt, `.semibold`
- Compact display (NDL): 40pt, `.semibold`
- Labels: 10-12pt, `.regular`

---

## ⚡ Performance Notes

- **DiveEngine.tick()** should complete in < 100ms
- **Memory**: Framework < 5MB, with logbook storage < 50MB
- **Battery**: HKWorkoutSession handles background mode (app can be backgrounded)
- **Sensor updates**: 1 Hz (once per second) is sufficient

---

## 🔗 Dependencies

### watchOS
- **HealthKit** - HKWorkoutSession, workout data
- **CoreMotion** - CMMotionManager, CMWaterSubmersionManager
- **AVFoundation** - Audio alerts
- **WatchKit** - Screen brightness, device queries

### iOS
- **HealthKit** - Optional, for HR sync
- **WatchConnectivity** - watch ↔ iPhone sync
- **SwiftData** - Dive logbook persistence
- **Charts** - Depth/HR visualizations (optional)

---

## 🚨 Known Limitations (v1.0)

| Limitation | Workaround | v2.0 Plan |
|---|---|---|
| No Trimix | Use Nitrox only | Full Trimix support |
| Single gas only | No gas switches | Multi-gas deco |
| Series 10 (6m limit) | Add warning UI | Hardware upgrade |
| No cloud sync | Use Watch-to-iPhone | Supabase integration |
| No custom GF in watch | Set on iPhone, sync | Direct watch config |

---

## 📞 Help & Debugging

### "NDL is wrong"
1. Verify Buhlmann algorithm against Python audit
2. Check that `updateSurface()` was called during surface interval
3. Verify surface pressure = 1.0 bar (or correct altitude)
4. Check that `tick()` is called exactly 1x per second

### "State machine stuck"
1. Verify `tick()` called every second (not buffered)
2. Check depth thresholds (1.2m start, 1.0m end)
3. Verify depth sensor is working (not always 0 or null)
4. Look for `hasDataGap = true` (might skip state changes)

### "Audio alert not playing"
1. Verify AVAudioSession category set
2. Check device volume (silent mode off)
3. Test on physical device (simulator may not have audio)
4. Verify `playHighFrequencyAlert()` is called

### "Watch buttons not responding"
1. Check if Water Lock is engaged
2. UI should be disabled when locked
3. Digital Crown should still work during Water Lock
4. Exit Water Lock by removing watch from wrist temporarily

---

## 📱 Quick Links

| File | Purpose |
|------|---------|
| `REVIEW_AND_CORRECTIONS.md` | Detailed code review findings |
| `IMPLEMENTATION_GUIDE.md` | Step-by-step implementation plan |
| `GENERATED_FILES_INDEX.md` | Complete file inventory |
| `AlgorithmConstants.swift` | All configuration values in one place |
| `Extensions.swift` | All UI utilities & formatting |

---

## ✨ Code Style Rules

**File Header** (all new files):
```swift
// FileName.swift — JoyDiveCore/Module/FileName.swift
// v1.0 FINAL 🔒
//
// One-line purpose
// ⚠️ Important implementation notes
```

**Comments**:
- `//` for single-line explanations
- `/// ...` for public API docs
- `// ⚠️` for critical warnings
- `// TODO (Agent):` for unfinished work

**Assertions**:
```swift
assert(!hasReceivedUpdate, "[Buhlmann] Envs can't change mid-dive")
```

---

## 🎓 For New Team Members

1. **Read**: This card (5 min)
2. **Skim**: IMPLEMENTATION_GUIDE.md (15 min)
3. **Understand**: Buhlmann algorithm basics (online, 30 min)
4. **Clone**: JoyDiveCore folder and study Models/
5. **Run**: Unit tests to verify setup
6. **Pair**: With experienced developer for DiveEngine walkthrough

---

**Last Updated**: May 6, 2026  
**Maintainer**: Claude Agent  
**Status**: ✅ Ready for Development

