// FixtureRoot.swift — JD2-LogbookTests：測試素材路徑推算的**唯一**來源
//
// 背景：2026-10-18（PM 裁示）起，樣本（`dive-log-samples/`、`00_Import_samples/`、
// `00_Import_submission/`、`00_Import_test_scenes/`）含第三方來源與真實潛水紀錄（授權／隱私待確認），
// 已從 `AppProject/_JD2-family/` **平行搬到** `…/Documents/ProjectRecDocs/_JD2-family/`（相對路徑不變），
// 避免隨 repo 推送。本檔取代原本散在三個測試檔、各自「上溯 N 層」的路徑算式。
//
// 規則與 `_JD2-family/DiveImportKit/Tests/DiveImportKitTests/FixtureRoot.swift` 一致：
//   1. 環境變數 `JD2_FIXTURE_ROOT`（＝新位置的 `_JD2-family` 目錄；換機器或 CI 時設定）
//   2. 沒設時：本 repo 所在 `AppProject` 的上一層 ＋ `ProjectRecDocs/_JD2-family`——由本檔 `#filePath`
//      上溯算出，**不寫死使用者名**。
//   3. 素材根目錄不存在 ⇒ 測試**失敗**（`requireRoot()`），**不 XCTSkip**。
//
// 為什麼不能靜默降級：本專案曾因「缺檔優雅跳過」讓路徑斷裂綠燈掩蓋（家族稽核 T-01）；
// 另有測試用「缺檔就 `continue`／`.filter { fileExists }`」也會在根目錄錯誤時零斷言通過，
// 所以凡是用到樣本的測試都要先呼叫 `requireRoot()`。
//
// 注意：本檔刻意不引用 DiveImportKit 的測試 target（Logbook 自己的 helper）。

import Foundation
import XCTest

enum FixtureRoot {

    /// `…/ProjectRecDocs/_JD2-family`（或 `JD2_FIXTURE_ROOT` 指定的目錄）。
    static let familyRoot: String = {
        if let env = ProcessInfo.processInfo.environment["JD2_FIXTURE_ROOT"], !env.isEmpty { return env }
        let here       = (#filePath as NSString).deletingLastPathComponent  // …/JD2-Logbook/JD2-Logbook/JD2-LogbookTests
        let moduleRoot = (here as NSString).deletingLastPathComponent       // …/JD2-Logbook/JD2-Logbook
        let repoRoot   = (moduleRoot as NSString).deletingLastPathComponent // …/AppProject/JD2-Logbook（repo）
        let appProject = (repoRoot as NSString).deletingLastPathComponent   // …/AppProject
        let documents  = (appProject as NSString).deletingLastPathComponent // …/Documents（AppProject 的上一層）
        return ((documents as NSString).appendingPathComponent("ProjectRecDocs") as NSString)
            .appendingPathComponent("_JD2-family")
    }()

    /// `…/_JD2-family/dive-log-samples`
    static let samplesRoot: String = (familyRoot as NSString).appendingPathComponent("dive-log-samples")

    /// `dive-log-samples/` 底下某個相對路徑的絕對路徑（例：`"UDDF/test42.uddf"`）。
    static func path(_ relative: String) -> String {
        (samplesRoot as NSString).appendingPathComponent(relative)
    }

    /// `_JD2-family/` 底下某個相對路徑的絕對路徑（例：`"00_Import_samples/UDDF"`）。
    static func familyPath(_ relative: String) -> String {
        (familyRoot as NSString).appendingPathComponent(relative)
    }

    /// 素材根目錄存在嗎。
    static var rootExists: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: familyRoot, isDirectory: &isDir) && isDir.boolValue
    }

    struct RootMissingError: Error, CustomStringConvertible {
        let root: String
        var description: String { "測試素材根目錄不存在：\(root)" }
    }

    /// 用到樣本的測試，第一行呼叫。根目錄不存在 ⇒ 記錄失敗並丟錯（測試以**失敗**收場，不是跳過）。
    static func requireRoot(file: StaticString = #filePath, line: UInt = #line) throws {
        guard rootExists else {
            XCTFail("測試素材根目錄不存在：\(familyRoot)——樣本已於 2026-10-18 搬到 ProjectRecDocs/_JD2-family/；"
                    + "換機器請設環境變數 JD2_FIXTURE_ROOT 指向該目錄", file: file, line: line)
            throw RootMissingError(root: familyRoot)
        }
    }
}
