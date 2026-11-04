import XCTest
import DiveKit
@testable import JoyDive_

final class ImportExtraDisplayTests: XCTestCase {
    func testDecoRequiredMapsTrueFalseAndKeepsOtherValues() {
        XCTAssertEqual(ImportExtraDisplay.decoRequiredText("true", yes: "Y", no: "N"), "Y")
        XCTAssertEqual(ImportExtraDisplay.decoRequiredText("FALSE", yes: "Y", no: "N"), "N")
        XCTAssertEqual(ImportExtraDisplay.decoRequiredText("1", yes: "Y", no: "N"), "1")
    }

    func testGasSwitchesFormatsAirNitroxTrimixInOrderGiven() {
        let json = #"[{"t":0,"fO2":0.21},{"t":1420,"fO2":0.5},{"t":3605,"fO2":0.18,"fHe":0.45}]"#
        let text = ImportExtraDisplay.gasSwitchesText(json, airName: "AIR")
        XCTAssertEqual(text, "0:00 AIR → 23:40 \(GasMix.nitrox(fO2: 0.5).displayName) → 60:05 \(GasMix.trimix(fO2: 0.18, fHe: 0.45).displayName)")
    }

    /// trimix／nitrox 名稱與 DiveKit `GasMix.displayName` 逐字相同（生產碼不建構 `.trimix`，CH-23）。測試可建構。
    func testGasSwitchNamesMatchDiveKitDisplayName() {
        let json = #"[{"t":60,"fO2":0.18,"fHe":0.45},{"t":120,"fO2":0.325},{"t":180,"fO2":0.105,"fHe":0.555}]"#
        let text = ImportExtraDisplay.gasSwitchesText(json, airName: "Air")
        let expected = "1:00 \(GasMix.trimix(fO2: 0.18, fHe: 0.45).displayName) → 2:00 \(GasMix.nitrox(fO2: 0.325).displayName) → 3:00 \(GasMix.trimix(fO2: 0.105, fHe: 0.555).displayName)"
        XCTAssertEqual(text, expected)
        XCTAssertEqual(text, "1:00 Tx18/45 → 2:00 EANx32.5 → 3:00 Tx10.5/55.5")
    }

    func testGasSwitchesReturnsNilForUndecodableOrEmpty() {
        XCTAssertNil(ImportExtraDisplay.gasSwitchesText("not json", airName: "Air"))
        XCTAssertNil(ImportExtraDisplay.gasSwitchesText("[]", airName: "Air"))
    }
}
