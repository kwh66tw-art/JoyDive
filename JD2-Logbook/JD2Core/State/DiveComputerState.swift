// DiveComputerState.swift — DiveKit/State
// JD2-Ultra 新增：潛水電腦安全狀態持久化
//
// ⚠️ 這是安全功能，不是 nice-to-have：
//    組織飽和 / 氧暴露 / Er 鎖定 / 禁飛 必須在 App 被終止、重啟、錶重開機後正確還原。
//    還原時依「離線經過時間」以水面脫飽和補算組織與 CNS 衰減。
//
// 儲存格式：JSON（Codable），由上層決定落地位置（App Group container / Application Support）。
// DiveKit 不直接碰檔案系統路徑決策，但提供預設的 FileBackedStateStore。

import Foundation

public struct DiveComputerState: Codable, Equatable, Sendable {

    /// 格式版本（schema migration 用）
    public var version: Int = 1

    /// 16 隔室 N₂ 分壓（bar）
    public var tissuePN2: [Double]

    /// 儲存當下使用的環境（還原時若高度設定變更需重新評估）
    public var environment: DiveEnvironment

    /// 氧暴露（CNS / OTU）
    public var oxygen: OxygenTracker

    /// 水面 / 禁飛 / Er 鎖定
    public var surface: SurfaceStatus

    /// 審計 Y2：潛水中已觸發、尚未結算的 Er 違規（App 於 finalize 前被終止時的保險）
    /// Optional：舊版快照無此欄位，解碼為 nil
    public var pendingErViolation: Bool?

    /// M22：存檔當下的 GF-high（widget 端計算可去海拔用；Optional＝舊快照相容）
    /// ⚠️ 還原時不套用——設定由 App 端 apply(settings:) 重建，此欄位僅供唯讀消費者
    public var gfHigh: Double?

    /// 最後更新時間（還原時據此補算離線期間的水面脫飽和）
    public var savedAt: Date

    public init(tissuePN2: [Double],
                environment: DiveEnvironment,
                oxygen: OxygenTracker,
                surface: SurfaceStatus,
                pendingErViolation: Bool? = nil,
                gfHigh: Double? = nil,
                savedAt: Date = Date()) {
        self.tissuePN2 = tissuePN2
        self.environment = environment
        self.oxygen = oxygen
        self.surface = surface
        self.pendingErViolation = pendingErViolation
        self.gfHigh = gfHigh
        self.savedAt = savedAt
    }

    // MARK: - M22：唯讀消費者（widget）便利查詢

    /// 脫飽和剩餘（依存檔組織算出總時長，再減去經過時間——指數脫飽和的時間平移性質使此式精確）
    public func desaturationRemainingSeconds(now: Date = Date()) -> Int {
        let total = Self.desaturationSeconds(tissuePN2: tissuePN2, environment: environment)
        let elapsed = Int(max(0, now.timeIntervalSince(savedAt)))
        return max(0, total - elapsed)
    }

    // MARK: - 還原補算

    /// 還原進 Buhlmann / OxygenTracker，並補算離線期間（視為水面呼吸空氣）。
    /// - Returns: 補算後的 OxygenTracker 與更新後的 SurfaceStatus
    public func restore(into buhlmann: Buhlmann, now: Date = Date())
        -> (oxygen: OxygenTracker, surface: SurfaceStatus) {

        // 先 reset 解除「潛水中不得切換 environment」防護（還原必然發生在水面/啟動時）
        buhlmann.reset()
        buhlmann.environment = environment
        buhlmann.restoreTissues(tissuePN2)

        // 離線期間水面脫飽和補算（分塊，沿用 tick 熔斷步長精神；長間隔用大步長即可，
        // Schreiner 對恆定 Palv 是解析解，步長不影響精度，分塊只為避免單步極端值）
        let elapsed = max(0, now.timeIntervalSince(savedAt))
        if elapsed > 0 {
            var remaining = elapsed
            let chunk = 3600.0   // 1h 一步（恆深恆氣體下解析解精確，無累積誤差）
            while remaining > 0.001 {
                let dt = min(chunk, remaining)
                buhlmann.updateSurface(deltaT: dt)
                remaining -= dt
            }
        }

        var ox = oxygen
        if elapsed > 0 {
            ox.update(po2: 0.21, deltaT: elapsed, isUnderwater: false)  // CNS 水面衰減
        }
        var surf = surface
        // 審計 Y2：潛水中觸發 Er 後 App 被終止 → 還原時補上鎖定與禁飛
        // （以 savedAt 起算 48h，與 finalize 時間差最多數分鐘，方向保守）
        if pendingErViolation == true {
            let until = savedAt.addingTimeInterval(
                Double(AlgorithmConstants.algorithmLockHours) * 3600)
            if surf.algorithmLockedUntil.map({ $0 < until }) ?? true {
                surf.algorithmLockedUntil = until
            }
            if surf.noFlyUntil.map({ $0 < until }) ?? true {
                surf.noFlyUntil = until
            }
        }
        surf.refresh(now: now)
        return (ox, surf)
    }

