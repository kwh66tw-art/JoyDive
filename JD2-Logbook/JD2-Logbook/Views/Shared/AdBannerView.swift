// AdBannerView.swift — JD2-Logbook/Views/Shared/
// Week 11 — AdMob Banner 廣告視圖
//
// 使用條件編譯：
//   - 加入 GoogleMobileAds SPM 並 import 後，顯示真實廣告
//   - 未加入 SPM 時，顯示開發用佔位符（不影響 build）
//
// MARK: - 如何啟用真實 AdMob
// 1. Xcode → File → Add Package →
//    https://github.com/googleads/swift-package-manager-google-mobile-ads
// 2. 在 Info.plist 加入 GADApplicationIdentifier（AdMob console 的 App ID）
// 3. 將下方 AdUnitID 常數換成真實 Ad Unit ID（上線前必填）
//
// Bug Fix (Audit):
//   - Coordinator 標註 @MainActor，修正 Swift 6 跨 actor 存取 UIApplication.shared 的
//     隔離邊界錯誤
//   - 棄用 isKeyWindow → 改用 UIWindowScene.keyWindow（iOS 15+ 正確 API）
//   - 補實 GADBannerViewDelegate：no-fill / 載入失敗時自動收合高度，不留空洞

import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds

// MARK: - 真實 AdMob Banner（已安裝 SDK 時啟用，iOS only）
// GoogleMobileAds SDK 僅支援 iOS/iPadOS，macOS 不支援

#if os(iOS)
struct AdBannerView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID        = adUnitID
        banner.delegate        = context.coordinator
        banner.rootViewController = context.coordinator.rootVC
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        if uiView.rootViewController == nil {
            uiView.rootViewController = context.coordinator.rootVC
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator: NSObject, BannerViewDelegate {

        var rootVC: UIViewController? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first(where: { $0.activationState == .foregroundActive })?
                .keyWindow?
                .rootViewController
        }

        func bannerView(_ bannerView: BannerView,
                        didFailToReceiveAdWithError error: Error) {
            print("[AdBanner] Failed: \(error.localizedDescription)")
            bannerView.frame.size.height = 0
            bannerView.isHidden = true
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            bannerView.isHidden = false
            bannerView.frame.size.height = AdSizeBanner.size.height
        }
    }
}

/// Standard banner 高度（AdSizeBanner = 50pt）
let adBannerHeight: CGFloat = AdSizeBanner.size.height

#endif // os(iOS)

#else

// MARK: - 開發用佔位符（未安裝 GoogleMobileAds SDK 時）

struct AdBannerView: View {
    let adUnitID: String

    var body: some View {
        // Debug 模式顯示有標記的佔位框，幫助佈局驗證；
        // Release 模式完全隱藏，不佔任何空間
        #if DEBUG
        HStack(spacing: 8) {
            Image(systemName: "rectangle.and.pencil.and.ellipsis")
                .foregroundStyle(.secondary)
            Text("Ad Banner · \(adUnitID.suffix(10))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: adBannerHeight)
        .background(Color.platformTertiaryFill)
        .overlay(
            Rectangle()
                .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
        )
        #else
        EmptyView()
        #endif
    }
}

let adBannerHeight: CGFloat = 50

#endif

// MARK: - Ad Unit ID 常數
//
// ⚠️ 上線前將下方測試 ID 替換為 AdMob console 核發的正式 Ad Unit ID

enum AdUnitID {
    /// 日誌主畫面底部 banner
    static let logbook       = "ca-app-pub-9582822701117167/7912367341"
    /// 設定頁底部 banner
    static let settings      = "ca-app-pub-9582822701117167/1893753901"
    /// Import 頁 banner
    static let importBanner  = "ca-app-pub-9582822701117167/4782955369"
    /// 地圖空狀態 inline ad
    static let mapEmptyState = "ca-app-pub-9582822701117167/3449692393"
}

// MARK: - PremiumAwareAdBanner
//
// 封裝 Premium 判斷邏輯，所有廣告版位統一使用此 wrapper。
// Premium 用戶自動隱藏廣告，非 Premium 才渲染 AdBannerView。
//
// 用法：PremiumAwareAdBanner(adUnitID: AdUnitID.importBanner)

struct PremiumAwareAdBanner: View {
    let adUnitID: String
    @State private var purchase = PurchaseManager.shared

    var body: some View {
        // macOS 無 AdMob 支援，廣告版位完全不渲染
        #if os(iOS)
        if !purchase.isPremium {
            AdBannerView(adUnitID: adUnitID)
                .frame(height: adBannerHeight)  // 固定高度，防止 BannerView 壓縮上方內容
                .accessibilityHidden(true)  // 廣告對 VoiceOver 不具意義
        }
        #endif
    }
}
