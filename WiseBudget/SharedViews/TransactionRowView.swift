import SwiftUI

struct TransactionRowView: View {
    let descriptionText: String?
    let categoryName: String?
    let categoryIcon: String?
    let extraField: String?
    let item: CurrencyConvertible

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if let desc = descriptionText {
                    Text(desc)
                        .font(.body)
                        .fontWeight(.medium)
                }
                if let name = categoryName, let icon = categoryIcon {
                    Label(name, systemImage: icon)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if let extra = extraField {
                    Text(extra)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            CurrencyAmountView(item: item)
        }
        .contentShape(Rectangle())
    }
}
