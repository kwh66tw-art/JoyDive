// DivingLogSQLiteParser.swift — JD2Core/Importers/
// v1.1 格式擴充：Diving Log 6.0（Windows 潛水日誌軟體）的 SQLite 資料庫匯出檔。
//
// 與其他品牌的專有二進位格式不同，Diving Log 直接用標準 SQLite 資料庫儲存
// （欄位命名清楚：Divedate/Entrytime/Divetime/Depth/DepthAvg/Watertemp/O2/He），
// 用系統內建 libsqlite3（iOS/macOS 皆原生內建，無需第三方套件）即可直接查詢，
// 不必逆向工程任何二進位格式。
//
// ⚠️ Logbook 資料表另有 `Profile`/`Profile2..5` 欄位存放深度剖面數據（自訂
// 數字編碼字串，非標準格式），本版本暫不解碼——沒有剖面樣本不影響日期/
// 深度/時長/水溫/氣體等核心欄位的正確性，僅互動剖面圖與組織艙分析頁籤
// 對此格式不可用，優於臆測編碼規則產生錯誤剖面。
//
// Comments 欄位為 RTF 格式（Windows RichTextBox 慣例），用 NSAttributedString
// 的 RTF document type 轉純文字，比自行剝除 RTF 控制碼可靠。

import Foundation
#if canImport(SQLite3)
import SQLite3
#endif

struct DivingLogSQLiteParser: DiveLogImporter {

    let format = DiveLogFormat.divingLog

