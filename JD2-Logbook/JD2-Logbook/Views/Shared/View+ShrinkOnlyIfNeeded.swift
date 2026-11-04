// View+ShrinkOnlyIfNeeded.swift — JD2-Logbook/Views/Shared/
// v1.4 C：`.minimumScaleFactor` 改成「先試原字級、放不下才縮」。

import SwiftUI

extension View {
    /// 先用原字級排一次（不縮）；水平放不下才換成可縮到 `minimumScale` 的版本。
    ///
    /// 直接掛 `.minimumScaleFactor` 時，Xcode 27 建置的版本在放得下的情況下也會縮小
    /// （同一份程式碼 Xcode 26 建置的 v1.2 正常；2026-10-05 模擬器 A/B 實驗，見
    /// `DiveAnalysisView.calloutCell`）——本專案決定用 `ViewThatFits` 繞開，不依賴該行為。
    /// 呼叫端自行先設 `.lineLimit(1)`。
    func shrinkOnlyIfNeeded(minimumScale: CGFloat) -> some View {
        ViewThatFits(in: .horizontal) {
            self.fixedSize(horizontal: true, vertical: false)
            self.minimumScaleFactor(minimumScale)
        }
    }
}
