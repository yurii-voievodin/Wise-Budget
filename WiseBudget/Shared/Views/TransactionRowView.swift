import SwiftUI

struct TransactionRowView: View {
    let descriptionText: String?
    let categoryName: String?
    let categoryIcon: String?
    let extraField: String?
    let item: CurrencyConvertible
    var amountTintColor: Color?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if let desc = descriptionText {
                    Text(desc)
                        .font(.body)
                        .fontWeight(.medium)
                }
                if let name = categoryName, let icon = categoryIcon {
                    Label(name, systemImage: icon)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let extra = extraField {
                    Text(extra)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            CurrencyAmountView(item: item, tintColor: amountTintColor)
        }
        .contentShape(Rectangle())
    }
}

private struct PreviewTransaction: CurrencyConvertible {
    var amount: Decimal
    var currency: String
    var baseCurrencyAmount: Decimal?
    var baseCurrency: String?
}

#Preview("Transaction Row") {
    VStack(spacing: 0) {
        TransactionRowView(
            descriptionText: "Weekly grocery run",
            categoryName: "Groceries",
            categoryIcon: "cart",
            extraField: "Whole Foods",
            item: PreviewTransaction(amount: 52.30, currency: "USD", baseCurrencyAmount: nil, baseCurrency: nil)
        )
        Divider()
        TransactionRowView(
            descriptionText: "Logo design project",
            categoryName: "Freelance",
            categoryIcon: "laptopcomputer",
            extraField: nil,
            item: PreviewTransaction(amount: 800, currency: "EUR", baseCurrencyAmount: 870, baseCurrency: "USD")
        )
        Divider()
        TransactionRowView(
            descriptionText: nil,
            categoryName: nil,
            categoryIcon: nil,
            extraField: nil,
            item: PreviewTransaction(amount: 15, currency: "USD", baseCurrencyAmount: nil, baseCurrency: nil)
        )
    }
    .padding()
    .frame(width: 500)
}
