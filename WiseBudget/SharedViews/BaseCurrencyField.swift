import SwiftUI

struct BaseCurrencyField: View {
    @Binding var baseCurrencyAmount: Decimal?
    let amount: Decimal?
    let currency: String
    let defaultCurrency: String
    let date: Date

    @State private var suggestedAmount: Decimal?
    @State private var isFetchingRate = false
    @State private var rateService = ExchangeRateService()

    private var rateTrigger: String {
        "\(amount?.description ?? "nil")|\(currency)|\(date.timeIntervalSince1970)"
    }

    var body: some View {
        HStack {
            TextField("Amount in \(defaultCurrency)", value: $baseCurrencyAmount, format: .number)
                .frame(width: 200)
            if isFetchingRate {
                ProgressView()
                    .controlSize(.small)
            } else if let suggested = suggestedAmount, baseCurrencyAmount == nil {
                Button {
                    baseCurrencyAmount = suggested
                } label: {
                    Text("Use \(suggested as NSDecimalNumber, formatter: Self.rateFormatter) \(defaultCurrency)")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .task(id: rateTrigger) {
            suggestedAmount = nil
            guard let amount, amount > .zero else { return }
            isFetchingRate = true
            let result = await rateService.suggestedConversion(amount: amount, from: currency, to: defaultCurrency, on: date)
            isFetchingRate = false
            suggestedAmount = result
        }
    }

    private static let rateFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()
}

#Preview("Base Currency Field") {
    @Previewable @State var baseCurrencyAmount: Decimal? = nil
    Form {
        LabeledContent("Base Amount") {
            BaseCurrencyField(
                baseCurrencyAmount: $baseCurrencyAmount,
                amount: 100,
                currency: "USD",
                defaultCurrency: "EUR",
                date: .now
            )
        }
    }
    .formStyle(.grouped)
    .frame(width: 500, height: 200)
}
