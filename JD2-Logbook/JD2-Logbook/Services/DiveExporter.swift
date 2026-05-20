// DiveExporter.swift — JD2-Logbook/Services/
// Week 12 — Premium Export：UDDF 3.2.2 + CSV（RFC 4180）
//
// 使用方式：
//   let url = try DiveExporter.exportToTempFile([dive], as: .uddf)
//   // 呈現 ActivityView(item: ExportItem(url: url)) 後系統自動清理
//
// 溫度單位：UDDF 3.2 規範使用 Kelvin（K = °C + 273.15）
// GPS 座標：nil 時 UDDF 省略 <geography>；CSV 輸出空欄位（避免 Null Island 0,0）
// Temp 清理：每次 exportToTempFile 呼叫前先清除舊的 JD2-Logbook-* 檔案

import Foundation

// MARK: - ExportFormat

enum ExportFormat: String, CaseIterable {
    case uddf = "UDDF"
    case csv  = "CSV"

    var fileExtension: String {
        switch self {
        case .uddf: return "uddf"
        case .csv:  return "csv"
        }
    }
}

// MARK: - ExportItem（用於 .sheet(item:) 觸發 ActivityView）

struct ExportItem: Identifiable {
    let id  = UUID()
    let url: URL
}

// MARK: - DiveExporter

struct DiveExporter {

    // MARK: - Public API

