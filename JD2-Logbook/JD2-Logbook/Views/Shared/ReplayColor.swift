// ReplayColor.swift — JD2-Logbook/Views/Shared/
// 重放分析畫面（組織負荷、Ceiling、No Deco）的語意色
//
// v1.3（PM 2026-10-05）：與家族同一套語意——同一個顏色在三個 App 是同一個意思。
// 色值出處：`_App管理/COLOR_SYSTEM.md` §4（＝`_JD2-family/F-25-DESIGN_LANGUAGE.md` §4.1 token）。
// 先前散用系統 `.green／.orange／.red`：橘色不在家族色盤，且 Ceiling 用紅色＝家族的「危險」，
// 家族中減壓停留是藍色（`deco`）。對照 App-u iPhone 端 `SafetyColor` 的同名用法。
// 只用於重放分析；一般 UI 的狀態色不在此列。

import SwiftUI

enum ReplayColor {
    /// #00C853：正常（組織負荷 ≤ 80%）
    static let safe = Color(red: 0x00 / 255, green: 0xC8 / 255, blue: 0x53 / 255)
    /// #FFD600：接近上限（組織負荷 80–100%、No Deco ≤ 5 min）
    static let warning = Color(red: 0xFF / 255, green: 0xD6 / 255, blue: 0x00 / 255)
    /// #FF1744：超過上限（組織負荷 > 100%）
    static let danger = Color(red: 0xFF / 255, green: 0x17 / 255, blue: 0x44 / 255)
    /// #1F66E0：有減壓義務（Ceiling > 0）
    // PM 2026-10-07（選 A）：原 #2979FF 配黑字仍不易辨識 ⇒ 加深為 #1F66E0 配白字（WCAG 對比 5.2:1，≥ AA 4.5:1；本專案決定的色值）。
    static let deco = Color(red: 0x1F / 255, green: 0x66 / 255, blue: 0xE0 / 255)
}
