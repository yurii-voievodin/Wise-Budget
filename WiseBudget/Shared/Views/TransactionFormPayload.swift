import Foundation

/// Domain-neutral payload emitted by `TransactionFormContent` on save. Each
/// concrete form sheet (`ExpenseFormSheet`, `IncomeFormSheet`) re-wraps this
/// into a model-aligned result type so call sites can use `.destination` /
/// `.source` instead of the generic `.extraField`.
struct TransactionFormPayload<C: CategoryModel> {
    let amount: Decimal
    let currency: String
    let date: Date
    let category: C?
    let descriptionText: String?
    let extraField: String?
    let baseCurrencyAmount: Decimal?
    let baseCurrency: String?
    let isInternalTransfer: Bool
}
