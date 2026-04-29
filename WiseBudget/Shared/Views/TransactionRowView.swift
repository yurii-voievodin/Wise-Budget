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
                    HStack(spacing: 4) {
                        Text(desc)
                            .font(.body)
                            .fontWeight(.medium)
                        if item.isInternalTransfer {
                            transferBadge
                        }
                    }
                } else if item.isInternalTransfer {
                    transferBadge
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
            CurrencyAmountView(item: item, tintColor: item.isInternalTransfer ? .secondary : amountTintColor)
        }
        .contentShape(Rectangle())
    }

    private var transferBadge: some View {
        Label("Transfer", systemImage: "arrow.left.arrow.right.circle.fill")
            .labelStyle(.iconOnly)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .help("Internal transfer — excluded from statistics")
            .accessibilityLabel("Internal transfer")
    }
}

private struct PreviewTransaction: CurrencyConvertible {
    var amount: Decimal
    var currency: String
    var baseCurrencyAmount: Decimal?
    var baseCurrency: String?
    var isInternalTransfer: Bool = false
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
        Divider()
        TransactionRowView(
            descriptionText: "To my savings jar",
            categoryName: "Other",
            categoryIcon: "folder",
            extraField: nil,
            item: PreviewTransaction(amount: 250, currency: "USD", baseCurrencyAmount: nil, baseCurrency: nil, isInternalTransfer: true)
        )
    }
    .padding()
    .frame(width: 500)
}
