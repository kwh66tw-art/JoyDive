// ActivityView.swift — JD2-Logbook/Views/Shared/
// Week 12 — Cross-platform Share Sheet
//
// iOS:   UIActivityViewController（已含 iPad popover 防崩潰保護）
// macOS: SwiftUI Sheet + ShareLink（原生 macOS 分享選單）
//
// 使用方式（兩平台相同）：
//   .sheet(item: $exportItem) { item in
//       ActivityView(url: item.url)
//   }

import SwiftUI

#if os(iOS)
import UIKit

struct ActivityView: UIViewControllerRepresentable {

    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        // ── iPad Popover 防崩潰保護 ──────────────────────────
        // 未設定錨點時 iOS 在 iPad 上拋出 NSException 強制崩潰。
        // 使用 iOS 15+ foregroundActive + keyWindow（Week 11 同款修法）。
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
                popover.permittedArrowDirections = []
            }
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController,
                                context: Context) {}
}

#else

// ── macOS ────────────────────────────────────────────────
// UIKit 不可用。呈現一個小 Sheet 內含 ShareLink，
// 使用者點擊後觸發原生 macOS 分享選單（NSSharingServicePicker）。

struct ActivityView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.and.arrow.up.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text(url.lastPathComponent)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 280)

            ShareLink(
                item: url,
                preview: SharePreview(url.lastPathComponent)
            ) {
                Label("Share File", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)

            Button("Cancel") { dismiss() }
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(minWidth: 320)
    }
}

#endif
