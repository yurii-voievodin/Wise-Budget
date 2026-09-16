import SwiftUI

struct CurrencyPickerScreen: View {
    @Binding var currency: String

    @State private var searchText: String = ""

    private static let options: [CurrencyOption] = Locale.commonISOCurrencyCodes.map { code in
        CurrencyOption(code: code, label: Locale.current.localizedString(forCurrencyCode: code) ?? code)
    }

    private var filteredOptions: [CurrencyOption] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return Self.options }
        return Self.options.filter {
            $0.code.localizedStandardContains(needle) || $0.label.localizedStandardContains(needle)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            CurrencySearchField(searchText: $searchText)
            Divider()
            let options = filteredOptions
            if options.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                CurrencyOptionList(options: options, currency: $currency)
            }
        }
    }
}

#Preview {
    @Previewable @State var currency = "USD"
    CurrencyPickerScreen(currency: $currency)
        .frame(width: 300, height: 360)
}
