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

    @State private var draftBudget: Decimal?

    private let columns = [
        GridItem(.adaptive(minimum: 200), spacing: 12)
    ]

    private var remaining: Decimal { monthlyBudget - totalActual }
    private var isOverPlanned: Bool { totalActual > totalPlanned && totalPlanned > 0 }
    private var isOverBudget: Bool { remaining < 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack {
                Label("Monthly Budget", systemImage: "wallet.bifold")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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

            LazyVGrid(columns: columns, spacing: 12) {
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
        .padding(12)
        .cardBackground()
        .task(id: monthlyBudget) {
            if draftBudget != monthlyBudget {
                draftBudget = monthlyBudget == .zero ? nil : monthlyBudget
            }
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
