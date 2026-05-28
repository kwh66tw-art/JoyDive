// DiveLog.swift — JD2Core/Models/DiveLog.swift
// v1.0 INITIAL
//
// 潛水日誌數據模型，用於記錄單次潛水的完整信息
// 與 SwiftData 整合，支援本地持久化

import Foundation
import SwiftData

// MARK: - 剖面樣本

/// 單一深度剖面樣本點
/// 使用短 CodingKey（t/d）節省 JSON 體積（一次潛水可能數百個樣本）
struct DiveProfileSample: Codable {
    let timeSeconds: Double   // 距潛水開始的秒數
    let depthMeters: Double   // 深度（公尺）

    enum CodingKeys: String, CodingKey {
        case timeSeconds = "t"
        case depthMeters = "d"
    }
}

@Model
final class DiveLog {

    // MARK: - 基本信息

    /// 潛水日期與時間
    var dateTime: Date

    /// 潛水地點名稱
    var location: String

    /// 潛水地點緯度（可選）
    var latitude: Double?

    /// 潛水地點經度（可選）
    var longitude: Double?

    // MARK: - 潛水參數

    /// 最大深度（公尺）
    var maxDepth: Double

    /// 潛水時間（秒）
    var diveTimeSeconds: Int

    /// 氣體配置（JSON 編碼的 GasMix enum）
    var gasMixJSON: String  // 臨時方案：存儲 GasMix 的 JSON 表示

    /// 水溫（攝氏度）
    var waterTemperature: Double

    // MARK: - 環境信息

    /// 潛水環境類型: "seawater", "freshwater", "altitude"
    var environmentType: String = "seawater"

    /// 海平面氣壓（bar），用於高海拔環境
    var surfacePressureBar: Double = 1.0

    /// 深度換算係數（m/bar）
    var metersPerBar: Double = 10.0

    // MARK: - 額外信息

    /// 潛水備註
    var notes: String = ""

    /// 潛伴名字（可選）
    var buddy: String?

    /// 深度剖面樣本（JSON 編碼）
    /// 格式：[{"t":10.0,"d":4.07},...] t=秒數, d=深度(m)
    /// SwiftData lightweight migration：有預設值，舊記錄自動補 "[]"
    var profileSamplesJSON: String = "[]"

    /// 源檔案格式: "UDDF", "SHEARWATER", "Garmin" 等
    var sourceFormat: String = "manual"

    /// 創建時間戳
    var createdAt: Date

    /// 最後修改時間戳
    var updatedAt: Date

    // MARK: - 初始化

    /// 建立新潛水日誌
    /// - Parameters:
    ///   - dateTime: 潛水日期時間
    ///   - location: 潛水地點
    ///   - maxDepth: 最大深度（公尺）
    ///   - diveTimeSeconds: 潛水時間（秒）
    ///   - gasMixJSON: 氣體配置（GasMix 的 JSON 表示）
    ///   - waterTemperature: 水溫（攝氏度）
    init(
        dateTime: Date,
        location: String,
        maxDepth: Double,
        diveTimeSeconds: Int,
        gasMixJSON: String = "\"air\"",
        waterTemperature: Double = 15.0
    ) {
        self.dateTime = dateTime
        self.location = location
        self.maxDepth = maxDepth
        self.diveTimeSeconds = diveTimeSeconds
        self.gasMixJSON = gasMixJSON
        self.waterTemperature = waterTemperature

        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }

    // MARK: - 計算屬性

    /// 潛水時間（分鐘）
    var diveTimeMinutes: Int {
        diveTimeSeconds / 60
    }

    /// 潛水時間格式化字串 (HH:MM:SS)
    var diveTimeFormatted: String {
        let hours = diveTimeSeconds / 3600
        let minutes = (diveTimeSeconds % 3600) / 60
        let seconds = diveTimeSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// 日期格式化字串 (YYYY-MM-DD)
    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: dateTime)
    }

    /// 時間格式化字串 (HH:MM)
    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: dateTime)
    }

    /// 解碼後的剖面樣本陣列（chart 用）
    var profileSamples: [DiveProfileSample] {
        guard let data = profileSamplesJSON.data(using: .utf8),
              let samples = try? JSONDecoder().decode([DiveProfileSample].self, from: data)
        else { return [] }
        return samples
    }

    /// 深度與時間的平均下潛速率 (m/min)
    var averageAscentRate: Double {
        guard diveTimeSeconds > 0 else { return 0 }
        // 簡化計算：假設潛水時間內均勻上升
        let timeInMinutes = Double(diveTimeSeconds) / 60.0
        return maxDepth / timeInMinutes
    }

    // MARK: - 方法

    /// 更新潛水信息
    /// - Parameter updates: 更新內容
    func update(
        location: String? = nil,
        maxDepth: Double? = nil,
        waterTemperature: Double? = nil,
        notes: String? = nil
    ) {
        if let location = location { self.location = location }
        if let maxDepth = maxDepth { self.maxDepth = maxDepth }
        if let waterTemperature = waterTemperature { self.waterTemperature = waterTemperature }
        if let notes = notes { self.notes = notes }

        self.updatedAt = Date()
    }

    /// 設定潛水地點座標
    func setLocation(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.updatedAt = Date()
    }

    /// 設定環境信息（海水/淡水/高海拔）
    func setEnvironment(
        type: String,
        surfacePressure: Double? = nil,
        metersPerBar: Double? = nil
    ) {
        self.environmentType = type
        if let surfacePressure = surfacePressure {
            self.surfacePressureBar = surfacePressure
        }
        if let metersPerBar = metersPerBar {
            self.metersPerBar = metersPerBar
        }
        self.updatedAt = Date()
    }

    // MARK: - 調試

    var debugDescription: String {
        """
        DiveLog(
          date: \(dateFormatted) \(timeFormatted),
          location: \(location),
          depth: \(maxDepth)m,
          time: \(diveTimeFormatted),
          temp: \(waterTemperature)°C
        )
        """
    }
}
