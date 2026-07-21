// UnitSystem.swift — JD2Core/Models/
// v1.2 #4 — 公制／英制單位系統
//
// ⚠️ 目前範圍：Settings 頁的切換選項＋共用轉換工具函式。
//    尚未展開到全 App 各處顯示/輸入欄位（那是後續一項一項處理的較大範圍工作，
//    見 V1_2_BACKLOG.md #4）；本檔案先把基礎打好，供之後各畫面逐步採用。

import Foundation

public enum UnitSystem: String, CaseIterable, Codable, Sendable {
    case metric
    case imperial

    /// Settings 頁與未來各畫面共用同一個 UserDefaults key 才能同步生效。
    public static let storageKey = "unitSystem"

    public var depthSymbol: String {
        switch self {
        case .metric:   return "m"
        case .imperial: return "ft"
        }
    }

    public var temperatureSymbol: String {
        switch self {
        case .metric:   return "°C"
        case .imperial: return "°F"
        }
    }

    /// 深度換算（輸入永遠是公尺，換算成此單位系統對應的顯示值）
    public func convertDepth(metersValue: Double) -> Double {
        switch self {
        case .metric:   return metersValue
        case .imperial: return metersValue * 3.28084
        }
    }

    /// 溫度換算（輸入永遠是攝氏，換算成此單位系統對應的顯示值）
    public func convertTemperature(celsiusValue: Double) -> Double {
        switch self {
        case .metric:   return celsiusValue
        case .imperial: return celsiusValue * 9.0 / 5.0 + 32.0
        }
    }
}
