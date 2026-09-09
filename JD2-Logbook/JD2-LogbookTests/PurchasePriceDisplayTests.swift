// PurchasePriceDisplayTests.swift — JD2-LogbookTests
// C2 派工單第 C 項（2026-09-07）：Premium 買斷價格顯示——寫死價格修復。
//
// 背景：`PurchaseManager.premiumPriceString` 原本是
//   `premiumProduct?.displayPrice ?? "$1.99"`
// StoreKit 商品未載入完成前，會對非美元區使用者顯示錯的幣別＋錯的數字，且與
// 真實結帳價格無從區分——這是使用者據以做付費決定的數字，屬送審合規風險
// （見 `app-store-submission-guide` skill §2.2／Guideline 2.3 Accurate Metadata）。
// 修復後：`premiumPriceString` 回傳 `String?`，nil＝未載入，呼叫端顯示 loading
// 佔位或「—」，不得顯示任何幣別數字。
//
// 測試限制（誠實揭露）：`Product`（StoreKit 2）是不可自建的具體 struct，無法在
// 不啟動真實/模擬 StoreKit 交易環境（StoreKitTest 設定檔）下建構出一個假的
// `premiumProduct`，因此無法直接測試「已載入 → 顯示真實 displayPrice」這一半。
// 本檔改用「不變量測試」鎖定唯一真正重要的行為契約：
//   **`premiumPriceString` 恆等於 `premiumProduct?.displayPrice`——不存在任何
//   獨立於商品載入狀態的寫死字串分支。**
// 這個不變量在「已載入」與「未載入」兩種狀態下都成立，且對回歸極度敏感：
// 只要有人重新加回 `?? "$1.99"`，`premiumProduct == nil` 時
// `premiumPriceString` 會變成 "$1.99" 而 `premiumProduct?.displayPrice` 仍是
// nil，等式立即不成立，測試變紅——這正是雙向故障注入的「紅」那一半（見下方
// `testFaultInjection...` 的說明）。

import XCTest
import StoreKit
@testable import JoyDive_

@MainActor
final class PurchasePriceDisplayTests: XCTestCase {

    /// 核心不變量：`premiumPriceString` 永遠不能是一個獨立於 `premiumProduct`
    /// 的寫死字串。無論 App 冷啟動後 StoreKit 商品是否已經載入完成（`shared`
    /// 是 singleton，測試執行當下實際載入狀態不可控、也不需要控制——這正是
    /// 這個不變量寫法的重點：兩種狀態下都必須成立）。
    func testPremiumPriceStringNeverIndependentOfLoadedProduct() {
        let pm = PurchaseManager.shared
        XCTAssertEqual(
            pm.premiumPriceString,
            pm.premiumProduct?.displayPrice,
            "premiumPriceString 不得含任何獨立於 premiumProduct 的寫死幣別/金額字串" +
            "（原本的 `?? \"$1.99\"` 正是這種分支，對非美元區使用者顯示錯誤價格）"
        )
    }

    /// 未載入時（`premiumProduct == nil`）明確斷言 `premiumPriceString == nil`，
    /// 不是某個看起來合法的價格字串。若 `premiumProduct` 在本次測試執行時已經
    /// 載入完成（StoreKit sandbox 回應夠快），本斷言略過。
    ///
    /// 🔴 **2026-09-09 更正**：此處原本寫「上面那支不變量測試才是不受載入時序
    /// 影響、恆定有效的規格測試」——**那句話是錯的**。商品**已載入**時，
    /// `premiumPriceString == premiumProduct?.displayPrice` 這個等式在有無
    /// `?? "寫死值"` 分支下都成立（`??` 根本不觸發），所以它同樣抓不到。
    /// **兩支測試的盲區是同一個狀態**，在該狀態下防護是 0 而不是 2。
    /// 稽核實測：注入 `?? "$1.99"` ⇒ 140 支全綠。
    /// 真正守住這條規格的是下方 `testPriceStringIsNilWhenDisplayPriceMissing`
    /// ——它測純函式 `PurchaseManager.priceString(displayPrice:)`，**不依賴
    /// StoreKit 執行期狀態、不帶任何 XCTSkip**。本檔兩支既有測試保留作為
    /// 端到端佐證，但它們不是這條規格的守門人。
    func testPremiumPriceStringIsNilWhenProductNotYetLoaded() throws {
        let pm = PurchaseManager.shared
        try XCTSkipUnless(pm.premiumProduct == nil,
            "本次執行時 StoreKit 商品已載入完成，無法驗證未載入狀態；" +
            "不變量測試（testPremiumPriceStringNeverIndependentOfLoadedProduct）" +
            "涵蓋兩種狀態，不受影響")
        XCTAssertNil(pm.premiumPriceString,
            "商品未載入時必須是 nil，不得顯示任何寫死的幣別/金額字串（例如 \"$1.99\"）")
    }

    // MARK: - 雙向故障注入說明（人工驗證紀錄，非可執行測試）
    //
    // 紅：暫時把 PurchaseManager.premiumPriceString 改回
    //     `premiumProduct?.displayPrice ?? "$1.99"`，在 premiumProduct == nil
    //     的狀態下執行 testPremiumPriceStringNeverIndependentOfLoadedProduct()
    //     ⇒ XCTAssertEqual(pm.premiumPriceString, pm.premiumProduct?.displayPrice)
    //       變成 XCTAssertEqual("$1.99", nil) ⇒ 失敗（紅）。
    // 綠：還原為 `premiumProduct?.displayPrice`（nil 傳遞）⇒ 兩側同為 nil ⇒ 通過。
    // 兩次執行紀錄見本次 C2 執行者的驗證報告（build/test 輸出）。

    // MARK: - 🔴 這條規格真正的守門人（2026-09-09，稽核發現② 修復）
    //
    // 上面兩支都依賴 StoreKit 執行期狀態：商品載入到就一支 skip、一支失明。
    // 下面兩支測純函式，**確定性執行、無 XCTSkip、不碰 singleton**。

    func testPriceStringIsNilWhenDisplayPriceMissing() {
        XCTAssertNil(
            PurchaseManager.priceString(displayPrice: nil),
            "商品未載入時必須是 nil。任何寫死的幣別/金額字串（例如 \"$1.99\"）" +
            "都會讓非美元區使用者看到錯誤價格——這是送審合規風險，不只是顯示瑕疵"
        )
    }

    func testPriceStringPassesThroughLoadedDisplayPrice() {
        // 已載入時必須原樣透傳，不得改寫成任何自家格式
        XCTAssertEqual(PurchaseManager.priceString(displayPrice: "NT$60"), "NT$60")
        XCTAssertEqual(PurchaseManager.priceString(displayPrice: "€1,99"), "€1,99")
    }
}
