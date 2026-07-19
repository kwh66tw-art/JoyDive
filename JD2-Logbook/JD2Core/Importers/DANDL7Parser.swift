// DANDL7Parser.swift — JD2Core/Importers/
// v1.1 格式擴充：DAN (Divers Alert Network) DL7 / ZXU 管線分隔文字交換格式。
//
// ⚠️ 官方規格書僅以 Word 文件形式流通、無公開線上版本；本實作field mapping
// 已對照開源 PyDL7（https://github.com/johnstonskj/PyDL7，
// divelog/dl7/__init__.py，2026-07-19 逐函式核對原始碼）的實際解析邏輯校正，
// 不採信初版研究文件裡「ZDT 是逐樣本剖面」的錯誤假設——ZDT 實際是「Dive
// Trailer」（每支潛水一行，記錄出水時間與最大深度），真正的逐樣本剖面是
// ZDP（單行或 ZDP{...ZDP} 多行區塊，兩種語法皆支援，見下）。
//
// 已驗證欄位（皆為 "|" 分隔，index 0 為紀錄類型如 "ZDH"，其後為資料欄位）：
//   ZDH（Dive Header）：__parse_dive_header(log, line) 收到的 line 是
//                        raw fields[1:]（record type 已被切掉一格），
//                        故 line[1] = dive.sequence_number 對應 raw field[2]。
//                        field[5] = leave_surface_time（開始時間 YYYYMMDDHHMMSS）
//   ZDT（Dive Trailer）：同理 __parse_dive_trailer 的 line[1] = internal
//                        sequence 對應 raw field[2]（field[1] 只是
//                        export_sequence，是檔案內流水號，不是配對用的
//                        dive number，這是本檔案原本的 bug 根源）。
//                        field[3] = max_depth（公尺）
//                        field[4] = reach_surface_time（結束時間 YYYYMMDDHHMMSS）
//                        field[5] = min_water_temperature（攝氏）
//   一個檔案可能包含多組 ZDH...ZDP*...ZDT（多次潛水），ZDH 與 ZDT 用
//   **field[2]**（PyDL7 的 dive.sequence_number／internal sequence）配對；
//   沒有對應 ZDT 的 ZDH（檔案截斷等情況）直接捨棄，不臆造資料。
//
//   ZDP（Dive Profile，可選，隸屬於最近一筆已開頭但尚未結算的 ZDH，對照
//   PyDL7 的 `dive = log.dives[len(log.dives)-1]`）有兩種語法，欄位語意一致
//   （__parse_dive_profile 收到的 line 同樣是切掉 record type 後的陣列）：
//     1) 單行：ZDP|elapsedTime|depth|gasSwitch|PO2|...|waterTemp|...
//        field[1] = elapsed_time（秒）／field[2] = depth（公尺）／
//        field[8] = water_temperature（攝氏）
//     2) 多行區塊：`ZDP{` 開始、`ZDP}` 結束，中間每行以 "|" 開頭（即該行
//        components(separatedBy: "|") 後 fields[0] == ""），後續欄位語意與
//        單行格式完全相同（fields[1]=elapsed_time／fields[2]=depth／
//        fields[8]=water_temperature）——PyDL7 dump() 寫出的正是
//        `'|%s|%s|...'`（起手就是一個 pipe，等同單行格式砍掉開頭的
//        "ZDP|" 四個字元），兩者是同一套欄位表，只是有沒有 "ZDP" 前綴的差異。
//        本檔案樣本 `_JD2-family/dive-log-samples/DAN/DL7.zxu`（Subsurface
//        官方測試檔）第二組潛水即用此區塊語法，2026-07-19 依此新增支援。

import Foundation

struct DANDL7Parser: DiveLogImporter {

    let format = DiveLogFormat.danDL7