    func canHandle(filePath: String) -> Bool {
        let ext = (filePath as NSString).pathExtension.lowercased()
        guard ext == "sql" || ext == "sqlite" || ext == "db" else { return false }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath),
                                   options: .mappedIfSafe) else { return false }
        return validateContent(data)
    }

    func validateContent(_ data: Data) -> Bool {
        guard data.count >= 16 else { return false }
        // SQLite 檔案標頭固定為 "SQLite format 3\0"
        guard data.prefix(16).elementsEqual(Array("SQLite format 3\0".utf8)) else { return false }
        // 內容需含 Diving Log 特有的 Logbook 資料表
        guard let text = String(data: data, encoding: .isoLatin1) else { return false }
        return text.contains("CREATE TABLE Logbook") || text.contains("CREATE TABLE 'Logbook'")
    }

    func parse(from filePath: String) throws -> [DiveLog] {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw DiveLogImportError.fileNotFound(filePath)
        }
        return try Self.parseDatabase(at: filePath)
    }

    // MARK: - SQLite 查詢

    static func parseDatabase(at filePath: String) throws -> [DiveLog] {
        #if canImport(SQLite3)
        var db: OpaquePointer?
        // SQLITE_OPEN_READONLY：匯入僅讀取，不修改使用者原始檔案
        guard sqlite3_open_v2(filePath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            sqlite3_close(db)
            throw DiveLogImportError.corruptedData("無法開啟 SQLite 資料庫: \(filePath)")
        }
        defer { sqlite3_close(db) }

        let sql = """
        SELECT Divedate, Entrytime, Divetime, Depth, DepthAvg, Watertemp,
               O2, He, Place, City, Country, Comments
        FROM Logbook
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw DiveLogImportError.parsingFailed("SQL 查詢準備失敗（非 Diving Log 資料庫結構？）")
        }
        defer { sqlite3_finalize(statement) }

        var results: [DiveLog] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let dive = buildDiveLog(from: statement) else { continue }
            results.append(dive)
        }

        guard !results.isEmpty else {
            throw DiveLogImportError.parsingFailed("Logbook 資料表無有效潛水紀錄")
        }
        return results
        #else
        throw DiveLogImportError.unsupportedFormat("此平台無 SQLite3 支援")
        #endif
    }

    #if canImport(SQLite3)
    private static func buildDiveLog(from statement: OpaquePointer) -> DiveLog? {
        guard let dateStr = columnText(statement, 0), let timeStr = columnText(statement, 1),
              let dateTime = parseDateTime(date: dateStr, time: timeStr)
        else { return nil }

        let diveTimeMinutes = sqlite3_column_double(statement, 2)
        let diveTimeSeconds = Int((diveTimeMinutes * 60).rounded())
        let maxDepth = sqlite3_column_double(statement, 3)
        guard diveTimeSeconds > 0, maxDepth >= 0 else { return nil }

        let depthAvg = sqlite3_column_type(statement, 4) != SQLITE_NULL ? sqlite3_column_double(statement, 4) : nil
        let waterTemp = sqlite3_column_type(statement, 5) != SQLITE_NULL ? sqlite3_column_double(statement, 5) : 15.0
        let o2 = sqlite3_column_type(statement, 6) != SQLITE_NULL ? sqlite3_column_double(statement, 6) : nil
        let he = sqlite3_column_type(statement, 7) != SQLITE_NULL ? sqlite3_column_double(statement, 7) : nil
        let place = columnText(statement, 8)
        let city = columnText(statement, 9)
        let country = columnText(statement, 10)
        let commentsRTF = columnText(statement, 11)

        let location = [place, city, country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        let dive = DiveLog(
            dateTime: dateTime,
            location: location,
            maxDepth: maxDepth,
            diveTimeSeconds: diveTimeSeconds,
            gasMixJSON: buildGasMixJSON(o2Pct: o2, hePct: he),
            waterTemperature: waterTemp ?? 15.0
        )
        dive.sourceFormat = "divinglog"
        if let depthAvg { dive.avgDepth = depthAvg }
        if let rtf = commentsRTF, let plainText = plainText(fromRTF: rtf), !plainText.isEmpty {
            dive.notes = plainText
        }
        return dive
    }

    private static func columnText(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let cString = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: cString)
    }
    #endif

    /// "2015-05-23" + "13:23" → Date（無時區資訊，視為 UTC）
    private static func parseDateTime(date: String, time: String) -> Date? {
        let dp = date.split(separator: "-").map(String.init)
        guard dp.count == 3, let year = Int(dp[0]), let month = Int(dp[1]), let day = Int(dp[2])
        else { return nil }
        let tp = time.split(separator: ":").map(String.init)
        let hour = tp.count >= 1 ? (Int(tp[0]) ?? 0) : 0
        let minute = tp.count >= 2 ? (Int(tp[1]) ?? 0) : 0

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute
        return cal.date(from: comps)
    }

    private static func buildGasMixJSON(o2Pct: Double?, hePct: Double?) -> String {
        guard let o2 = o2Pct, o2 > 0 else { return "\"air\"" }
        let fO2 = o2 / 100.0
        let fHe = (hePct ?? 0) / 100.0
        if fHe > 0.001 {
            return "{\"trimix\":{\"fO2\":\(String(format: "%.2f", fO2))," +
                   "\"fHe\":\(String(format: "%.2f", fHe))}}"
        } else if abs(fO2 - 0.21) < 0.005 {
            return "\"air\""
        } else {
            return "{\"nitrox\":{\"fO2\":\(String(format: "%.2f", fO2))}}"
        }
    }

    /// RTF → 純文字（Windows RichTextBox 慣例輸出）
    /// 手動剝除控制字組，而非用 NSAttributedString 的 RTF document type——
    /// 該 API 在 iOS 僅隨 UIKit 提供，會破壞 JD2Core 對 UIKit 零依賴的架構界線
    /// （且 macOS 無 UIKit，本來就無法共用）。僅需純文字內容，不需完整排版還原。
    private static func plainText(fromRTF rtf: String) -> String? {
        guard rtf.hasPrefix("{\\rtf") else { return rtf }   // 非 RTF，原樣返回
        // 已知限制：不區分 fonttbl/colortbl 等「目的地群組」，該群組內的純文字
        // （如字型名稱）會被當作內文保留；真實筆記內容通常不受影響。

        var result = ""
        let chars = Array(rtf)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            switch c {
            case "\\":
                i += 1
                guard i < chars.count else { break }
                if chars[i] == "'" , i + 2 < chars.count {
                    // \'hh 十六進位跳脫字元（Windows-1252/Latin-1）
                    let hex = String(chars[(i + 1)...(i + 2)])
                    if let byte = UInt8(hex, radix: 16) {
                        result.append(Character(UnicodeScalar(byte)))
                    }
                    i += 3
                    continue
                }
                if chars[i] == "\\" || chars[i] == "{" || chars[i] == "}" {
                    result.append(chars[i])
                    i += 1
                    continue
                }
                // 控制字組：\word 後可接負號與數字參數，以空白或非字母結尾
                var word = ""
                while i < chars.count, chars[i].isLetter {
                    word.append(chars[i]); i += 1
                }
                while i < chars.count, chars[i].isNumber || chars[i] == "-" {
                    i += 1
                }
                if i < chars.count, chars[i] == " " { i += 1 }   // 控制字組後的單一空白是分隔符，非內容
                if word == "par" || word == "line" { result.append("\n") }
            case "{", "}":
                i += 1
            default:
                result.append(c)
                i += 1
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