    /// 清除 temp 目錄中所有 JD2-Logbook-* 舊導出檔。
    /// 在每次 exportToTempFile 前自動呼叫，也可手動呼叫。
    static func cleanupTempFiles() {
        let tmp = FileManager.default.temporaryDirectory
        let candidates = (try? FileManager.default.contentsOfDirectory(
            at: tmp,
            includingPropertiesForKeys: nil
        )) ?? []
        for url in candidates where url.lastPathComponent.hasPrefix("JD2-Logbook-") {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// 將指定潛水記錄導出為 temp 檔案，回傳 URL 供 ActivityView 分享。
    /// - 呼叫前自動清理舊 temp 檔案。
    /// - Parameters:
    ///   - dives: 要導出的潛水記錄陣列
    ///   - format: 導出格式（.uddf / .csv）
    /// - Returns: temp 檔案的 URL
    static func exportToTempFile(_ dives: [DiveLog], as format: ExportFormat) throws -> URL {
        cleanupTempFiles()
        let data     = export(dives, as: format)
        let filename = fileName(for: format, diveCount: dives.count)
        let url      = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// 直接回傳導出的 Data（單元測試用）。
    static func export(_ dives: [DiveLog], as format: ExportFormat) -> Data {
        switch format {
        case .uddf: return uddfData(from: dives)
        case .csv:  return csvData(from: dives)
        }
    }

    /// 導出檔案命名：JD2-Logbook-{N}dives-{yyyy-MM-dd}.{ext}
    static func fileName(for format: ExportFormat, diveCount: Int) -> String {
        let dateStr = DateFormatter.exportDate.string(from: Date())
        return "JD2-Logbook-\(diveCount)dives-\(dateStr).\(format.fileExtension)"
    }

    // MARK: - UDDF 3.2.2

    static func uddfData(from dives: [DiveLog]) -> Data {
        let nowISO = ISO8601DateFormatter().string(from: Date())

        var xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.2">
          <generator>
            <name>JD2 Logbook</name>
            <version>1.0</version>
            <datetime>\(nowISO)</datetime>
          </generator>
          <diver>
            <owner id="owner">
              <personal>
                <firstname>JD2</firstname>
                <lastname>Logbook User</lastname>
              </personal>
            </owner>
          </diver>
          <profiledata>
            <repetitiongroup id="rg1">
        """

        for (i, dive) in dives.enumerated() {
            let diveID          = "dive\(i + 1)"
            let iso8601         = ISO8601DateFormatter().string(from: dive.dateTime)
            let locationEscaped = xmlEscape(dive.location.isEmpty ? "Unknown" : dive.location)
            let notesEscaped    = xmlEscape(dive.notes)

            // ── informationbeforedive ──────────────────────
            xml += """

              <dive id="\(diveID)">
                <informationbeforedive>
                  <datetime>\(iso8601)</datetime>
                  <divenumber>\(i + 1)</divenumber>
                  <divelocation>
                    <name>\(locationEscaped)</name>
            """

            // GPS：nil 時省略 <geography>，避免 Null Island 0,0
            if let lat = dive.latitude, let lon = dive.longitude {
                xml += """

                      <geography>
                        <latitude>\(lat)</latitude>
                        <longitude>\(lon)</longitude>
                      </geography>
            """
            }

            xml += """

                  </divelocation>
                </informationbeforedive>
                <samples/>
            """

            // ── informationafterdive ───────────────────────
            // 溫度單位：UDDF 3.2 規範使用 Kelvin
            let tempKelvin = dive.waterTemperature + 273.15

            xml += """

                <informationafterdive>
                  <greatestdepth>\(String(format: "%.2f", dive.maxDepth))</greatestdepth>
                  <diveduration>\(dive.diveTimeSeconds)</diveduration>
                  <temperaturemin>\(String(format: "%.2f", tempKelvin))</temperaturemin>
            """

            if !notesEscaped.isEmpty {
                xml += """

                      <notes>\(notesEscaped)</notes>
                """
            }

            xml += """

                </informationafterdive>
              </dive>
            """
        }

        xml += """

            </repetitiongroup>
          </profiledata>
        </uddf>
        """

        return Data(xml.utf8)
    }

    // MARK: - CSV（RFC 4180）

    static func csvData(from dives: [DiveLog]) -> Data {
        let header = "Date,Time,Location,Max Depth (m),Duration (s),Duration (min)," +
                     "Water Temp (°C),Gas,Environment,Buddy,Latitude,Longitude,Notes"

        var rows: [String] = [header]

        let dateFmt = DateFormatter.exportDate
        let timeFmt = DateFormatter.exportTime

        for dive in dives {
            let date = dateFmt.string(from: dive.dateTime)
            let time = timeFmt.string(from: dive.dateTime)
            let gas  = gasMixDescription(from: dive.gasMixJSON)

            // GPS：nil 時輸出空欄位，避免 Null Island 0,0
            let latStr = dive.latitude.map  { String(format: "%.6f", $0) } ?? ""
            let lonStr = dive.longitude.map { String(format: "%.6f", $0) } ?? ""

            let row: [String] = [
                csvField(date),
                csvField(time),
                csvField(dive.location),
                String(format: "%.2f", dive.maxDepth),
                "\(dive.diveTimeSeconds)",
                String(format: "%.1f", Double(dive.diveTimeSeconds) / 60.0),
                String(format: "%.1f", dive.waterTemperature),
                csvField(gas),
                csvField(dive.environmentType),
                csvField(dive.buddy ?? ""),
                latStr,
                lonStr,
                csvField(dive.notes)
            ]
            rows.append(row.joined(separator: ","))
        }

        return Data(rows.joined(separator: "\r\n").utf8)   // RFC 4180：CRLF 換行
    }

    // MARK: - Private Helpers

    /// RFC 4180：含逗號 / 雙引號 / 換行的欄位用雙引號包裹，內部雙引號加倍
    private static func csvField(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }

    /// XML 特殊字元轉義
    private static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&",  with: "&amp;")
         .replacingOccurrences(of: "<",  with: "&lt;")
         .replacingOccurrences(of: ">",  with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "'",  with: "&apos;")
    }

    /// 從 JSON 字串解碼 GasMix，回傳可讀氣體名稱
    private static func gasMixDescription(from json: String) -> String {
        guard let data = json.data(using: .utf8),
              let gas  = try? JSONDecoder().decode(GasMix.self, from: data) else {
            return "Air"
        }
        return gas.displayName
    }
}

// MARK: - DateFormatter Extensions（僅在此檔案使用）

private extension DateFormatter {
    static let exportDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale     = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static let exportTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.locale     = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
