import SwiftUI

struct CurrencyAmountView: View {
    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    let item: CurrencyConvertible

    var body: some View {
        VStack(alignment: .trailing) {
            HStack(spacing: 4) {
                if item.currency != defaultCurrency {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text("\(item.amount, format: .number) \(item.currency)")
                    .font(.headline)
            }
            if let baseAmount = item.baseCurrencyAmount,
               let baseCur = item.baseCurrency {
                Text("\(baseAmount, format: .number) \(baseCur)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
