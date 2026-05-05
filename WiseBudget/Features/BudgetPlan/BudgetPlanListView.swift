import SwiftUI
import SwiftData

struct BudgetPlanListView: View {
    let categories: [ExpenseCategory]
    let plan: BudgetPlan
    let planCurrency: String
    let summaryTitle: String
    let totalPlanned: Decimal
    let totalActual: Decimal
    let monthlyBudget: Decimal
    let unplannedAmount: Decimal
    let unconvertibleExpenseCount: Int
    let actualSpending: (ExpenseCategory) -> Decimal
    let plannedAmount: (ExpenseCategory) -> Decimal
    let onPlannedChange: (ExpenseCategory, Decimal) -> Void
    let onMonthlyBudgetChange: (Decimal) -> Void
    let onShowForeignExpenses: () -> Void
    let onCategoryTap: (ExpenseCategory) -> Void
    let onResetPlan: () -> Void

    private let categoryColumns = [
        GridItem(.adaptive(minimum: 360), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BudgetSummarySection(
                    title: summaryTitle,
                    monthlyBudget: monthlyBudget,
                    planCurrency: planCurrency,
                    totalPlanned: totalPlanned,
                    unplannedAmount: unplannedAmount,
                    totalActual: totalActual,
                    unconvertibleExpenseCount: unconvertibleExpenseCount,
                    onMonthlyBudgetChange: onMonthlyBudgetChange,
                    onShowForeignExpenses: onShowForeignExpenses
                )

                LazyVGrid(columns: categoryColumns, spacing: 12) {
                    ForEach(categories) { category in
                        BudgetCategoryRow(
                            categoryName: category.name,
                            categoryIcon: category.displayIconName,
                            actual: actualSpending(category),
                            planned: plannedAmount(category),
                            currency: planCurrency,
                            onPlannedChange: { onPlannedChange(category, $0) },
                            onCategoryTap: { onCategoryTap(category) }
                        )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
        }
        .focusedSceneValue(\.resetBudgetPlan, onResetPlan)
    }
}
