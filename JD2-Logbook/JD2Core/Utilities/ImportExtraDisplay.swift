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
    ///
    /// 🔴 trimix 不建構 `GasMix.trimix`（CH-23 `check_trimix_boundary.sh` 規則 3：三個 App 生產碼零 `.trimix(` 建構，
    /// PM 2026-09-15 trimix 不在支援範圍）。名稱直接組成與 DiveKit `GasMix.displayName` 相同格式
    /// （"Tx" + O₂% + "/" + He%，`GasMix.swift:152-154`），百分比用 Kit 公開的 `GasMix.percentText`（不取整、不另寫一份）。
    /// 與 `displayName` 唯一差別：Kit 對畸形比例（超出 0–1 或總和 > 1）先夾值，這裡顯示匯入的原值——
    /// 這是「原始匯入資料」區塊，顯示原值是本專案決定。nitrox 同樣用 `percentText`（與 `displayName` 讀原值一致）。
    nonisolated static func gasSwitchesText(_ json: String, airName: String) -> String? {
        struct Item: Decodable { let t: Double; let fO2: Double; let fHe: Double? }
        guard let data = json.data(using: .utf8),
              let items = try? JSONDecoder().decode([Item].self, from: data),
              !items.isEmpty else { return nil }
        return items.map { item in
            let name: String
            if let fHe = item.fHe, fHe > 0.001 {
                name = "Tx" + GasMix.percentText(item.fO2) + "/" + GasMix.percentText(fHe)
            } else if abs(item.fO2 - 0.21) < 0.005 {
                name = airName
            } else {
                name = "EANx" + GasMix.percentText(item.fO2)
            }
            let seconds = max(0, Int(item.t.rounded()))
            return String(format: "%d:%02d %@", seconds / 60, seconds % 60, name)
        }.joined(separator: " → ")
    }
}
