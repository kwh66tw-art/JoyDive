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
}
