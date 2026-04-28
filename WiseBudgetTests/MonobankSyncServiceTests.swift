import Testing
import Foundation
import SwiftData
@testable import WiseBudget

struct MonobankSyncServiceTests {
    actor RetryProbe {
        private var attempts = 0
        private var sleeps: [TimeInterval] = []

        func nextAttempt() -> Int {
            attempts += 1
            return attempts
        }

        func recordSleep(_ duration: TimeInterval) {
            sleeps.append(duration)
        }

        func snapshot() -> (attempts: Int, sleeps: [TimeInterval]) {
            (attempts, sleeps)
        }
    }

    actor WindowProbe {
        private var requestedWindows: [(Date, Date)] = []
        private var sleeps: [TimeInterval] = []

        func recordWindow(from: Date, to: Date) -> Int {
            requestedWindows.append((from, to))
            return requestedWindows.count
        }

        func recordSleep(_ duration: TimeInterval) {
            sleeps.append(duration)
        }

        func snapshot() -> (windows: [(Date, Date)], sleeps: [TimeInterval]) {
            (requestedWindows, sleeps)
        }
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Expense.self, Income.self, ExpenseCategory.self, IncomeCategory.self])
        let config = ModelConfiguration(
            UUID().uuidString,
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Helper to create a MonobankStatement with sensible defaults.
    private static func makeStatement(
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
        let statement = Self.makeStatement(
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
        let statement = Self.makeStatement(
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
        let statement = Self.makeStatement(
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
        let statement = Self.makeStatement(
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

    // MARK: - Edge cases

    @Test func zeroAmountTransactionReturnsNil() {
        let statement = Self.makeStatement(amount: 0, operationAmount: 0)
        let result = MonobankSyncService.convertStatement(
            statement,
            accountCurrency: "UAH",
            ownIbans: [],
            defaultCurrency: "UAH"
        )
        #expect(result == nil, "Zero-amount transactions should be skipped")
    }

    @Test func ownAccountTransferReturnsNil() {
        let ownIban = "UA213223130000026007233566001"
        let statement = Self.makeStatement(counterIban: ownIban)
        let result = MonobankSyncService.convertStatement(
            statement,
            accountCurrency: "UAH",
            ownIbans: [ownIban],
            defaultCurrency: "UAH"
        )
        #expect(result == nil, "Own-account transfers should be skipped")
    }

    @Test func fopTransferReturnsNil() {
        let statement = Self.makeStatement(description: "З гривневого рахунку ФОП")
        let result = MonobankSyncService.convertStatement(
            statement,
            accountCurrency: "UAH",
            ownIbans: [],
            defaultCurrency: "UAH"
        )
        #expect(result == nil, "FOP transfers should be skipped")
    }

    @Test func fopTransferCaseInsensitive() {
        let statement = Self.makeStatement(description: "на рахунок фоп")
        let result = MonobankSyncService.convertStatement(
            statement,
            accountCurrency: "UAH",
            ownIbans: [],
            defaultCurrency: "UAH"
        )
        #expect(result == nil, "FOP matching should be case-insensitive")
    }

    @Test func commentOverridesDescription() throws {
        let statement = Self.makeStatement(
            description: "Original merchant",
            comment: "My custom note"
        )
        let result = try #require(MonobankSyncService.convertStatement(
            statement,
            accountCurrency: "UAH",
            ownIbans: [],
            defaultCurrency: "UAH"
        ))
        #expect(result.targetName == "My custom note")
    }

    @Test func positiveAmountIsIncome() throws {
        let statement = Self.makeStatement(amount: 100000, operationAmount: 100000)
        let result = try #require(MonobankSyncService.convertStatement(
            statement,
            accountCurrency: "UAH",
            ownIbans: [],
            defaultCurrency: "UAH"
        ))
        #expect(result.direction == "IN")
        #expect(result.amount == Decimal(string: "1000"))
    }

    @Test func externalIdFormat() throws {
        let statement = Self.makeStatement(id: "abc123")
        let result = try #require(MonobankSyncService.convertStatement(
            statement,
            accountCurrency: "UAH",
            ownIbans: [],
            defaultCurrency: "UAH"
        ))
        #expect(result.externalId == "mono_abc123")
    }

    // MARK: - Same currency (no conversion needed)

    @Test func sameCurrencyTransactionHasNoBaseCurrency() {
        // UAH purchase on a UAH account — no conversion at all.
        let statement = Self.makeStatement(
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

    @Test func dateWindowsAreNewestFirst() {
        let calendar = Calendar(identifier: .gregorian)
        let from = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 0, minute: 0))!
        let to = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12, minute: 0))!

        let windows = MonobankSyncService.dateWindows(from: from, to: to)

        #expect(windows.count == 3)
        #expect(windows[0].1 == to)
        #expect(windows[0].0 > windows[1].0)
        #expect(windows[1].0 > windows[2].0)
        #expect(windows[2].0 == from)
    }

    @Test func fetchStatementsRetriesOnRateLimitWithBackoff() async throws {
        let from = Date(timeIntervalSince1970: 1_777_000_000)
        let to = Date(timeIntervalSince1970: 1_777_100_000)
        let probe = RetryProbe()

        let statements = try await MonobankSyncService.fetchStatementsWithRetry(
            fetchStatements: { accountId, requestFrom, requestTo in
                #expect(accountId == "acc-1")
                #expect(requestFrom == from)
                #expect(requestTo == to)
                let attempt = await probe.nextAttempt()
                if attempt < 3 {
                    throw MonobankAPIError.rateLimited
                }
                return [Self.makeStatement(id: "retried-success")]
            },
            accountId: "acc-1",
            from: from,
            to: to,
            sleep: { duration in
                await probe.recordSleep(duration)
            }
        )

        let snapshot = await probe.snapshot()
        #expect(snapshot.attempts == 3)
        #expect(snapshot.sleeps == [5.0, 10.0])
        #expect(statements.count == 1)
        #expect(statements.first?.id == "retried-success")
    }

    @MainActor
    @Test func syncImportsNewestWindowBeforeLaterFailure() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let from = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 0, minute: 0))!
        let to = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12, minute: 0))!
        let expectedWindows = MonobankSyncService.dateWindows(from: from, to: to)
        let probe = WindowProbe()

        do {
            _ = try await MonobankSyncService.sync(
                context: context,
                from: from,
                to: to,
                accountsToSync: [("acc-1", 980, nil)],
                ownIbans: [],
                defaultCurrency: "UAH",
                fetchStatements: { _, requestFrom, requestTo in
                    let requestIndex = await probe.recordWindow(from: requestFrom, to: requestTo)

                    if requestIndex == 1 {
                        return [
                            Self.makeStatement(
                                id: "newest-window-transaction",
                                time: Int(requestTo.timeIntervalSince1970) - 60,
                                description: "Newest window merchant"
                            )
                        ]
                    }

                    throw MonobankAPIError.serverError(500)
                },
                sleep: { duration in
                    await probe.recordSleep(duration)
                }
            )
            Issue.record("Expected sync to fail after importing the newest window.")
        } catch MonobankAPIError.serverError(let code) {
            #expect(code == 500)
        }

        let snapshot = await probe.snapshot()
        #expect(snapshot.windows.count == 2)
        #expect(snapshot.windows[0].0 == expectedWindows[0].0)
        #expect(snapshot.windows[0].1 == expectedWindows[0].1)
        #expect(snapshot.windows[1].0 == expectedWindows[1].0)
        #expect(snapshot.windows[1].1 == expectedWindows[1].1)
        #expect(snapshot.sleeps == [3.0])

        let expenses = try context.fetch(FetchDescriptor<Expense>())
        #expect(expenses.count == 1)
        #expect(expenses.first?.externalId == "mono_newest-window-transaction")
        #expect(expenses.first?.descriptionText == "Newest window merchant")
    }
}
