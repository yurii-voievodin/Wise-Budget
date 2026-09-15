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
        VStack(spacing: 0) {
            searchField
            Divider()
            list
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search currency", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            List(filteredOptions) { option in
                Button {
                    currency = option.code
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Text(option.code)
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)
                            .frame(width: 42, alignment: .leading)
                        Text(option.label)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if option.code == currency {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
            .onAppear { proxy.scrollTo(currency, anchor: .center) }
        }
    }
}

private struct CurrencyOption: Identifiable {
    let code: String
    let label: String
    var id: String { code }
}

#Preview {
    @Previewable @State var currency = "USD"
    CurrencyPickerScreen(currency: $currency)
        .frame(width: 300, height: 360)
}
