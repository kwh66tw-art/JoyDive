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

    public var weightSymbol: String {
        switch self {
        case .metric:   return "kg"
        case .imperial: return "lbs"
        }
    }

    public var pressureSymbol: String {
        switch self {
        case .metric:   return "bar"
        case .imperial: return "psi"
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

    /// 配重換算（輸入永遠是公斤，換算成此單位系統對應的顯示值）
    public func convertWeight(kgValue: Double) -> Double {
        switch self {
        case .metric:   return kgValue
        case .imperial: return kgValue * 2.20462
        }
    }

    /// 氣瓶壓力換算（輸入永遠是 bar，換算成此單位系統對應的顯示值）
    public func convertPressure(barValue: Double) -> Double {
        switch self {
        case .metric:   return barValue
        case .imperial: return barValue * 14.5038
        }
    }

    /// 深度顯示字串（含單位符號），例如 "41.0 m" / "134.5 ft"
    /// - Parameter locale: 小數點與千分位要用哪個語系的寫法。
    ///   🔴 **`String(format:)` 不帶 `locale:` ＝ 一律用 "." 當小數點**（非在地化），
    ///   在法／德／西等逗號語系會顯示成 "12.5 m" 而非 "12,5 m"。
    ///   預設 `.current` 跟系統語言走；**App 內語言切換器**的選擇不在系統語言裡，
    ///   所以呼叫端若拿得到 `languageManager.locale` 就該傳進來（多數 View 都拿得到）。
    public func formatDepth(_ metersValue: Double, decimals: Int = 1,
                            locale: Locale = .current) -> String {
        String(format: "%.\(decimals)f %@", locale: locale,
               convertDepth(metersValue: metersValue), depthSymbol)
    }

    /// 減壓 ceiling 專用的保守進位顯示（R-022 Bug 1）。
    ///
    /// Ceiling 是潛水員「必須停留在此深度（或更深）直到清除」的下限深度，安全的
    /// 顯示方向是**絕不比真實值淺**。一般 `formatDepth(decimals: 0)` 用 `%.0f`
    /// 四捨五入，約有一半機率把 ceiling 無條件捨去到較淺的整數（例如真實 5.4m
    /// 顯示成 5m），潛水員若照著顯示值上升，會提前離開真正需要的停留深度——
    /// 這是安全問題，不是單純的美觀問題。
    ///
    /// 換算順序：先用 `convertDepth` 轉成顯示單位（公尺或英尺），**再**對顯示值
    /// 無條件進位（`.rounded(.up)`），而不是對公尺值進位後才換算——避免公制轉
    /// 英制時，換算誤差又把進位後的值拉回顯示單位的下一個整數以下。
    public func formatDepthConservative(_ metersValue: Double,
                                        locale: Locale = .current) -> String {
        let displayValue = convertDepth(metersValue: metersValue).rounded(.up)
        return String(format: "%.0f %@", locale: locale, displayValue, depthSymbol)
    }

    /// 溫度顯示字串（含單位符號），例如 "27°C" / "81°F"
    public func formatTemperature(_ celsiusValue: Double,
                                  locale: Locale = .current) -> String {
        String(format: "%.0f%@", locale: locale,
               convertTemperature(celsiusValue: celsiusValue), temperatureSymbol)
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

    /// 使用者在目前單位系統下輸入的配重值，反推回公斤（供寫入 DiveLog 儲存欄位）
    public func kgValue(fromDisplay displayValue: Double) -> Double {
        switch self {
        case .metric:   return displayValue
        case .imperial: return displayValue / 2.20462
        }
    }

    /// 使用者在目前單位系統下輸入的氣瓶壓力值，反推回 bar（供寫入 DiveLog 儲存欄位）
    public func barValue(fromDisplay displayValue: Double) -> Double {
        switch self {
        case .metric:   return displayValue
        case .imperial: return displayValue / 14.5038
        }
    }
}
