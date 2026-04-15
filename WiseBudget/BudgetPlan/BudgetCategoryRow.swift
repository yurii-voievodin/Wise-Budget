import SwiftUI

struct BudgetCategoryRow: View {
    let categoryName: String
    let categoryIcon: String
    let actual: Decimal
    let planned: Decimal
    let currency: String
    @Binding var plannedText: String
    var onCategoryTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let onCategoryTap {
                    Button {
                        onCategoryTap()
                    } label: {
                        Label(categoryName, systemImage: categoryIcon)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.plain)
                } else {
                    Label(categoryName, systemImage: categoryIcon)
                        .fontWeight(.medium)
                }
                Spacer()
                Text("\(actual, format: .number)")
                    .foregroundStyle(.secondary)
                Text("/")
                    .foregroundStyle(.secondary)
                TextField(
                    "0",
                    text: $plannedText
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .multilineTextAlignment(.trailing)
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                }
                Text(currency)
                    .foregroundStyle(.secondary)
            }
            if actual > 0 {
                BudgetProgressBar(spent: actual, planned: planned > 0 ? planned : actual)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    @Previewable @State var plannedText = "500"
    List {
        BudgetCategoryRow(
            categoryName: "Groceries",
            categoryIcon: "cart",
            actual: 320,
            planned: 500,
            currency: "USD",
            plannedText: $plannedText
        )
        BudgetCategoryRow(
            categoryName: "Transport",
            categoryIcon: "car",
            actual: 0,
            planned: 200,
            currency: "USD",
            plannedText: .constant("200")
        )
        BudgetCategoryRow(
            categoryName: "Entertainment",
            categoryIcon: "film",
            actual: 150,
            planned: 100,
            currency: "USD",
            plannedText: .constant("100")
        )
    }
    .frame(width: 500, height: 300)
}
