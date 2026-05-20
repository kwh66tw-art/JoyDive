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

// MARK: - 真實 AdMob Banner（已安裝 SDK 時啟用）

struct AdBannerView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID        = adUnitID
        banner.delegate        = context.coordinator
        // rootViewController 設定移至 Coordinator.rootVC（lazy）
        // makeUIView 時 window 可能尚未 active，不在此處賦值，
        // 由 Coordinator.bannerViewWillPresentScreen(_:) 時已確保 window ready
        banner.rootViewController = context.coordinator.rootVC
        banner.load(GADRequest())
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        // rootVC 可能在 makeUIView 時為 nil（window 尚未 active），在 update 補賦值
        if uiView.rootViewController == nil {
            uiView.rootViewController = context.coordinator.rootVC
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: Coordinator
    //
    // @MainActor 修正：
    //   UIApplication.shared 是 MainActor 隔離屬性。
    //   未標註時 Swift 6 strict concurrency 會報 "main actor-isolated property
    //   'shared' can not be referenced from a non-isolated context" 錯誤。
    @MainActor
    final class Coordinator: NSObject, GADBannerViewDelegate {

        // MARK: rootVC
        //
        // 修正 isKeyWindow（iOS 15 廢棄）→ 改用 UIWindowScene.keyWindow
        // 同時篩選 foregroundActive scene，確保 window 已完全激活
        var rootVC: UIViewController? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first(where: { $0.activationState == .foregroundActive })?
                .keyWindow?
                .rootViewController
        }

        // MARK: GADBannerViewDelegate — no-fill / 失敗處理
        //
        // 廣告載入失敗（包含 no-fill）時，將 banner 高度收為 0，
        // 避免在 UI 中留下 50pt 的空白塊。
        func bannerView(_ bannerView: GADBannerView,
                        didFailToReceiveAdWithError error: Error) {
            print("[AdBanner] Failed: \(error.localizedDescription)")
            // 收合高度：透過 intrinsicContentSize override 並非最佳，
            // 此處用 frame 設為 0 並通知父層 SwiftUI 重新佈局
            bannerView.frame.size.height = 0
            bannerView.isHidden = true
        }

        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            // 確保廣告載入成功後高度恢復（例如從失敗狀態重試成功）
            bannerView.isHidden = false
            bannerView.frame.size.height = GADAdSizeBanner.size.height
        }
    }
}

/// Standard banner 高度（GADAdSizeBanner = 50pt）
let adBannerHeight: CGFloat = GADAdSizeBanner.size.height

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
        .background(Color(.tertiarySystemFill))
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
    /// Import 頁 banner（Google 公開測試 ID，上線前換成正式 ID）
    static let importBanner  = "ca-app-pub-3940256099942544/2934735716"
    /// 地圖空狀態 inline ad（Google 公開測試 ID，上線前換成正式 ID）
    static let mapEmptyState = "ca-app-pub-3940256099942544/2934735716"
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
        if !purchase.isPremium {
            AdBannerView(adUnitID: adUnitID)
                .accessibilityHidden(true)  // 廣告對 VoiceOver 不具意義
        }
    }
}
