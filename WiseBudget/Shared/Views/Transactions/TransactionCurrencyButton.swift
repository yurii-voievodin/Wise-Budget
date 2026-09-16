import SwiftUI

struct TransactionCurrencyButton: View {
    @Binding var currency: String
    let tint: Color

    @State private var isPickerPresented = false

    var body: some View {
        Button(action: presentPicker) {
            HStack(spacing: Layout.Spacing.tight) {
                Text(currency)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(tint)
            .padding(.vertical, 5)
            .padding(.horizontal, 9)
            .background(tint.opacity(0.15), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Currency")
        .accessibilityValue(currency)
        .popover(isPresented: $isPickerPresented, arrowEdge: .bottom) {
            CurrencyPickerScreen(currency: $currency)
                .frame(minWidth: 300, idealWidth: 300, minHeight: 360, idealHeight: 360)
        }
    }

    private func presentPicker() {
        isPickerPresented = true
    }
}
