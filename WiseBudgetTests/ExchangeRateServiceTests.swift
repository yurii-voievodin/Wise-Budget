import Testing
import Foundation
@testable import WiseBudget

@MainActor
struct ExchangeRateServiceTests {

    // MARK: - Same Currency Short-Circuit

    @Test func sameCurrencyReturnsNil() async {
        let service = ExchangeRateService()
        let result = await service.suggestedConversion(
            amount: Decimal(string: "100.00")!,
            from: "EUR",
            to: "EUR",
            on: Date.now
        )
        #expect(result == nil, "Same currency conversion should return nil")
    }
}
