// ImportExtraDisplay.swift — JD2Core/Utilities
// v1.4 C：「原始匯入資料」裡 Diving Log／Subsurface 的值轉成可讀文字（純函式，可測）。

import Foundation
import DiveKit

enum ImportExtraDisplay {
    /// `decoRequired`（DiveImportKit `DivingLogSQLiteParser` 寫 "true"／"false"）→ 是／否；其他值原樣。
    nonisolated static func decoRequiredText(_ raw: String, yes: String, no: String) -> String {
        switch raw.lowercased() {
        case "true":  return yes
        case "false": return no
        default:      return raw
        }
    }

    /// `gasSwitches`（DiveImportKit `SubsurfaceXMLParser.buildGasSwitchesJSON`：
    /// `[{"t":秒,"fO2":0.5}, {"t":秒,"fO2":0.18,"fHe":0.45}]`）→「0:00 Air → 23:40 EANx50」。
    /// 解不開就回 nil（呼叫端顯示原字串）。
    /// 氣體分類沿用 DiveImportKit `makeGasMixJSON` 的同一規則（fHe > 0.001 ⇒ trimix；
    /// |fO2 − 0.21| < 0.005 ⇒ air；否則 nitrox），不另訂門檻。時間格式與箭頭為本專案決定。
    nonisolated static func gasSwitchesText(_ json: String, airName: String) -> String? {
        struct Item: Decodable { let t: Double; let fO2: Double; let fHe: Double? }
        guard let data = json.data(using: .utf8),
              let items = try? JSONDecoder().decode([Item].self, from: data),
              !items.isEmpty else { return nil }
        return items.map { item in
            let gas: GasMix
            if let fHe = item.fHe, fHe > 0.001 {
                gas = .trimix(fO2: item.fO2, fHe: fHe)
            } else if abs(item.fO2 - 0.21) < 0.005 {
                gas = .air
            } else {
                gas = .nitrox(fO2: item.fO2)
            }
            let name = gas == .air ? airName : gas.displayName
            let seconds = max(0, Int(item.t.rounded()))
            return String(format: "%d:%02d %@", seconds / 60, seconds % 60, name)
        }.joined(separator: " → ")
    }
}
