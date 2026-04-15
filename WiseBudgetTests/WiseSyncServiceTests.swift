import Testing
import Foundation
@testable import WiseBudget

struct WiseSyncServiceTests {

    // MARK: - parseFormattedAmount

    @Test func parseSimpleAmount() throws {
        let result = try #require(WiseSyncService.parseFormattedAmount("10.00 EUR"))
        #expect(result.0 == Decimal(string: "10.00"))
        #expect(result.1 == "EUR")
    }

    @Test func parseNegativeAmount() throws {
        let result = try #require(WiseSyncService.parseFormattedAmount("-25.50 GBP"))
        #expect(result.0 == Decimal(string: "-25.50"))
        #expect(result.1 == "GBP")
    }

    @Test func parseAmountWithThousandsSeparator() throws {
        let result = try #require(WiseSyncService.parseFormattedAmount("1,234.56 USD"))
        #expect(result.0 == Decimal(string: "1234.56"))
        #expect(result.1 == "USD")
    }

    @Test func parseHTMLWrappedPositiveAmount() throws {
        let result = try #require(WiseSyncService.parseFormattedAmount("<positive>+ 3,754.76 EUR</positive>"))
        #expect(result.0 == Decimal(string: "3754.76"))
        #expect(result.1 == "EUR")
    }

    @Test func parseHTMLWrappedNegativeAmount() throws {
        let result = try #require(WiseSyncService.parseFormattedAmount("<negative>- 18.55 EUR</negative>"))
        #expect(result.0 == Decimal(string: "-18.55"))
        #expect(result.1 == "EUR")
    }

    @Test func parseEmptyStringReturnsNil() {
        #expect(WiseSyncService.parseFormattedAmount("") == nil)
    }

    @Test func parseSingleWordReturnsNil() {
        #expect(WiseSyncService.parseFormattedAmount("EUR") == nil)
    }

    @Test func parseLowercaseCurrencyReturnsNil() {
        #expect(WiseSyncService.parseFormattedAmount("10.00 eur") == nil)
    }

    @Test func parseInvalidCurrencyLengthReturnsNil() {
        #expect(WiseSyncService.parseFormattedAmount("10.00 EU") == nil)
        #expect(WiseSyncService.parseFormattedAmount("10.00 EURO") == nil)
    }

    @Test func parseNonNumericAmountReturnsNil() {
        #expect(WiseSyncService.parseFormattedAmount("abc EUR") == nil)
    }

    // MARK: - categoryForActivityType

    @Test(arguments: [
        ("CARD_TRANSACTION", "Shopping"),
        ("CARD_PAYMENT", "Shopping"),
        ("DIRECT_DEBIT_TRANSACTION", "Subscription"),
        ("DIRECT_DEBIT_INSTRUCTION", "Subscription"),
        ("TRANSFER", "Other"),
        ("SEND_ORDER", "Other"),
        ("BALANCE_TRANSACTION", "Other"),
        ("CARD_CASHBACK", "Other"),
        ("FEE_REFUND", "Other"),
        ("UNKNOWN_TYPE", "Other"),
    ])
    func activityTypeMapsToCategory(activityType: String, expected: String) {
        #expect(WiseSyncService.categoryForActivityType(activityType) == expected)
    }
}
