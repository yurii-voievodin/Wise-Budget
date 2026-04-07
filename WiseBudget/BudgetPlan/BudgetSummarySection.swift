import SwiftUI

struct BudgetSummarySection: View {
    let monthlyBudgetBinding: Binding<String>
    let planCurrency: String
    let totalPlanned: Decimal
    let monthlyBudget: Decimal
    let unplannedAmount: Decimal
    let totalActual: Decimal
    let unconvertibleExpenseCount: Int
    let onShowForeignExpenses: () -> Void

    var body: some View {
        Section {
            HStack {
                Text("Monthly Budget")
                Spacer()
                TextField("0", text: monthlyBudgetBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .multilineTextAlignment(.trailing)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                    )
                Text(planCurrency)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            HStack {
                Text("Total Planned")
                Spacer()
                Text("\(totalPlanned, format: .number) \(planCurrency)")
                    .fontWeight(.semibold)
            }
            .padding(.vertical, 4)

            if monthlyBudget > 0 {
                HStack {
                    Text("Unplanned")
                    Spacer()
                    Text("\(unplannedAmount, format: .number) \(planCurrency)")
                        .fontWeight(.semibold)
                        .foregroundStyle(unplannedAmount < 0 ? .red : .secondary)
                }
                .padding(.vertical, 4)
            }

            HStack {
                Text("Total Spent")
                Spacer()
                Text("\(totalActual, format: .number) \(planCurrency)")
                    .fontWeight(.semibold)
                    .foregroundStyle(totalActual > totalPlanned && totalPlanned > 0 ? .red : .primary)
            }
            .padding(.vertical, 4)

            if monthlyBudget > 0 {
                let remaining = monthlyBudget - totalActual
                HStack {
                    Text("Remaining")
                    Spacer()
                    Text("\(remaining, format: .number) \(planCurrency)")
                        .fontWeight(.semibold)
                        .foregroundStyle(remaining < 0 ? .red : .green)
                }
                .padding(.vertical, 4)
            }

            if totalActual > 0, totalPlanned > 0 {
                BudgetProgressBar(spent: totalActual, planned: totalPlanned)
                    .padding(.vertical, 4)
                    .listRowSeparator(.hidden)
            }

            if unconvertibleExpenseCount > 0 {
                Button {
                    onShowForeignExpenses()
                } label: {
                    Label(
                        "\(unconvertibleExpenseCount) expense(s) in foreign currency excluded",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
        }
    }
}
