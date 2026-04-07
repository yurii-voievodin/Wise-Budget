import Testing
import Foundation
@testable import WiseBudget

struct MonobankSyncServiceTests {

    /// Helper to create a MonobankStatement with sensible defaults.
    private func makeStatement(
        id: String = "testId",
        time: Int = 1_712_000_000,
        description: String = "Test merchant",
        mcc: Int = 5411,
        amount: Int = -10000,         // card amount in minor units (kopecks)
        operationAmount: Int = -10000, // merchant amount in minor units
        currencyCode: Int = 980,       // 980 = UAH
        comment: String? = nil,
        counterIban: String? = nil
    ) -> MonobankStatement {
        MonobankStatement(
            id: id,
            time: time,
            description: description,
            mcc: mcc,
            originalMcc: nil,
            amount: amount,
            operationAmount: operationAmount,
            currencyCode: currencyCode,
            balance: 0,
            hold: false,
            cashbackAmount: nil,
            comment: comment,
            counterIban: counterIban
        )
    }

    // MARK: - Foreign currency, defaultCurrency != accountCurrency

    @Test func foreignCurrencySkipsBaseCurrencyWhenDefaultDiffers() {
        // USD purchase (840) on a UAH account, but user's default currency is USD.
        // The bank's UAH amount is not useful — should be nil.
        let statement = makeStatement(
            amount: -21931,          // 219.31 UAH charged to card
            operationAmount: -499,   // 4.99 USD merchant amount
            currencyCode: 840        // 840 = USD
        )

        let result = MonobankSyncService.convertStatement(
            statement,
            accountCurrency: "UAH",
            ownIbans: [],
            defaultCurrency: "USD"
        )

        #expect(result != nil)
        #expect(result?.amount == Decimal(string: "4.99"))
        #expect(result?.currency == "USD")
        #expect(result?.baseCurrencyAmount == nil)
        #expect(result?.baseCurrency == nil)
    }

    @Test func foreignCurrencyEURSkipsBaseCurrencyWhenDefaultIsEUR() {
        // EUR purchase (978) on a UAH account, user's default currency is EUR.
        // accountCurrency (UAH) != defaultCurrency (EUR) → skip base amount.
        let statement = makeStatement(
            amount: -67658,          // 676.58 UAH charged to card
            operationAmount: -1315,  // 13.15 EUR merchant amount
            currencyCode: 978        // 978 = EUR
        )

        let result = MonobankSyncService.convertStatement(
            statement,
            accountCurrency: "UAH",
            ownIbans: [],
            defaultCurrency: "EUR"
        )

        #expect(result != nil)
        #expect(result?.amount == Decimal(string: "13.15"))
        #expect(result?.currency == "EUR")
        #expect(result?.baseCurrencyAmount == nil)
        #expect(result?.baseCurrency == nil)
    }

    // MARK: - Foreign currency, defaultCurrency == accountCurrency (UAH)

    @Test func foreignCurrencyStoresBaseCurrencyWhenDefaultMatchesAccount() {
        // USD purchase (840) on a UAH account, user's default currency is UAH.
        // The bank's UAH amount IS useful — should be stored.
        let statement = makeStatement(
            amount: -21931,          // 219.31 UAH charged to card
            operationAmount: -499,   // 4.99 USD merchant amount
            currencyCode: 840        // 840 = USD
        )

        let result = MonobankSyncService.convertStatement(
            statement,
            accountCurrency: "UAH",
            ownIbans: [],
            defaultCurrency: "UAH"
        )

        #expect(result != nil)
        #expect(result?.amount == Decimal(string: "4.99"))
        #expect(result?.currency == "USD")
        #expect(result?.baseCurrencyAmount == Decimal(string: "219.31"))
        #expect(result?.baseCurrency == "UAH")
    }

    @Test func foreignCurrencyEURStoresBaseCurrencyWhenDefaultIsUAH() {
        // EUR purchase (978) on a UAH account, user's default currency is UAH.
        let statement = makeStatement(
            amount: -67658,          // 676.58 UAH
            operationAmount: -1315,  // 13.15 EUR
            currencyCode: 978        // 978 = EUR
        )

        let result = MonobankSyncService.convertStatement(
            statement,
            accountCurrency: "UAH",
            ownIbans: [],
            defaultCurrency: "UAH"
        )

        #expect(result != nil)
        #expect(result?.amount == Decimal(string: "13.15"))
        #expect(result?.currency == "EUR")
        #expect(result?.baseCurrencyAmount == Decimal(string: "676.58"))
        #expect(result?.baseCurrency == "UAH")
    }

    // MARK: - Same currency (no conversion needed)

    @Test func sameCurrencyTransactionHasNoBaseCurrency() {
        // UAH purchase on a UAH account — no conversion at all.
        let statement = makeStatement(
            amount: -434000,
            operationAmount: -434000,
            currencyCode: 980  // 980 = UAH
        )

        let result = MonobankSyncService.convertStatement(
            statement,
            accountCurrency: "UAH",
            ownIbans: [],
            defaultCurrency: "UAH"
        )

        #expect(result != nil)
        #expect(result?.amount == Decimal(string: "4340"))
        #expect(result?.currency == "UAH")
        #expect(result?.baseCurrencyAmount == nil)
        #expect(result?.baseCurrency == nil)
    }
}
