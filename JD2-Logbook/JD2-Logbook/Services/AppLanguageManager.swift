// AppLanguageManager.swift — JD2-Logbook/Services/
// v1.1 — App 內語系切換（獨立於系統設定）
//
// 作法比照 JD2-ultra 的「四段式解法」（0.2.9 / LESSONS_LEARNED §C7）：
// 單靠 `.environment(\.locale, ...)` 蓋不到 navigationTitle、tabItem 等系統層文字
// （UINavigationBar / UITabBar chrome，不是純 SwiftUI 內容，不吃 \.locale）。
// 完整需要四件事同時成立，語言切換才會「即時生效、不必重開 App」：
//   ① 行程級 `AppleLanguages` UserDefaults override —— 涵蓋系統面板等殘餘
//      （分享面板、系統警示等我們管不到的地方），下次啟動 100% 生效。
//   ② root 掛 `.environment(\.locale, ...)` —— 一般 Text/Label 用 LocalizedStringKey
//      的地方，本次執行立即切換。
//   ③ `localized(_:)` 手動查表 —— navigationTitle / tabItem 這類 \.locale 蓋不到的
//      地方，個別呼叫這個方法即時查對應 .lproj，取代 Text("key") 寫法。
//   ④ UserDefaults 持久化 —— 下次啟動記住使用者選擇。
//
// ⚠️ 用 localized() 查到的 key 不會有 Text("key") 引用，清殭屍 key 前
//    要先 grep `localized(` 確認沒有遺漏（JD2-ultra LESSONS_LEARNED §C7 教訓）。

import Foundation
import Observation

@MainActor
@Observable
final class AppLanguageManager {

    /// SettingsView Picker 顯示用：語言名以「該語言自己的文字」顯示，不翻譯（業界慣例）。
    /// 繁體中文排最前，對齊本專案主要目標語言（V1_RELEASE_CHECKLIST）。
    static let supportedLanguages: [(code: String, nativeName: String)] = [
        ("zh-Hant", "繁體中文"),
        ("zh-Hans", "简体中文"),
        ("en", "English"),
        ("en-GB", "English (UK)"),
        ("ja", "日本語"),
        ("ko", "한국어"),
        ("fr", "Français"),
        ("de", "Deutsch"),
        ("es", "Español"),
        ("it", "Italiano"),
        ("nl", "Nederlands"),
        ("pt-PT", "Português"),
        ("id", "Bahasa Indonesia"),
        ("ms", "Bahasa Melayu"),
        ("vi", "Tiếng Việt"),
        ("th", "ภาษาไทย"),
        ("el", "Ελληνικά"),
        ("hr", "Hrvatski"),
    ]

    private static let languageKey = "jd2logbook.appLanguage"

    private let defaults: UserDefaults

    /// nil = 跟隨系統；否則為 xcstrings 語言代碼（如 "zh-Hant"）。
    var appLanguage: String? {
        didSet {
            defaults.set(appLanguage, forKey: Self.languageKey)
            // ① 行程級 override：涵蓋系統層殘餘（分享面板等），下次啟動全面生效。
            if let lang = appLanguage {
                UserDefaults.standard.set([lang], forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            }
        }
    }

    /// ② 掛在 root `.environment(\.locale)`，一般 Text/Label 即時跟隨。
    var locale: Locale {
        appLanguage.map { Locale(identifier: $0) } ?? .autoupdatingCurrent
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appLanguage = defaults.string(forKey: Self.languageKey)
    }

    /// ③ navigationTitle / tabItem 等 \.locale 蓋不到之處用此手動查表。
    /// 用法：`.navigationTitle(Text(verbatim: languageManager.localized("Settings")))`
    func localized(_ key: String) -> String {
        if let lang = appLanguage,
           let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return NSLocalizedString(key, comment: "")
    }

    /// ⑤ `DateFormatter()`／`Calendar.current` 都不吃 `\.locale`（Foundation 型別，
    /// 不是 SwiftUI environment-aware），各處各自手動 `DateFormatter()` 很容易忘記
    /// 設 locale，症狀跟①②③一樣：語言切換後不生效，只是這次咬的是日期而不是字串
    /// （2026-07-26 一次抓到 7 處）。日期／月曆一律經這裡拿，不要再手動生。
    ///
    /// ⚠️ 強制 `.calendar = Calendar(identifier: .gregorian)`：泰文 `Locale(identifier: "th")`
    /// 預設曆法是佛曆（`identifier: buddhist`），不設會顯示「2569」而非「2026」——
    /// 潛水日誌一律要西元年，跟其他 17 語言一致，不能因為語言不同就換算年份
    /// （2026-07-26 真機截圖抓到，逐一測過全部 18 語言確認只有泰文受影響）。
    func dateFormatter(dateStyle: DateFormatter.Style = .none, timeStyle: DateFormatter.Style = .none) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter
    }

    /// 潛水記錄的日期時間顯示（Entry/Exit Time 等）：純數字日期，不夾雜語意月份字詞
    /// （越南文「ngày 4 thg 6, 2026」量測到全語系最長 24 字元，UI 卡片寬度會裁切/換行；
    /// 改用數字後跟其他語言一致，也更短）。12/24 小時制仍尊重各語系自然慣例
    /// （英文 AM/PM、韓文 오전/오후 等不受影響，那是時制慣例不是月份字詞問題）。
    /// 一樣強制 Gregorian 曆法，理由同 `dateFormatter(dateStyle:timeStyle:)`。
    func numericDateTimeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.setLocalizedDateFormatFromTemplate("yMdjm")
        return formatter
    }

    var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        return cal
    }
}
