import SwiftUI

struct CurrencyPickerScreen: View {
    @Binding var currency: String
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""

    private static let options: [CurrencyOption] = Locale.commonISOCurrencyCodes.map { code in
        CurrencyOption(code: code, label: Locale.current.localizedString(forCurrencyCode: code) ?? code)
    }

    private var filteredOptions: [CurrencyOption] {
        guard !searchText.isEmpty else { return Self.options }
        let query = searchText.lowercased()
        return Self.options.filter {
            $0.code.lowercased().contains(query) || $0.label.lowercased().contains(query)
        }
    }

    var body: some View {
        List(filteredOptions) { option in
            Button {
                currency = option.code
                dismiss()
            } label: {
                HStack {
                    Text("\(option.code) – \(option.label)")
                    Spacer()
                    if option.code == currency {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search currency")
        .navigationTitle("Currency")
    }
}

private struct CurrencyOption: Identifiable {
    let code: String
    let label: String
    var id: String { code }
}

#Preview {
    @Previewable @State var currency = "USD"
    NavigationStack {
        CurrencyPickerScreen(currency: $currency)
    }
    .frame(width: 400, height: 500)
}