    func canHandle(filePath: String) -> Bool {
        let ext = (filePath as NSString).pathExtension.lowercased()
        guard ["dl7", "zxu", "zxl", "txt"].contains(ext) else { return false }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath),
                                   options: .mappedIfSafe) else { return false }
        return validateContent(data)
    }

    func validateContent(_ data: Data) -> Bool {
        guard let head = String(data: data.prefix(256), encoding: .utf8) else { return false }
        return head.hasPrefix("FSH|") && head.contains("ZXU")
    }

    func parse(from filePath: String) throws -> [DiveLog] {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw DiveLogImportError.fileNotFound(filePath)
        }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath),
                                   options: .mappedIfSafe) else {
            throw DiveLogImportError.corruptedData("無法讀取: \(filePath)")
        }
        guard !data.isEmpty else { throw DiveLogImportError.emptyFile }
        guard let text = String(data: data, encoding: .utf8) else {
            throw DiveLogImportError.invalidFormat("非 UTF-8 文字檔")
        }
        return try Self.parseText(text)
    }

    // MARK: - 靜態輔助（供單元測試直接呼叫）

    static func parseText(_ text: String) throws -> [DiveLog] {
        struct PendingDive {
            var sequence: String
            var startTime: Date
            var samples: [DiveProfileSample] = []
        }

        var pending: [String: PendingDive] = [:]   // sequence number（field[2]）→ 進行中的潛水
        var results: [DiveLog] = []
        var currentKey: String?     // 最近一筆已開頭但尚未結算的 ZDH，供 ZDP 樣本歸屬用
        var inProfileBlock = false  // 是否正處於 ZDP{ ... ZDP} 多行區塊內

        /// 共用邏輯：把一筆 ZDP 樣本欄位（單行或區塊行皆同一套欄位表）掛到 currentKey 對應的潛水上
        func appendProfileSample(_ fields: [String]) {
            guard fields.count > 2,
                  let elapsed = Double(fields[1]),
                  let depth = Double(fields[2]),
                  elapsed >= 0, depth >= 0,
                  let key = currentKey else { return }
            let waterTemp: Double? = fields.count > 8 ? Double(fields[8]) : nil
            pending[key]?.samples.append(
                DiveProfileSample(timeSeconds: elapsed, depthMeters: depth, waterTemp: waterTemp)
            )
        }

        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            guard !line.isEmpty else { continue }
            let fields = line.components(separatedBy: "|")
            guard let recordType = fields.first else { continue }

            // ZDP{...ZDP} 多行區塊：區塊內每行以 "|" 開頭，components 後 fields[0] == ""，
            // 不會命中下面 switch 的任何具名 case，需在 switch 之前攔截處理。
            if inProfileBlock {
                if recordType == "ZDP}" {
                    inProfileBlock = false
                } else if recordType.isEmpty {
                    appendProfileSample(fields)
                }
                // 區塊內出現非空、非 ZDP} 的異常行（格式錯誤）：不臆造資料，靜默略過該行即可，
                // 不中斷整個區塊（沿用既有「單筆樣本壞掉不影響其他樣本」的寬容策略）。
                continue
            }

            switch recordType {
            case "ZDH":
                // fields: [ZDH, exportSeq, seq, recordType, interval, startTime, airTemp, tankVol, o2Mode, ...]
                // field[1] 只是檔案內流水號（export_sequence），field[2] 才是與 ZDT 配對用的
                // dive sequence number（PyDL7 dive.sequence_number）。
                guard fields.count > 5 else { continue }
                let sequence = fields[2]
                guard let startTime = parseDL7DateTime(fields[5]) else { continue }
                pending[sequence] = PendingDive(sequence: sequence, startTime: startTime)
                currentKey = sequence

            case "ZDP{":
                inProfileBlock = true

            case "ZDP":
                // fields: [ZDP, elapsedTime, depth, gasSwitch, PO2, ascentViolation, decoViolation,
                //          ceiling, waterTemp, warning, mainPressure, diluentPressure, ...]
                // ZDP 沒有攜帶 dive sequence，隸屬於「最近一筆尚未結算的 ZDH」
                appendProfileSample(fields)

            case "ZDT":
                // fields: [ZDT, exportSeq, seq, maxDepth, reachSurfaceTime, minWaterTemp, pressureDrop, ...]
                // 同 ZDH，field[2] 才是配對用的 dive sequence number，field[1] 不是。
                guard fields.count > 4 else { continue }
                let sequence = fields[2]
                guard let dive = pending[sequence],
                      let maxDepth = Double(fields[3]),
                      let endTime = parseDL7DateTime(fields[4])
                else { continue }
                let durationSec = Int(endTime.timeIntervalSince(dive.startTime))
                guard durationSec > 0, maxDepth >= 0 else { continue }

                let waterTemp = fields.count > 5 ? (Double(fields[5]) ?? 15.0) : 15.0
                let log = DiveLog(
                    dateTime: dive.startTime,
                    location: "",
                    maxDepth: maxDepth,
                    diveTimeSeconds: durationSec,
                    gasMixJSON: "\"air\"",   // DL7 未攜帶簡單的 O2 百分比欄位，預設 Air
                    waterTemperature: waterTemp
                )
                log.sourceFormat = "dan-dl7"
                if !dive.samples.isEmpty {
                    let sorted = dive.samples.sorted { $0.timeSeconds < $1.timeSeconds }
                    if let jsonData = try? JSONEncoder().encode(sorted),
                       let jsonStr = String(data: jsonData, encoding: .utf8) {
                        log.profileSamplesJSON = jsonStr
                    }
                }
                results.append(log)
                pending.removeValue(forKey: sequence)
                if currentKey == sequence { currentKey = nil }

            default:
                continue
            }
        }

        guard !results.isEmpty else {
            throw DiveLogImportError.parsingFailed("找不到完整的潛水紀錄（ZDH/ZDT 配對缺失）")
        }
        return results
    }

    /// "20180101101000" → YYYYMMDDHHMMSS，無時區資訊，視為 UTC（沿用專案既有慣例）
    private static func parseDL7DateTime(_ str: String) -> Date? {
        guard str.count == 14 else { return nil }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyyMMddHHmmss"
        return fmt.date(from: str)
    }
}
