// DiveLog.swift — JD2Core/Models/DiveLog.swift
// v1.0 INITIAL
//
// 潛水日誌數據模型，用於記錄單次潛水的完整信息
// 與 SwiftData 整合，支援本地持久化

import Foundation
import SwiftData
import DiveKit

// MARK: - 剖面樣本

/// 單一深度剖面樣本點
/// 使用短 CodingKey（t/d/w）節省 JSON 體積（一次潛水可能數百個樣本）
struct DiveProfileSample: Codable {
    let timeSeconds: Double     // 距潛水開始的秒數
    let depthMeters: Double     // 深度（公尺）
    /// 水溫（攝氏度）。v1.1 #4：additive optional，舊資料 / 無此欄位的匯入器解碼為 nil，優雅降級
    var waterTemp: Double?

    enum CodingKeys: String, CodingKey {
        case timeSeconds = "t"
        case depthMeters = "d"
        case waterTemp   = "w"
    }

    init(timeSeconds: Double, depthMeters: Double, waterTemp: Double? = nil) {
        self.timeSeconds = timeSeconds
        self.depthMeters = depthMeters
        self.waterTemp = waterTemp
    }
}

// MARK: - 潛水類型

/// 潛水類型（dive mode）。
///
/// **為什麼需要這個欄位**：Bühlmann 模型假設潛水者在深度**持續呼吸環境氣體**
/// （Schreiner 方程的 Palv 就是這樣定義的）；閉氣潛水（自由潛水／浮潛）只有下水前
/// 的那一口氣。若把一筆有完整剖面樣本的自由潛水當成一般前導潛水放進殘氮鏈，模型會
/// 以為「這個人在 20m 持續呼吸了兩分鐘」，算出物理上錯誤且嚴重高估的氮負荷並顯示
/// 給使用者。DiveKit `DiveReplayEngine` 因此提供 `DiveInput.isBreathHold`：前導潛水
/// 為閉氣潛水時在建鏈階段直接濾掉，目標潛水本身為閉氣潛水則回報
/// `Anomaly.breathHoldTarget`。規格見
/// `_JD2-family/decisions/2026-08-22_重放連續潛水殘氮與前置判斷-設計.md` 第六之三節。
///
/// **rawValue 與 ultra 對齊**：ultra 的 `DiveLogEntry.diveMode` 使用
/// `"air"/"nitrox"/"gauge"/"free"/"snorkel"`。閉氣的兩個值（`free`／`snorkel`）
/// **字面完全相同**，未來跨 App 同步不需轉換。水肺側 Logbook 只用單一 `"scuba"`
/// ——ultra 的 air/nitrox/gauge 三者在 Logbook 是由 `gasMixJSON` 表達的，若在此
/// 再存一份氣體資訊會出現兩個可以互相矛盾的真相來源（例如 nitrox 潛水的
/// diveMode 寫成 "air"）。同步時 ultra 的 air/nitrox/gauge 一律收斂成 `.scuba`。
///
/// ⚠️ 型別名刻意是 `DiveLogMode` 而非 `DiveMode`：DiveKit 已有 public 的
/// `DiveMode`（潛水電腦設定模式 air/nitrox/free/gauge/snorkel/off，即 ultra
/// `diveMode` 字串的來源）。本檔 `import DiveKit`，同名會造成全 App 的解析歧義。
enum DiveLogMode: String, CaseIterable, Codable, Sendable {
    /// 水肺潛水（Logbook 的預設與絕大多數紀錄）
    case scuba
    /// 自由潛水
    case free
    /// 浮潛
    case snorkel

    /// 是否為閉氣潛水（→ DiveKit `DiveInput.isBreathHold`）
    var isBreathHold: Bool { self != .scuba }
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

    // MARK: - 環境與條件詳細資訊

    /// 天氣狀況: "sunny", "cloudy", "rainy"（nil = 未記錄，匯入資料通常無此欄位）
    var weather: String?

    /// 氣溫（攝氏度，nil = 未記錄）
    var airTemperature: Double?

    /// 水面狀況: "calm", "slight", "moderate", "rough"（nil = 未記錄）
    var surfaceCondition: String?

    /// 水流強度: "none", "slight", "moderate", "strong"（nil = 未記錄）
    var waterflow: String?

    /// 能見度（公尺，nil = 未記錄）
    var visibility: Double?

    // MARK: - 時間詳細資訊

