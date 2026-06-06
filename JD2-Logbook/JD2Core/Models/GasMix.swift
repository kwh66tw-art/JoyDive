// GasMix.swift — JoyDiveCore/Models/GasMix.swift
// v6.1 — 加入自訂 Codable（修正 air bare-string 格式）

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

    nonisolated var description: String { displayName }

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

    // MARK: - 自訂 Codable
    //
    // 全站 JSON 格式（DiveLogEditSheet / DiveLogImporter 均依此規範）：
    //   air    → "air"                              (bare JSON string)
    //   nitrox → {"nitrox":{"fO2":0.32}}
    //   trimix → {"trimix":{"fO2":0.21,"fHe":0.35}}
    //
    // Swift 合成的 Codable 對 case air 輸出 {"air":{}}，與全站格式不符，
    // 故改用自訂實作確保一致。

    private enum CodingKeys: String, CodingKey {
        case nitrox, trimix
    }

    private struct NitroxPayload: Codable {
        let fO2: Double
    }

    private struct TrimixPayload: Codable {
        let fO2: Double
        let fHe: Double
    }

    nonisolated init(from decoder: Decoder) throws {
        // 優先嘗試 bare string（air 格式）
        if let str = try? decoder.singleValueContainer().decode(String.self) {
            guard str == "air" else {
                throw DecodingError.dataCorruptedError(
                    in: try decoder.singleValueContainer(),
                    debugDescription: "Unknown GasMix string: \(str)"
                )
            }
            self = .air
            return
        }
        // 再嘗試 keyed container（nitrox / trimix 格式）
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let payload = try container.decodeIfPresent(TrimixPayload.self, forKey: .trimix) {
            self = .trimix(fO2: payload.fO2, fHe: payload.fHe)
        } else if let payload = try container.decodeIfPresent(NitroxPayload.self, forKey: .nitrox) {
            self = .nitrox(fO2: payload.fO2)
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .nitrox,
                in: container,
                debugDescription: "Unknown GasMix format"
            )
        }
    }

    nonisolated func encode(to encoder: Encoder) throws {
        switch self {
        case .air:
            var c = encoder.singleValueContainer()
            try c.encode("air")
        case .nitrox(let fO2):
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(NitroxPayload(fO2: fO2), forKey: .nitrox)
        case .trimix(let fO2, let fHe):
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(TrimixPayload(fO2: fO2, fHe: fHe), forKey: .trimix)
        }
    }
}
