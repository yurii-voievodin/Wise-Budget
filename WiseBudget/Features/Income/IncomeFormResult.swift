import Foundation

/// All fields produced by `IncomeFormSheet` on save
struct IncomeFormResult {
    let amount: Decimal
    let currency: String
    let date: Date
    let category: IncomeCategory?
    let descriptionText: String?
    let source: String?
    let baseCurrencyAmount: Decimal?
    let baseCurrency: String?
    let isInternalTransfer: Bool

    func apply(to income: Income) {
        income.amount = amount
        income.currency = currency
        income.date = date
        income.category = category
        income.descriptionText = descriptionText
        income.source = source
        income.baseCurrencyAmount = baseCurrencyAmount
        income.baseCurrency = baseCurrency
        income.isInternalTransfer = isInternalTransfer
    }

    func makeIncome() -> Income {
        Income(
            amount: amount,
            currency: currency,
            date: date,
            category: category,
            descriptionText: descriptionText,
            source: source,
            baseCurrencyAmount: baseCurrencyAmount,
            baseCurrency: baseCurrency,
            isInternalTransfer: isInternalTransfer
        )
    }
}
