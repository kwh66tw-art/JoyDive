// DiveSettings.swift — DiveKit/Models
// JD2-Ultra 新增：潛水模式設定（對應 業界規格 各模式設定項）
//
// UI 層以此為單一來源；DiveEngine 在「水面狀態」接受設定變更，
// 潛水中途僅允許不影響演算法的項目（與 業界「部分設定潛水後 5 分鐘內不可改」精神一致）。

import Foundation

/// 潛水模式（業界規格 ＋ 0.2.0 擴充）。氣瓶壓力相關功能已確認省略。
public enum DiveMode: String, Codable, CaseIterable, Sendable {
    case air      // 一般空氣
    case nitrox   // 高氧（O₂ 21–50%）
    case free     // 自由潛水
    case gauge    // 0.2.0(A7)：bottom timer——不提供 NDL/減壓資訊，用後鎖定 24h
    case snorkel  // 0.2.0(A11)：浮潛——GPS 航跡＋間歇下潛記錄＋返航羅盤（免費層核心）
    case off      // 關閉潛水電腦（不自動入水啟動、PLAN 隱藏）
}

public struct DiveSettings: Codable, Equatable, Sendable {

    // MARK: - 模式
    public var mode: DiveMode = .air

    // MARK: - 演算法保守度（業界規格）
    public var personal: PersonalSetting = .p0
    public var altitude: AltitudeSetting = .a0

    // MARK: - Nitrox（業界規格）
    /// O₂ 分率 0.21–0.40（休閒潛水上限 EAN40；業界規格雖到 50%，本產品定位休閒，PM 2026-06-13）
    public var nitroxFO2: Double = 0.21
    /// PO₂ 上限 0.5–1.6 bar（業界預設 1.4；手冊建議休閒上限 1.4、應變上限 1.6）
    public var maxPO2: Double = 1.4

    // MARK: - Deepstop（業界規格，Air/Nitrox 預設開啟、可關閉）
    public var deepstopEnabled: Bool = true

    // MARK: - 警報（業界規格 ＋ 0.2.0 A3 擴充）
    /// 深度警報第 1 組，預設 30 m 開啟（業界規格；保留舊欄位名以相容既有設定檔）
    public var depthAlarmEnabled: Bool = true
    public var depthAlarmMeters: Double = 30.0
    /// A3：額外深度警報（第 2、3 組）
    public var extraDepthAlarms: [DepthAlarmSlot] = [DepthAlarmSlot(), DepthAlarmSlot()]
    /// A3：變深度計——每下潛/上升 N 公尺提醒一次（nil = 關閉）
    public var variometerEveryMeters: Double? = nil
    /// A3：自潛垂直速度警報（m/min；nil = 關閉）
    public var freeAscentRateAlarmMpm: Double? = nil
    public var freeDescentRateAlarmMpm: Double? = nil
    /// 潛水時間警報（分鐘），nil = 關閉
    public var diveTimeAlarmMinutes: Int? = nil

    // MARK: - 0.2.0(B10)：停留參數（業界對應）
    /// 安全停留時長（秒；預設 180 = 業界標準 3 分鐘）
    public var safetyStopDurationSec: Int = AlgorithmConstants.safetyStopDuration
    /// 出水確認延遲（秒；預設 180 = 3 分鐘內再下潛屬同一次潛水）
    public var diveEndDelaySec: Int = AlgorithmConstants.diveEndConfirmSec
    /// 最後減壓停留深度下限（3 或 6 m；引導顯示與 TTS 模擬以此為停留底線）
    public var lastStopDepthMeters: Double = 3.0

    // MARK: - 取樣率（業界規格）
    public var scubaSampleRateSec: Int = AlgorithmConstants.scubaSampleRateDefault
    public var freeSampleRateSec: Int = AlgorithmConstants.freeSampleRateDefault

    // MARK: - Free 模式（業界規格）
    /// 自由潛水深度通知（最多 5 組，各自可開關）
    public var freeDepthNotifications: [DepthNotification] = DepthNotification.defaults
    /// 水面間隔提醒（秒），nil = 關閉（Free 模式 surface timer）
    public var freeSurfaceTimerSec: Int? = nil

    // MARK: - 0.2.0(A8)：靜音潛水（獵魚/攝影）——低優先警報靜音，高優先安全警報永不靜音
    public var silentDiving: Bool = false

