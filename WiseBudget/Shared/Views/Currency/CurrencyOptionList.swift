import SwiftUI

struct CurrencyOptionList: View {
    let options: [CurrencyOption]
    @Binding var currency: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollViewReader { proxy in
            List(options) { option in
                Button {
                    select(option)
                } label: {
                    CurrencyOptionRow(option: option, isSelected: option.code == currency)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
            .onAppear { proxy.scrollTo(currency, anchor: .center) }
        }
    }

    private func select(_ option: CurrencyOption) {
        currency = option.code
        dismiss()
    }
}
