// PurchaseManager.swift — JD2-Logbook/Services/
// Week 11 — StoreKit 2 IAP：$1.99 買斷，移除廣告
//
// Product ID:  com.jd2logbook.premium
// 類型:        Non-Consumable（買斷）
// 功能解鎖:    isPremium == true → 隱藏廣告
//
// 架構說明：
//   - 使用 Swift 5.9 @Observable（iOS 17+）取代 ObservableObject + @Published
//   - View 側改用 @State var purchase = PurchaseManager.shared 觀察
//   - 修正：listenForTransactions() 對所有交易呼叫 finish()，防止 StoreKit 重複投遞
//   - 修正：isPremium 使用 UserDefaults 快取初始值，避免冷啟動閃爍

import Foundation
import StoreKit

// MARK: - UserDefaults Cache Key

private extension UserDefaults {
    static let premiumCacheKey = "com.jd2logbook.isPremiumCached"

    var cachedIsPremium: Bool {
        get { bool(forKey: Self.premiumCacheKey) }
        set { set(newValue, forKey: Self.premiumCacheKey) }
    }
}

// MARK: - PurchaseManager

@MainActor
@Observable
final class PurchaseManager {

    // MARK: Singleton
    static let shared = PurchaseManager()

    // MARK: Observable State
    //
    // @Observable 會自動追蹤所有 stored properties 的變化，
    // View 側使用 @State var pm = PurchaseManager.shared 即可訂閱更新。
    //
    // isPremium 初始值從 UserDefaults 讀取快取，冷啟動時付費用戶不會看到廣告閃爍。
    private(set) var isPremium: Bool = UserDefaults.standard.cachedIsPremium
    private(set) var isLoading     = false
    private(set) var premiumProduct: Product?

    /// 顯示用價格字串（含幣別符號）；商品未載入前顯示預設值
    var premiumPriceString: String {
        premiumProduct?.displayPrice ?? "$1.99"
    }

    // MARK: Constants
    static let premiumProductID = "com.jd2logbook.premium"

    // MARK: Transaction Listener
    private var transactionListenerTask: Task<Void, Never>?

    // MARK: - Init

    private init() {
        // 必須在 app 啟動時立即建立監聽，確保不遺漏任何交易
        transactionListenerTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
        Task {
            await loadProducts()
            await refreshPurchaseStatus()
        }
    }

    // deinit 已移除：
    //   PurchaseManager 是 singleton（static let shared），App 生命週期內永遠不會 deinit。
    //   Swift 6 中 deinit 強制 nonisolated，無法存取 @MainActor 屬性，
    //   且對 singleton 加 deinit 毫無意義。

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let products = try await Product.products(for: [Self.premiumProductID])
            premiumProduct = products.first(where: { $0.id == Self.premiumProductID })
        } catch {
            print("[PurchaseManager] loadProducts failed: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase() async {
        if premiumProduct == nil { await loadProducts() }
        guard let product = premiumProduct else { return }
        await performPurchase(product)
    }

    private func performPurchase(_ product: Product) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return }
                await transaction.finish()
                setIsPremium(true)

            case .userCancelled:
                break

            case .pending:
                // Ask to Buy：父母核准後由 Transaction Listener 處理
                break

            @unknown default:
                break
            }
        } catch {
            print("[PurchaseManager] purchase failed: \(error)")
        }
    }

    // MARK: - Refresh Purchase Status

    func refreshPurchaseStatus() async {
        var foundPremium = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.premiumProductID
               && transaction.revocationDate == nil {
                foundPremium = true
                break
            }
        }
        setIsPremium(foundPremium)
    }

    // MARK: - Transaction Listener
    //
    // ✅ Bug Fix：無論 productID 是否符合，都必須呼叫 finish()。
    //    若只在 premiumProductID 時 finish，其他未完成交易會讓 StoreKit
    //    在每次啟動或網路重連時反覆重送，造成背景阻塞與 App Store 審核被拒。

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            let transaction: Transaction
            switch result {
            case .verified(let t):
                transaction = t
            case .unverified(let t, let error):
                print("[PurchaseManager] Unverified transaction \(t.productID): \(error)")
                transaction = t
            }

            // 先處理業務邏輯，再 finish（不可反轉順序）
            if transaction.productID == Self.premiumProductID {
                setIsPremium(transaction.revocationDate == nil)
            }

            // ✅ 對所有交易呼叫 finish，不論 productID
            await transaction.finish()
        }
    }

    // MARK: - Helpers

    private func setIsPremium(_ value: Bool) {
        isPremium = value
        UserDefaults.standard.cachedIsPremium = value
    }
}
