// DANDL7Parser.swift — JD2Core/Importers/
// v1.1 格式擴充：DAN (Divers Alert Network) DL7 / ZXU 管線分隔文字交換格式。
//
// ⚠️ 官方規格書僅以 Word 文件形式流通、無公開線上版本；本實作field mapping
// 已對照開源 PyDL7（https://github.com/johnstonskj/PyDL7）的實際解析邏輯校正，
// 不採信初版研究文件裡「ZDT 是逐樣本剖面」的錯誤假設——ZDT 實際是「Dive
// Trailer」（每支潛水一行，記錄出水時間與最大深度），真正的逐樣本剖面是
// ZDP（本專案測試樣本檔未包含，若真實檔案有則一併支援）。
//
// 已驗證欄位（皆為 "|" 分隔，index 0 為紀錄類型如 "ZDH"，其後為資料欄位）：
//   ZDH（Dive Header）：field[5] = leave_surface_time（開始時間 YYYYMMDDHHMMSS）
//   ZDT（Dive Trailer）：field[3] = max_depth（公尺）
//                        field[4] = reach_surface_time（結束時間 YYYYMMDDHHMMSS）
//                        field[5] = min_water_temperature（攝氏）
//   ZDP（Dive Profile，可選）：field[1] = elapsed_time（秒）
//                              field[2] = depth（公尺）
//                              field[8] = water_temperature（攝氏）
//   一個檔案可能包含多組 ZDH...ZDP*...ZDT（多次潛水），ZDH 與 ZDT 用 dive
//   sequence number（field[1]）配對；沒有對應 ZDT 的 ZDH（檔案截斷等情況）
//   直接捨棄，不臆造資料。

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

        var pending: [String: PendingDive] = [:]   // sequence number → 進行中的潛水
        var results: [DiveLog] = []

        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            guard !line.isEmpty else { continue }
            let fields = line.components(separatedBy: "|")
            guard let recordType = fields.first else { continue }

            switch recordType {
            case "ZDH":
                // fields: [ZDH, seq, sample#, recordType, interval, startTime, airTemp, tankVol, o2Mode, ...]
                guard fields.count > 5 else { continue }
                let sequence = fields[1]
                guard let startTime = parseDL7DateTime(fields[5]) else { continue }
                pending[sequence] = PendingDive(sequence: sequence, startTime: startTime)

            case "ZDP":
                // fields: [ZDP, elapsedTime, depth, gasSwitch, PO2, ascentViolation, decoViolation,
                //          ceiling, waterTemp, warning, mainPressure, diluentPressure, ...]
                // ZDP 沒有攜帶 dive sequence，隸屬於「最近一筆尚未結算的 ZDH」
                guard fields.count > 2,
                      let elapsed = Double(fields[1]),
                      let depth = Double(fields[2]),
                      elapsed >= 0, depth >= 0,
                      let lastKey = pending.keys.sorted().last else { continue }
                let waterTemp: Double? = fields.count > 8 ? Double(fields[8]) : nil
                pending[lastKey]?.samples.append(
                    DiveProfileSample(timeSeconds: elapsed, depthMeters: depth, waterTemp: waterTemp)
                )

            case "ZDT":
                // fields: [ZDT, seq, sample#, maxDepth, reachSurfaceTime, minWaterTemp, pressureDrop, ...]
                guard fields.count > 4 else { continue }
                let sequence = fields[1]
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
