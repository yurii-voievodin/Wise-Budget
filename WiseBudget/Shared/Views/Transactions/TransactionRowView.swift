import SwiftUI

struct TransactionRowView: View {
    let descriptionText: String?
    let categoryName: String?
    let categoryIcon: String?
    var categoryColor: Color? = nil
    let extraField: String?
    let item: CurrencyConvertible
    var amountTintColor: Color?

    var body: some View {
        let source = TransactionSource(externalId: item.externalId)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if descriptionText != nil || item.isInternalTransfer || source.isSynced {
                    HStack(spacing: Layout.Spacing.tight) {
                        if let desc = descriptionText {
                            Text(desc)
                                .font(.body)
                            if item.isInternalTransfer {
                                TransferBadge()
                            }
                        } else if item.isInternalTransfer {
                            Label("Transfer", systemImage: "arrow.left.arrow.right.circle.fill")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Internal transfer")
                        }
                        TransactionSourceBadge(source: source)
                    }
                }
                if let name = categoryName, let icon = categoryIcon {
                    HStack(spacing: Layout.Spacing.snug) {
                        CategoryIconBadge(systemName: icon, color: categoryColor ?? .secondary, size: 22)
                        Text(name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if let extra = extraField {
                    Text(extra)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            CurrencyAmountView(item: item, tintColor: item.isInternalTransfer ? .secondary : amountTintColor)
                .opacity(item.isInternalTransfer ? 0.7 : 1)
        }
        .contentShape(Rectangle())
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
