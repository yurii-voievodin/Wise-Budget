import SwiftUI

struct TransactionAmountEditor: View {
    @Binding var amount: Decimal?
    @Binding var currency: String
    let tint: Color
    @FocusState.Binding var isAmountFocused: Bool

    @ScaledMetric(relativeTo: .largeTitle) private var fieldWidth: Double = 180

    var body: some View {
        HStack(spacing: Layout.Spacing.medium) {
            TextField("0", value: $amount, format: .number)
                .textFieldStyle(.plain)
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .focused($isAmountFocused)
                .frame(minWidth: fieldWidth)
                .accessibilityLabel("Amount")
            TransactionCurrencyButton(currency: $currency, tint: tint)
        }
        .padding(.vertical, Layout.Spacing.small)
        .padding(.horizontal, 14)
        .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(tint.opacity(isAmountFocused ? 0.6 : 0.2), lineWidth: 1)
        }
        .fixedSize()
    }
}
