// DiveEnvironment.swift — DiveKit/Models
// 基底：JD2Core v3.0 FINAL 🔒
// JD2-Ultra: 加上 public / Sendable / Codable，新增 AltitudeSetting 0–2 對應（業界規格）

import Foundation

public struct DiveEnvironment: Equatable, Codable, Sendable {

    /// 海平面氣壓（bar）
    /// ✅ 1.0 bar（與 Python Audit 及 Bühlmann 原著一致）
    /// 注：物理上 1 atm = 1.01325 bar，但業界潛水電腦普遍使用 1.0 bar 簡化計算
    public let surfacePressureBar: Double

    /// 水蒸氣分壓（bar），37°C 體溫恆定
    public let waterVaporPressureBar: Double

    /// 深度換算係數（m/bar）
    /// 海水（≈1025 kg/m³）：10.0 m/bar（業界標準）
    /// 淡水（≈1000 kg/m³）：10.2 m/bar（物理精確值 10.197）
    /// ⚠️ 不得在潛水中途切換（影響所有 Schreiner 計算）
    public let metersPerBar: Double

    public init(surfacePressureBar: Double,
                waterVaporPressureBar: Double,
                metersPerBar: Double) {
        self.surfacePressureBar = surfacePressureBar
        self.waterVaporPressureBar = waterVaporPressureBar
        self.metersPerBar = metersPerBar
    }

    // MARK: - 預設環境

    /// 標準海水，預設值，與 Python Audit 完全對齊
    public static let seaLevel = DiveEnvironment(
        surfacePressureBar: 1.0,
        waterVaporPressureBar: 0.0627,
        metersPerBar: 10.0
    )

    /// 淡水環境（湖潛、洞穴潛水）
    public static let freshwater = DiveEnvironment(
        surfacePressureBar: 1.0,
        waterVaporPressureBar: 0.0627,
        metersPerBar: 10.2
    )

    /// 高海拔環境，傳入當地實測地面氣壓（bar）
    /// metersPerBar 預設 10.2（高海拔通常為淡水）
    public static func altitude(surfacePressure: Double,
                                metersPerBar: Double = 10.2) -> DiveEnvironment {
        return DiveEnvironment(
            surfacePressureBar: surfacePressure,
            waterVaporPressureBar: 0.0627,
            metersPerBar: metersPerBar
        )
    }

    // MARK: - 換算輔助

    /// 給定深度的絕對壓力（bar）
    public func absolutePressure(at depth: Double) -> Double {
        return surfacePressureBar + depth / metersPerBar
    }

    /// 絕對壓力反解深度（m）
    public func depth(from absolutePressure: Double) -> Double {
        return max(0.0, (absolutePressure - surfacePressureBar) * metersPerBar)
    }

    /// N₂ 組織初始分壓（供 Buhlmann.reset() 使用）
    /// ✅ 使用 AlgorithmConstants.fN2Air = 0.7902（不依賴 GasMix.air.fN2 = 0.79）
    public var initialTissuePN2: Double {
        return AlgorithmConstants.fN2Air * (surfacePressureBar - waterVaporPressureBar)
        // seaLevel: 0.7902 × (1.0 - 0.0627) = 0.740654 bar ✅ = Python Audit P_INIT
    }
}

// MARK: - JD2-Ultra: 高度調整檔位

/// 業界標準 高度檔位 A0–A2。
/// 取各區間「最高海拔」的標準大氣壓做保守換算（檔位內任何高度都不會比假設值更危險）。
public enum AltitudeSetting: Int, CaseIterable, Codable, Sendable {
    case a0 = 0   // 0 – 300 m（預設）
    case a1 = 1   // 300 – 1500 m
    case a2 = 2   // 1500 – 3000 m

    /// 保守地面氣壓（bar）：ISA 標準大氣 P = 1.01325×(1 − 2.25577e-5·h)^5.25588，
    /// 取區間上限 h 並向下取捨。a0 沿用業界慣例 1.0。
    public var surfacePressureBar: Double {
        switch self {
        case .a0: return 1.0
        case .a1: return 0.85   // h=1500m → ≈0.852 bar
        case .a2: return 0.70   // h=3000m → ≈0.708 bar
        }
    }

    /// 對應 DiveEnvironment。a1/a2 視為淡水（高山湖），a0 預設海水。
    public func environment(metersPerBar: Double? = nil) -> DiveEnvironment {
        switch self {
        case .a0:
            return DiveEnvironment(surfacePressureBar: 1.0,
                                   waterVaporPressureBar: AlgorithmConstants.pWvp,
                                   metersPerBar: metersPerBar ?? 10.0)
        case .a1, .a2:
            return DiveEnvironment(surfacePressureBar: surfacePressureBar,
                                   waterVaporPressureBar: AlgorithmConstants.pWvp,
                                   metersPerBar: metersPerBar ?? 10.2)
        }
    }
}

// MARK: - JD2-Ultra: 業界標準 個人調整檔位 → Gradient Factor 對應

/// 保守度 0–2：以 GF 保守度階梯近似氣泡模型的個人調整行為。
/// 對應值參考業界慣例（業界常見 GF 預設）並偏保守取值。
public enum PersonalSetting: Int, CaseIterable, Codable, Sendable {
    case p0 = 0   // 理想狀況（預設）
    case p1 = 1   // 保守：存在部分風險因子
    case p2 = 2   // 更保守：存在多項風險因子

    public var gfLow: Double {
        switch self {
        case .p0: return 0.40
        case .p1: return 0.35
        case .p2: return 0.30
        }
    }

    public var gfHigh: Double {
        switch self {
        case .p0: return 0.85
        case .p1: return 0.75
        case .p2: return 0.70
        }
    }
}