    /// 入水時間（可選）
    var entryTime: Date?

    /// 出水時間（可選）
    var exitTime: Date?

    // MARK: - 裝備信息

    /// 防寒衣厚度: "3mm", "5mm" 等（nil = 未提供，例如 dive computer 匯入）
    var wetsuitThickness: String?

    /// 配重總重量（公斤，nil = 未提供）
    var weightTotal: Double?

    /// 氣瓶材質: "aluminum", "steel"（nil = 未提供）
    var cylinderMaterial: String?

    /// 氣瓶規格：例如 "S80(12L)", "S63(8.6L)"（nil = 未提供）
    var cylinderSize: String?

    /// 氣瓶起始壓力（bar，nil = 未提供）
    var cylinderStartPressure: Double?

    /// 氣瓶結束壓力（bar，可選）
    var cylinderEndPressure: Double?

    // MARK: - 額外信息

    /// 潛水備註
    var notes: String = ""

    /// 深度剖面樣本（JSON 編碼）
    /// 格式：[{"t":10.0,"d":4.07},...] t=秒數, d=深度(m)
    /// SwiftData lightweight migration：有預設值，舊記錄自動補 "[]"
    var profileSamplesJSON: String = "[]"

    /// 源檔案格式: "UDDF", "SHEARWATER", "Garmin" 等
    var sourceFormat: String = "manual"

    /// 潛水類型（`DiveLogMode` 的 rawValue："scuba" / "free" / "snorkel"）
    ///
    /// v1.2：additive 欄位，SwiftData lightweight migration 自動補預設值 `"scuba"`
    /// ——Logbook 是水肺日誌，**既有資料一律視為水肺**，預設值使既有紀錄語意不變、
    /// `isBreathHold` 維持 false，重放行為與加欄位前完全相同。
    ///
    /// ⚠️ **已知限制：匯入路徑帶不進這個資訊。** DiveImportKit 的 `ParsedDiveLog`
    /// 目前沒有 dive mode 欄位，要接得改那個 Kit 與各解析器（家族鐵律：不得在本
    /// repo 修 Kit），因此**所有匯入紀錄一律落在預設值 `"scuba"`**，匯入的自由潛水
    /// 紀錄仍需使用者手動改成 free/snorkel 才會被排除在殘氮鏈之外。
    /// 已登錄 `V1_2_BACKLOG.md`「匯入自動帶入 dive mode」。
    ///
    /// 以 String 而非 enum 儲存：未知值（未來新增類型／他版本備份還原）解碼時由
    /// `diveModeValue` 優雅退回 `.scuba`，不會讓整筆紀錄讀不出來。
    var diveMode: String = DiveLogMode.scuba.rawValue

    /// 平均深度（公尺）。0 = 未記錄（匯入來源無此欄位）
    /// v1.1 #8：additive 欄位，SwiftData lightweight migration 自動補 0
    var avgDepth: Double = 0

    /// 匯入時無對應欄位的原始資料（裝置序號/韌體/buddy/tags 等），key-value JSON dump
    /// v1.1 #6/#7：additive 欄位，SwiftData lightweight migration 自動補 "{}"
    var importExtrasJSON: String = "{}"

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

    /// 潛水類型（型別化存取；未知 rawValue 一律退回 `.scuba`，見 `diveMode` 說明）
    var diveModeValue: DiveLogMode {
        get { DiveLogMode(rawValue: diveMode) ?? .scuba }
        set { diveMode = newValue.rawValue }
    }

    /// 解碼後的匯入原始資料（Detail view「原始資料」區塊用）
    var importExtras: [String: String] {
        guard let data = importExtrasJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict
    }

    /// 平均深度以樣本梯形近似重建（匯入來源無 avgDepth 但有剖面樣本時使用）
    /// 帶 totalTimeSeconds 觸發尾段補償＋除以官方時長，避免尾段低估
    /// （家族共用函式，見 DiveKit.DiveProfileSample.reconstructedAvgDepth）
    func reconstructedAvgDepth() -> Double {
        let kitSamples = profileSamples.map {
            DiveKit.DiveProfileSample(timeSeconds: $0.timeSeconds, depthMeters: $0.depthMeters, waterTemp: $0.waterTemp)
        }
        return DiveKit.DiveProfileSample.reconstructedAvgDepth(
            samples: kitSamples,
            totalTimeSeconds: Double(diveTimeSeconds)
        )
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
