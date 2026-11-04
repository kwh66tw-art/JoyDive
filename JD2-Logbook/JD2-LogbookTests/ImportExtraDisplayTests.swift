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

    func testGasSwitchesReturnsNilForUndecodableOrEmpty() {
        XCTAssertNil(ImportExtraDisplay.gasSwitchesText("not json", airName: "Air"))
        XCTAssertNil(ImportExtraDisplay.gasSwitchesText("[]", airName: "Air"))
    }
}
