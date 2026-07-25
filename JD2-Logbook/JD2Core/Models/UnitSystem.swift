// UnitSystem.swift — JD2Core/Models/
// v1.2 #4 — 公制／英制單位系統
//
// 資料模型（DiveLog／DiveProfileSample 等）內部儲存永遠是公制（公尺／攝氏），
// 不因使用者切換單位而改變，避免資料遷移與匯入/匯出格式複雜化。UnitSystem
// 只負責「顯示層」與「輸入層」的雙向換算，各畫面用 `@AppStorage(UnitSystem.storageKey)`
// 讀取目前選擇，呼叫 formatDepth/formatTemperature 顯示、metersValue/celsiusValue
// 反向換算使用者輸入。

import Foundation

public enum UnitSystem: String, CaseIterable, Codable, Sendable {
    case metric
    case imperial

    /// Settings 頁與各畫面共用同一個 UserDefaults key 才能同步生效。
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

    // MARK: - 顯示層換算（儲存值 → 顯示值）

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

    /// 深度顯示字串（含單位符號），例如 "41.0 m" / "134.5 ft"
    public func formatDepth(_ metersValue: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f %@", convertDepth(metersValue: metersValue), depthSymbol)
    }

    /// 溫度顯示字串（含單位符號），例如 "27°C" / "81°F"
    public func formatTemperature(_ celsiusValue: Double) -> String {
        String(format: "%.0f%@", convertTemperature(celsiusValue: celsiusValue), temperatureSymbol)
    }

    // MARK: - 輸入層反向換算（使用者輸入的顯示值 → 儲存用公制值）

    /// 使用者在目前單位系統下輸入的深度值，反推回公尺（供寫入 DiveLog 儲存欄位）
    public func metersValue(fromDisplay displayValue: Double) -> Double {
        switch self {
        case .metric:   return displayValue
        case .imperial: return displayValue / 3.28084
        }
    }

    /// 使用者在目前單位系統下輸入的溫度值，反推回攝氏（供寫入 DiveLog 儲存欄位）
    public func celsiusValue(fromDisplay displayValue: Double) -> Double {
        switch self {
        case .metric:   return displayValue
        case .imperial: return (displayValue - 32.0) * 5.0 / 9.0
        }
    }
}
