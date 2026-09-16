import SwiftUI

struct BaseCurrencyAmountCell: View {
    let item: CurrencyConvertible
    let defaultCurrency: String

    var body: some View {
        HStack(spacing: Layout.Spacing.tight) {
            Spacer()
            if item.currency == defaultCurrency {
                Text("—").foregroundStyle(.secondary)
            } else if let base = item.baseCurrencyAmount,
                      let baseCur = item.baseCurrency {
                Text(base, format: .number.precision(.fractionLength(2)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text(baseCur)
                    .foregroundStyle(.secondary)
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
    }
}
