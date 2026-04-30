import SwiftUI

struct BudgetSummarySection: View {
    let monthlyBudget: Decimal
    let planCurrency: String
    let totalPlanned: Decimal
    let unplannedAmount: Decimal
    let totalActual: Decimal
    let unconvertibleExpenseCount: Int
    let onMonthlyBudgetChange: (Decimal) -> Void
    let onShowForeignExpenses: () -> Void

    @State private var draftBudget: Decimal?

    var body: some View {
        Section {
            HStack {
                Text("Monthly Budget")
                Spacer()
                TextField("0", value: $draftBudget, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .multilineTextAlignment(.trailing)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                    }
                    .onChange(of: draftBudget) { _, newValue in
                        let normalized = max(.zero, newValue ?? .zero)
                        if normalized != monthlyBudget {
                            onMonthlyBudgetChange(normalized)
                        }
                    }
                Text(planCurrency)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Total Planned")
                Spacer()
                Text("\(totalPlanned, format: .number) \(planCurrency)")
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }

            if monthlyBudget > 0 {
                HStack {
                    Text("Unplanned")
                    Spacer()
                    Text("\(unplannedAmount, format: .number) \(planCurrency)")
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(unplannedAmount < 0 ? .expense : .secondary)
                }
            }

            HStack {
                Text("Total Spent")
                Spacer()
                Text("\(totalActual, format: .number) \(planCurrency)")
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(totalActual > totalPlanned && totalPlanned > 0 ? .expense : .primary)
            }

            if monthlyBudget > 0 {
                let remaining = monthlyBudget - totalActual
                HStack {
                    Text("Remaining")
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: remaining >= 0 ? "checkmark.circle" : "exclamationmark.triangle")
                            .font(.caption)
                        Text("\(remaining, format: .number) \(planCurrency)")
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .foregroundStyle(remaining < 0 ? .expense : .income)
                }
            }

            if totalActual > 0, totalPlanned > 0 {
                BudgetProgressBar(spent: totalActual, planned: totalPlanned)
                    .listRowSeparator(.hidden)
            }

            if unconvertibleExpenseCount > 0 {
                Button(action: onShowForeignExpenses) {
                    Label(
                        "\(unconvertibleExpenseCount) expense(s) in foreign currency excluded",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
        }
        .task(id: monthlyBudget) {
            if draftBudget != monthlyBudget {
                draftBudget = monthlyBudget == .zero ? nil : monthlyBudget
            }
        }
    }
}

#Preview {
    List {
        BudgetSummarySection(
            monthlyBudget: 1000,
            planCurrency: "USD",
            totalPlanned: 750,
            unplannedAmount: 250,
            totalActual: 620,
            unconvertibleExpenseCount: 2,
            onMonthlyBudgetChange: { _ in },
            onShowForeignExpenses: {}
        )
    }
    .frame(width: 500, height: 400)
}
