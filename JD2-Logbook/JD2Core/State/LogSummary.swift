// LogSummary.swift — DiveKit/State
// M22 續：日誌彙總（總支數／總時長／最深）供 widget 在「禁飛結束後」顯示更有意義的資訊。
//
// widget 為獨立 process、且日誌 SwiftData 容器不在 App Group（讀不到），故由 App 端在日誌變動時
// 計算此彙總、原子寫入 App Group 檔案；widget 讀此檔（與 computer-state.json 同層、同模式）。
// 純值型別、無 UI/SwiftData 依賴，phone app 與 widget 皆可用。

import Foundation

public struct LogSummary: Codable, Equatable, Sendable {
    public var totalDives: Int
    public var totalDiveSeconds: Int
    public var deepestMeters: Double
    public var savedAt: Date

    public init(totalDives: Int, totalDiveSeconds: Int, deepestMeters: Double,
                savedAt: Date = Date()) {
        self.totalDives = totalDives
        self.totalDiveSeconds = totalDiveSeconds
        self.deepestMeters = deepestMeters
        self.savedAt = savedAt
    }
}

/// JSON 檔案落地（App Group 優先，退 Application Support），與 FileBackedStateStore 同模式。
public struct LogSummaryStore: Sendable {

    public let fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public static func defaultStore(
        appGroup: String? = "group.com.joydive.jd2ultra") throws -> LogSummaryStore {
        let base: URL
        if let group = appGroup,
           let container = FileManager.default
               .containerURL(forSecurityApplicationGroupIdentifier: group) {
            base = container
        } else {
            base = try FileManager.default.url(for: .applicationSupportDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        }
        let dir = base.appendingPathComponent("DiveKit", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return LogSummaryStore(fileURL: dir.appendingPathComponent("log-summary.json"))
    }

    public func save(_ summary: LogSummary) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(summary).write(to: fileURL, options: [.atomic])
    }

    public func load() throws -> LogSummary? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LogSummary.self, from: Data(contentsOf: fileURL))
    }
}
