// ActivityView.swift — JD2-Logbook/Views/Shared/
// Week 12 — UIActivityViewController 封裝，含 iPad Popover 防崩潰保護
//
// iPad 必要保護：
//   未設定 popoverPresentationController.sourceView 時，iOS 在 iPad 上
//   會拋出 NSException 導致 App 強制崩潰。
//   此處使用 iOS 15+ keyWindow API（與 Week 11 AdBannerView 修正方式一致）。
//
// 使用方式：
//   .sheet(item: $exportItem) { item in
//       ActivityView(url: item.url)
//   }

import SwiftUI
import UIKit

struct ActivityView: UIViewControllerRepresentable {

    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        // ── iPad Popover 防崩潰保護 ──────────────────────────
        // iPad 呈現 UIActivityViewController 必須提供 popover 錨點，
        // 否則 iOS 拋出 NSException（App 閃退，App Store 審核必被拒）。
        // 使用 iOS 15+ 的 foregroundActive + keyWindow，
        // 與 Week 11 對 isKeyWindow 廢棄 API 的修正方式一致。
        if let popover = controller.popoverPresentationController {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }

            if let rootVC = scene?.keyWindow?.rootViewController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(
                    x: rootVC.view.bounds.midX,
                    y: rootVC.view.bounds.midY,
                    width:  0,
                    height: 0
                )
                // 螢幕正中央彈出，不顯示方向箭頭
                popover.permittedArrowDirections = []
            }
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController,
                                context: Context) {
        // 無需更新：UIActivityViewController 為一次性呈現
    }
}
