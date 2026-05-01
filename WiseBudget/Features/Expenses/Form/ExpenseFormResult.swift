import Foundation

/// All fields produced by `ExpenseFormSheet` on save
struct ExpenseFormResult {
    let amount: Decimal
    let currency: String
    let date: Date
    let category: ExpenseCategory?
    let descriptionText: String?
    let destination: String?
    let baseCurrencyAmount: Decimal?
    let baseCurrency: String?
    let isInternalTransfer: Bool

    func apply(to expense: Expense) {
        expense.amount = amount
        expense.currency = currency
        expense.date = date
        expense.category = category
        expense.descriptionText = descriptionText
        expense.destination = destination
        expense.baseCurrencyAmount = baseCurrencyAmount
        expense.baseCurrency = baseCurrency
        expense.isInternalTransfer = isInternalTransfer
    }

    func makeExpense() -> Expense {
        Expense(
            amount: amount,
            currency: currency,
            date: date,
            category: category,
            descriptionText: descriptionText,
            destination: destination,
            baseCurrencyAmount: baseCurrencyAmount,
            baseCurrency: baseCurrency,
            isInternalTransfer: isInternalTransfer
        )
    }
}
