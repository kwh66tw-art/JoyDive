// DiveEnvironment.swift — JoyDiveCore/Models/DiveEnvironment.swift
// v3.0 FINAL 🔒

import Foundation

struct DiveEnvironment: Equatable {

    /// 海平面氣壓（bar）
    /// ✅ 1.0 bar（與 Python Audit 及 Bühlmann 原著一致）
    /// 注：物理上 1 atm = 1.01325 bar，但業界潛水電腦普遍使用 1.0 bar 簡化計算
    let surfacePressureBar: Double

    /// 水蒸氣分壓（bar），37°C 體溫恆定
    let waterVaporPressureBar: Double

    /// 深度換算係數（m/bar）
    /// 海水（≈1025 kg/m³）：10.0 m/bar（業界標準）
    /// 淡水（≈1000 kg/m³）：10.2 m/bar（物理精確值 10.197）
    ///   注：某些業界規範（如 EN 13319 部分校準基準）使用 10.3，@30m 差距 < 0.3m
    /// ⚠️ 不得在潛水中途切換（影響所有 Schreiner 計算）
    let metersPerBar: Double

    // MARK: - 預設環境

    /// 標準海水，預設值，與 Python Audit 完全對齊
    static let seaLevel = DiveEnvironment(
        surfacePressureBar: 1.0,
        waterVaporPressureBar: 0.0627,
        metersPerBar: 10.0
    )

    /// 淡水環境（湖潛、洞穴潛水）
    /// ⚠️ 高海拔淡水（如 Titicaca 湖 3812m、清邁高山湖）請使用 altitude()
    ///    此預設 surfacePressureBar = 1.0 僅適用於海平面附近的淡水場景
    static let freshwater = DiveEnvironment(
        surfacePressureBar: 1.0,
        waterVaporPressureBar: 0.0627,
        metersPerBar: 10.2
    )

    /// 高海拔環境，傳入當地實測地面氣壓（bar）
    /// metersPerBar 預設 10.2（高海拔通常為淡水）
    static func altitude(surfacePressure: Double,
                         metersPerBar: Double = 10.2) -> DiveEnvironment {
        return DiveEnvironment(
            surfacePressureBar: surfacePressure,
            waterVaporPressureBar: 0.0627,
            metersPerBar: metersPerBar
        )
    }

    // MARK: - 換算輔助

    /// 給定深度的絕對壓力（bar）
    func absolutePressure(at depth: Double) -> Double {
        return surfacePressureBar + depth / metersPerBar
    }

    /// 絕對壓力反解深度（m）
    /// - Parameter absolutePressure: 絕對壓力（bar），已包含 surfacePressureBar
    ///   SensorService 若取得相對壓力（已扣大氣壓），請直接乘以 metersPerBar
    func depth(from absolutePressure: Double) -> Double {
        return max(0.0, (absolutePressure - surfacePressureBar) * metersPerBar)
    }

    /// N₂ 組織初始分壓（供 Buhlmann.reset() 使用）
    /// ✅ 使用 AlgorithmConstants.fN2Air = 0.7902（不依賴 GasMix.air.fN2 = 0.79）
    ///    職責分離：GasMix.air.fN2 = 0.79 用於氣體加總；fN2Air = 0.7902 用於組織初始化
    var initialTissuePN2: Double {
        return AlgorithmConstants.fN2Air * (surfacePressureBar - waterVaporPressureBar)
        // seaLevel: 0.7902 × (1.0 - 0.0627) = 0.740654 bar ✅ = Python Audit P_INIT
    }
}
