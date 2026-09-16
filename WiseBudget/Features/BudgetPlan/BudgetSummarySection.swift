import SwiftUI

struct BudgetSummarySection: View {
    let title: String
    let monthlyBudget: Decimal
    let planCurrency: String
    let totalPlanned: Decimal
    let unplannedAmount: Decimal
    let totalActual: Decimal
    let unconvertibleExpenseCount: Int
    let onMonthlyBudgetChange: (Decimal) -> Void
    let onShowForeignExpenses: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 200), spacing: Layout.Spacing.medium)
    ]

    private var remaining: Decimal { monthlyBudget - totalActual }
    private var isOverPlanned: Bool { totalActual > totalPlanned && totalPlanned > 0 }
    private var isOverBudget: Bool { remaining < 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: Layout.Spacing.medium) {
                Text(title)
                    .font(.title3)
                    .bold()
                Spacer(minLength: 12)
                Label("Monthly Budget", systemImage: "wallet.bifold")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                PlannedAmountField(
                    value: monthlyBudget,
                    currency: planCurrency,
                    width: 110,
                    onChange: onMonthlyBudgetChange
                )
            }

            Divider()

            LazyVGrid(columns: columns, spacing: Layout.Spacing.medium) {
                StatCard(
                    label: "Total Planned",
                    icon: "list.bullet.rectangle",
                    color: .accentColor,
                    amount: totalPlanned,
                    currency: planCurrency,
                    bold: true
                )
                if monthlyBudget > 0 {
                    StatCard(
                        label: "Unplanned",
                        icon: "questionmark.circle",
                        color: unplannedAmount < 0 ? .expense : .secondary,
                        amount: unplannedAmount,
                        currency: planCurrency,
                        signed: true
                    )
                }
                StatCard(
                    label: "Total Spent",
                    icon: "creditcard",
                    color: isOverPlanned ? .expense : .primary,
                    amount: totalActual,
                    currency: planCurrency,
                    bold: true
                )
                if monthlyBudget > 0 {
                    StatCard(
                        label: "Remaining",
                        icon: isOverBudget ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                        color: isOverBudget ? .expense : .income,
                        amount: remaining,
                        currency: planCurrency,
                        signed: true,
                        bold: true
                    )
                }
            }

            if totalActual > 0, totalPlanned > 0 {
                BudgetProgressBar(spent: totalActual, planned: totalPlanned)
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
        .padding(Layout.Spacing.large)
        .cardBackground(cornerRadius: Layout.Radius.large)
        .overlay {
            RoundedRectangle(cornerRadius: Layout.Radius.large)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        }
    }
}

#Preview {
    ScrollView {
        BudgetSummarySection(
            title: "May 2026",
            monthlyBudget: 1000,
            planCurrency: "USD",
            totalPlanned: 750,
            unplannedAmount: 250,
            totalActual: 620,
            unconvertibleExpenseCount: 2,
            onMonthlyBudgetChange: { _ in },
            onShowForeignExpenses: {}
        )
        .padding()
    }
    .frame(width: 500, height: 400)
}
