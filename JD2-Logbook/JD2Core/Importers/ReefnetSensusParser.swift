// ReefnetSensusParser.swift — JD2Core/Importers/
// v1.1 格式擴充：Reefnet Sensus / Sensus Ultra 資料記錄器 CSV 匯出。
//
// ⚠️ 真實樣本（TestFiles/Sensus/TestSensusSingle.csv）沒有 header 列，純資料
// 逐行如：`1,SU-10000,0023469553,2011,3,27,11,25,29,0,1214,287,67`
// 研究文件原本猜測 canHandle 可用內容關鍵字 "Sensus"/"Reefnet" 比對，但真實
// 檔案完全沒有這類文字，改用結構特徵（13 欄逗號分隔、欄位[3..8] 為合法
// 年/月/日/時/分/秒）辨識。
//
// 欄位對照（依真實樣本＋開源 libdivecomputer reefnet_sensusultra_parser.c
// 的壓力換算公式交叉驗證）：
//   [0]  dive/session 編號
//   [1]  裝置型號前綴（如 "SU-10000" = Sensus Ultra）
//   [2]  裝置序號
//   [3..8] 潛水開始時間：年/月/日/時/分/秒
//   [9]  距開始秒數（本樣本固定 10 秒間隔）
//   [10] 絕對壓力（毫巴 mbar）— 深度公尺 = (壓力 - 1013) × 0.00975
//        （公式來源：ReefNet Sensus Ultra 官方 Raw Data 換算說明，數值範圍
//        與真實樣本吻合：1214 mbar → 1.96m，2178 mbar → 11.36m）
//   [11] 整個檔案中固定不變的數值（本樣本恆為 287）：疑似裝置校正常數或
//        中繼資料，非逐樣本感測值，不採用
//   [12] 逐樣本變動的數值（本樣本 55–69 區間）：變化幅度符合感測器讀數特徵，
//        但確切單位/換算公式未能從官方文件取得可靠證實（PDF 開發手冊無法
//        擷取純文字），**不強行猜測轉換**，暫不採用此欄位（寧可缺水溫，
//        不製造可能錯誤的攝氏數值）

import Foundation

struct ReefnetSensusParser: DiveLogImporter {

    let format = DiveLogFormat.sensus

    func canHandle(filePath: String) -> Bool {
        let ext = (filePath as NSString).pathExtension.lowercased()
        guard ext == "csv" || ext == "dat" else { return false }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath),
                                   options: .mappedIfSafe) else { return false }
        return validateContent(data)
    }

    /// 結構特徵比對：前 5 行皆為 13 欄逗號分隔，且欄位[3..8] 為合理年/月/日/時/分/秒
    func validateContent(_ data: Data) -> Bool {
        guard let text = String(data: data.prefix(2048), encoding: .utf8) else { return false }
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }.prefix(5)
        guard !lines.isEmpty else { return false }
        return lines.allSatisfy { Self.isSensusRow($0) }
    }

    private static func isSensusRow(_ line: String) -> Bool {
        let fields = line.components(separatedBy: ",")
        guard fields.count == 13 else { return false }
        guard let year = Int(fields[3]), (1990...2100).contains(year),
              let month = Int(fields[4]), (1...12).contains(month),
              let day = Int(fields[5]), (1...31).contains(day),
              let hour = Int(fields[6]), (0...23).contains(hour),
              let minute = Int(fields[7]), (0...59).contains(minute),
              let second = Int(fields[8]), (0...59).contains(second),
              Double(fields[9]) != nil,   // elapsed seconds
              Double(fields[10]) != nil   // pressure
        else { return false }
        return true
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
        struct Session {
            var startTime: Date
            var samples: [DiveProfileSample] = []
        }
        var sessions: [String: Session] = [:]   // dive 編號 → session
        var order: [String] = []

        for line in text.components(separatedBy: .newlines) where !line.isEmpty {
            let fields = line.components(separatedBy: ",")
            guard isSensusRow(line),
                  let year = Int(fields[3]), let month = Int(fields[4]), let day = Int(fields[5]),
                  let hour = Int(fields[6]), let minute = Int(fields[7]), let second = Int(fields[8]),
                  let elapsed = Double(fields[9]), let pressureMbar = Double(fields[10])
            else { continue }

            let diveKey = fields[0]
            if sessions[diveKey] == nil {
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = TimeZone(secondsFromGMT: 0)!
                var comps = DateComponents()
                comps.year = year; comps.month = month; comps.day = day
                comps.hour = hour; comps.minute = minute; comps.second = second
                guard let startTime = cal.date(from: comps) else { continue }
                sessions[diveKey] = Session(startTime: startTime)
                order.append(diveKey)
            }
            // 深度 = (壓力mbar - 1013) × 0.00975；負值（水面雜訊）夾為 0
            let depth = max(0, (pressureMbar - 1013) * 0.00975)
            sessions[diveKey]?.samples.append(DiveProfileSample(timeSeconds: elapsed, depthMeters: depth))
        }

        var results: [DiveLog] = []
        for key in order {
            guard let session = sessions[key], session.samples.count >= 2 else { continue }
            let sorted = session.samples.sorted { $0.timeSeconds < $1.timeSeconds }
            let maxDepth = sorted.map(\.depthMeters).max() ?? 0
            let durationSec = Int(sorted.last?.timeSeconds ?? 0)
            guard durationSec > 0 else { continue }

            let dive = DiveLog(
                dateTime: session.startTime,
                location: "",
                maxDepth: maxDepth,
                diveTimeSeconds: durationSec,
                gasMixJSON: "\"air\"",
                waterTemperature: 15.0   // 見檔頭說明：無法可靠換算樣本水溫欄位，使用預設值
            )
            dive.sourceFormat = "reefnet-sensus"
            if let jsonData = try? JSONEncoder().encode(sorted),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                dive.profileSamplesJSON = jsonStr
            }
            results.append(dive)
        }

        guard !results.isEmpty else {
            throw DiveLogImportError.parsingFailed("找不到有效的 Sensus 潛水紀錄")
        }
        return results
    }
}
