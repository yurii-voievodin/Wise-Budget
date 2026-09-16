import SwiftUI

struct TransactionFormHeader: View {
    let entityLabel: String
    let isEditing: Bool
    let tint: Color
    @Binding var amount: Decimal?
    @Binding var currency: String
    @FocusState.Binding var isAmountFocused: Bool

    private var currencyName: String {
        Locale.current.localizedString(forCurrencyCode: currency) ?? currency
    }

    var body: some View {
        VStack(spacing: Layout.Spacing.medium) {
            Text(isEditing ? "Edit \(entityLabel)" : "Add \(entityLabel)")
                .font(.headline)
                .foregroundStyle(.secondary)
            TransactionAmountEditor(
                amount: $amount,
                currency: $currency,
                tint: tint,
                isAmountFocused: $isAmountFocused
            )
            Text(currencyName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.16), tint.opacity(0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
