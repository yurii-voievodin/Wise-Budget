import SwiftUI

struct MonobankAccountRow: View {
    let account: MonobankAccount
    let isSelected: Bool
    let onToggle: () -> Void

    private var currency: String {
        MonobankAPIClient.currencyString(for: account.currencyCode)
    }

    private var balance: Decimal {
        Decimal(account.balance) / 100
    }

    private var maskedPan: String {
        account.maskedPan?.first ?? ""
    }

    private var accountLabel: String {
        if let type = account.type {
            return "\(type.capitalized) (\(currency))"
        }
        return currency
    }

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(accountLabel)
                        .font(.callout)
                    if !maskedPan.isEmpty {
                        Text(maskedPan)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("\(balance, format: .number.precision(.fractionLength(2))) \(currency)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, Layout.Spacing.snug)
            .padding(.horizontal, Layout.Spacing.small)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            .clipShape(.rect(cornerRadius: Layout.Radius.small))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
