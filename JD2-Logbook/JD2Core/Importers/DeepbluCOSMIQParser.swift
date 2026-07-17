// DeepbluCOSMIQParser.swift — JD2Core/Importers/
// v1.1 格式擴充：Deepblu COSMIQ+ 雲端 API JSON payload。
//
// ⚠️ 格式假設（同 GarminConnectJSONParser 的既有慣例）：Deepblu 官方未提供
// 公開 API 文件，本實作依 file_format_research 的欄位假設建構，**尚無真實
// 匯出樣本驗證**。內容偵測要求同時具備 dive_time_seconds／max_depth_meter／
// profile_points 三個關鍵欄位，降低誤吞其他 JSON 格式的風險；欄位名稱若與
// 真實 API 不符則 canHandle 會直接不匹配（fail closed，不會硬吞後產生錯誤
// 資料），待未來取得真實匯出檔可再校正。

import Foundation

struct DeepbluCOSMIQParser: DiveLogImporter {

    let format = DiveLogFormat.deepblu

    func canHandle(filePath: String) -> Bool {
        let ext = (filePath as NSString).pathExtension.lowercased()
        guard ext == "json" else { return false }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath),
                                   options: .mappedIfSafe) else { return false }
        return validateContent(data)
    }

    func validateContent(_ data: Data) -> Bool {
        guard let head = String(data: data.prefix(2048), encoding: .utf8) else { return false }
        return head.contains("dive_time_seconds")
            && head.contains("max_depth_meter")
            && head.contains("profile_points")
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
        return try Self.parseJSONData(data)
    }

    // MARK: - 靜態輔助（供單元測試直接呼叫）

    static func parseJSONData(_ data: Data) throws -> [DiveLog] {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw DiveLogImportError.parsingFailed("JSON 解析失敗", underlyingError: error)
        }

        let entries: [[String: Any]]
        if let single = json as? [String: Any] {
            entries = [single]
        } else if let array = json as? [[String: Any]] {
            entries = array
        } else {
            throw DiveLogImportError.invalidFormat("非 Deepblu COSMIQ+ JSON 結構")
        }

        let dives = entries.compactMap(buildDive)
        guard !dives.isEmpty else {
            throw DiveLogImportError.parsingFailed("找不到有效的潛水紀錄")
        }
        return dives
    }

    private static func buildDive(from entry: [String: Any]) -> DiveLog? {
        guard let durationNum = entry["dive_time_seconds"] as? NSNumber,
              let maxDepthNum = entry["max_depth_meter"] as? NSNumber,
              let startStr = entry["start_datetime"] as? String,
              let dateTime = parseISO8601(startStr)
        else { return nil }
        let durationSec = durationNum.intValue
        let maxDepth = maxDepthNum.doubleValue
        guard durationSec > 0, maxDepth >= 0 else { return nil }

        let waterTemp = (entry["water_temp_celsius"] as? NSNumber)?.doubleValue ?? 15.0

        let dive = DiveLog(
            dateTime: dateTime,
            location: "",
            maxDepth: maxDepth,
            diveTimeSeconds: durationSec,
            gasMixJSON: "\"air\"",   // payload 無氣體資訊
            waterTemperature: waterTemp
        )
        dive.sourceFormat = "deepblu-cosmiq"

        if let points = entry["profile_points"] as? [[String: Any]] {
            var samples: [DiveProfileSample] = []
            for point in points {
                guard let t = (point["time_sec"] as? NSNumber)?.doubleValue,
                      let d = (point["depth_m"] as? NSNumber)?.doubleValue,
                      t >= 0, d >= 0 else { continue }
                let temp = (point["temp_c"] as? NSNumber)?.doubleValue
                samples.append(DiveProfileSample(timeSeconds: t, depthMeters: d, waterTemp: temp))
            }
            samples.sort { $0.timeSeconds < $1.timeSeconds }
            if !samples.isEmpty,
               let jsonData = try? JSONEncoder().encode(samples),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                dive.profileSamplesJSON = jsonStr
            }
        }

        return dive
    }

    private static func parseISO8601(_ str: String) -> Date? {
        let fracFmt = ISO8601DateFormatter()
        fracFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fracFmt.date(from: str) { return d }
        let stdFmt = ISO8601DateFormatter()
        stdFmt.formatOptions = [.withInternetDateTime]
        return stdFmt.date(from: str)
    }
}
