// GasMix.swift — JoyDiveCore/Models/GasMix.swift
// v6.0 FINAL 🔒

import Foundation

enum GasMix: Codable, Hashable, CustomStringConvertible {

    case air
    case nitrox(fO2: Double)
    case trimix(fO2: Double, fHe: Double)   // v2.0 佔位，MVP 不啟用

    // MARK: - 氣體分率
    // ⚠️ GasMix.air.fN2 = 0.79（純氣體組成加總 = 1.00）
    //    initialTissuePN2 使用 AlgorithmConstants.fN2Air = 0.7902（職責分離）
    //    DO NOT UNIFY

    var fO2: Double {
        switch self {
        case .air:                  return 0.21
        case .nitrox(let f):        return min(max(f, 0.16), 1.0)
        case .trimix(let f, _):     return f
        }
    }

    var fHe: Double {
        switch self {
        case .trimix(_, let h):     return h
        default:                    return 0.0
        }
    }

    var fN2: Double { 1.0 - fO2 - fHe }   // air: 0.79，加總 = 1.00 ✅

    // MARK: - 顯示名稱
    var displayName: String {
        switch self {
        case .air:                  return "Air"
        case .nitrox(let f):        return String(format: "EANx%d", Int(f * 100))
        case .trimix(let o, let h): return String(format: "Tx%.0f/%.0f", o*100, h*100)
        }
    }

    var description: String { displayName }

    // MARK: - MOD 計算
    /// 最大操作深度（m）
    /// - Parameters:
    ///   - maxPO2: 最大允許 PO₂（bar），預設 1.4
    ///   - surfacePressure: 海平面氣壓（bar），預設 1.0
    func mod(maxPO2: Double = 1.4, surfacePressure: Double = 1.0) -> Double {
        guard fO2 > 0 else { return Double.infinity }
        // depth = (P_abs - P_surface) × metersPerBar
        // P_abs_max = maxPO2 / fO2（忽略水蒸氣，MOD 計算慣例）
        return (maxPO2 / fO2 - surfacePressure) * 10.0
    }

    // MARK: - Trimix 執行期保護（MVP 不支援）
    var isTrimix: Bool {
        if case .trimix = self { return true }
        return false
    }
}