    /// 0.2.0(B2)：目前組織負載下可安全前往的最高海拔（公尺）
    /// 條件：所有隔室 pN2 ≤ 該海拔地面壓力下的 M-value（取 gfHigh 端，保守）。
    /// ISA 標準大氣反解；顯示上限 5000 m（深山公路情境足夠，超過顯示「5000+」由 UI 處理）。
    public static func allowedAltitudeMeters(tissuePN2: [Double], gfHigh: Double) -> Double {
        let cap = 5000.0
        var pMin = 0.0
        for (i, row) in Buhlmann.zhl16cTable.enumerated() where i < tissuePN2.count {
            let den = gfHigh / row.b + 1.0 - gfHigh
            guard den > 0 else { continue }
            pMin = max(pMin, (tissuePN2[i] - row.a * gfHigh) / den)
        }
        guard pMin > 0.54 else { return cap }   // 需求壓力低於 ~5000m 氣壓 → 顯示上限
        let ratio = pow(pMin / 1.01325, 1.0 / 5.25588)
        let h = (1.0 - ratio) / 2.25577e-5
        return min(max(h, 0), cap)
    }

    /// 估算目前組織完全脫飽和所需時間（秒）——禁飛計算輸入。
    /// 定義：最慢隔室回到「初始分壓 + ε」所需時間（恆定水面 Palv 下的解析解）。
    public static func desaturationSeconds(tissuePN2: [Double],
                                           environment: DiveEnvironment) -> Int {
        let palv = (environment.surfacePressureBar - environment.waterVaporPressureBar)
                   * AlgorithmConstants.fN2Air
        let epsilon = 0.01   // bar，視為已脫飽和的容許殘差
        var maxSec = 0.0
        for (i, p) in tissuePN2.enumerated() {
            guard p > palv + epsilon else { continue }
            let ht = Buhlmann.zhl16cTable[i].ht
            let k = log(2.0) / ht
            // p(t) = palv + (p - palv)·e^(−kt)；解 p(t) = palv + ε
            let t_min = log((p - palv) / epsilon) / k
            maxSec = max(maxSec, t_min * 60.0)
        }
        return Int(maxSec)
    }
}

// MARK: - 預設檔案儲存

/// JSON 檔案落地的簡單儲存層。上層（watch app）以 Application Support 目錄初始化。
public struct FileBackedStateStore: Sendable {

    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// 預設位置。0.2.0(B1)：優先用 App Group container（widget 可讀），
    /// 無 entitlement 時回退 Application Support（widget 顯示佔位，App 功能不受影響）。
    public static func defaultStore(
        appGroup: String? = "group.com.joydive.jd2ultra") throws -> FileBackedStateStore {
        let base: URL
        if let group = appGroup,
           let container = FileManager.default
               .containerURL(forSecurityApplicationGroupIdentifier: group) {
            base = container
        } else {
            base = try FileManager.default.url(for: .applicationSupportDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil,
                                               create: true)
        }
        let dir = base.appendingPathComponent("DiveKit", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return FileBackedStateStore(fileURL: dir.appendingPathComponent("computer-state.json"))
    }

    public func save(_ state: DiveComputerState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        // 原子寫入：安全狀態不允許寫一半
        try data.write(to: fileURL, options: [.atomic])
    }

    public func load() throws -> DiveComputerState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DiveComputerState.self, from: data)
    }

    public func clear() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