    // MARK: - 單位
    public var units: UnitsSystem = .metric

    // MARK: - 0.2.0(M9)：水下畫面版面（C6 頁序 / C7 Big Numbers / C9 省電）
    public var screenLayout = DiveScreenLayout()

    public init() {}

    /// 目前模式的有效氣體（gauge 以空氣保守追蹤組織）
    public var activeGas: GasMix {
        switch mode {
        // 使用端 clamp 21–40%：即使舊存檔帶超範圍值也不會超出休閒上限（防呆）
        case .nitrox: return .nitrox(fO2: min(max(nitroxFO2, 0.21), 0.40))
        default:      return .air
        }
    }

    /// 目前氣體的最大操作深度（m）
    public var modMeters: Double {
        modMeters(for: activeGas)
    }

    /// 指定氣體的最大操作深度（m）——PLAN 可用任意計劃氣體（0.2.2）
    public func modMeters(for gas: GasMix) -> Double {
        let env = altitude.environment()
        return gas.mod(maxPO2: maxPO2,
                       surfacePressure: env.surfacePressureBar,
                       metersPerBar: env.metersPerBar)
    }
}

/// A3：額外深度警報槽
public struct DepthAlarmSlot: Codable, Equatable, Sendable {
    public var enabled: Bool = false
    public var depthMeters: Double = 20.0
    public init(enabled: Bool = false, depthMeters: Double = 20.0) {
        self.enabled = enabled
        self.depthMeters = depthMeters
    }
}

/// 自由潛水深度通知（業界規格：5 組獨立深度、各可開關）
public struct DepthNotification: Codable, Equatable, Identifiable, Sendable {
    public var id: Int
    public var enabled: Bool
    public var depthMeters: Double

    public init(id: Int, enabled: Bool = false, depthMeters: Double) {
        self.id = id
        self.enabled = enabled
        self.depthMeters = depthMeters
    }

    public static let defaults: [DepthNotification] = (1...AlgorithmConstants.freeDepthNotificationCount)
        .map { DepthNotification(id: $0, enabled: false, depthMeters: Double($0) * 10.0) }
}

public enum UnitsSystem: String, Codable, CaseIterable, Sendable {
    case metric
    case imperial
}

// MARK: - 0.2.0(M9)：水下畫面版面模型

/// 水下資料頁種類（0.2.2 M17 架構 v2：main 恆首、gas 依模式、compass 視開關；powerSaving 不再是頁）
public enum DiveScreenPage: String, Codable, CaseIterable, Sendable {
    case main          // 主資料頁（深度/時間/引導）
    case gas           // 氣體/環境（原 oxygen 改名；Nitrox=PO₂/OLF/MOD，Air=time/temp/HR）
    case compass       // 羅盤（緊鄰 main 的頁，錶冠一格到）
}

public struct DiveScreenLayout: Equatable, Sendable {
    /// C7：主資料頁放大佈局
    public var bigNumbers: Bool = false
    /// C9：省電模式（主頁降載；0.2.2 起＝設定開關，不再是獨立頁）
    public var powerSaving: Bool = false

    public init() {}

    /// 實際生效的頁面序列：main 恆首；compass 緊鄰 main（錶冠一格到，深度/NDL 仍在頂）；gas 於水肺模式。
    /// （0.2.2：羅盤＝錶冠叫出的相鄰頁——比 Action Button 穩、零設定、水下可用。）
    public func effectivePages(mode: DiveMode) -> [DiveScreenPage] {
        var pages: [DiveScreenPage] = [.main, .compass]
        if mode == .air || mode == .nitrox { pages.append(.gas) }
        return pages
    }
}

// 0.2.2：寬鬆解碼，相容 0.2.x 舊存檔（pageOrder/disabledPages/oxygen/powerSaving/compassEnabled）。
// 只取現用鍵、忽略所有舊鍵；缺鍵給預設，永不因舊存檔崩潰。
extension DiveScreenLayout: Codable {
    private enum CodingKeys: String, CodingKey { case bigNumbers, powerSaving }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bigNumbers = ((try? c.decodeIfPresent(Bool.self, forKey: .bigNumbers)) ?? nil) ?? false
        powerSaving = ((try? c.decodeIfPresent(Bool.self, forKey: .powerSaving)) ?? nil) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(bigNumbers, forKey: .bigNumbers)
        try c.encode(powerSaving, forKey: .powerSaving)
    }
}
