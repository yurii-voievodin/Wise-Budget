import SwiftUI

struct CashflowBarRow: View {
    let label: String
    let amount: Decimal
    let maxValue: Decimal
    let tint: Color
    let currency: String

    private var widthRatio: Double {
        guard maxValue > 0 else { return 0 }
        let ratio = NSDecimalNumber(decimal: amount / maxValue).doubleValue
        return min(max(ratio, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.tight) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: Layout.Spacing.tight) {
                    Text(amount, format: .number.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                    Text(currency)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            ZStack {
                Capsule()
                    .fill(tint.opacity(0.12))
                Capsule()
                    .fill(tint)
                    .scaleEffect(x: widthRatio, anchor: .leading)
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
    }
}
