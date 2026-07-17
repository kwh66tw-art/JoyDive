// MinimalZipReaderTests.swift — JD2-LogbookTests
// 純 Swift ZIP 讀取器測試（真實 .SDE 樣本，Deflate 壓縮）

import XCTest
@testable import JoyDive_

final class MinimalZipReaderTests: XCTestCase {

    private var sdePath: String {
        let here       = (#filePath as NSString).deletingLastPathComponent
        let moduleRoot = (here as NSString).deletingLastPathComponent
        let repoRoot   = (moduleRoot as NSString).deletingLastPathComponent
        return (repoRoot as NSString).appendingPathComponent("TestFiles/Suunto/SDE/TestDiveDM3.SDE")
    }

    private func skipIfMissing(_ path: String) throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: path),
                          "測試檔案不存在，略過：\((path as NSString).lastPathComponent)")
    }

    func testExtractDeflateEntry() throws {
        try skipIfMissing(sdePath)
        let zipData = try Data(contentsOf: URL(fileURLWithPath: sdePath))
        let xmlData = try MinimalZipReader.extractFirstEntry(from: zipData) {
            $0.lowercased().hasSuffix(".xml")
        }
        let text = String(data: xmlData, encoding: .isoLatin1) ?? ""
        XCTAssertTrue(text.contains("<SUUNTO>"), "解壓後應含 <SUUNTO> 根節點")
        XCTAssertTrue(text.contains("<SAMPLE>"), "解壓後應含樣本資料")
    }

    func testExtractNonexistentEntryThrows() throws {
        try skipIfMissing(sdePath)
        let zipData = try Data(contentsOf: URL(fileURLWithPath: sdePath))
        XCTAssertThrowsError(
            try MinimalZipReader.extractFirstEntry(from: zipData) { $0 == "does-not-exist.xml" }
        )
    }

    func testExtractFromNonZipDataThrows() {
        let data = Data("not a zip file".utf8)
        XCTAssertThrowsError(try MinimalZipReader.extractFirstEntry(from: data) { _ in true })
    }
}
