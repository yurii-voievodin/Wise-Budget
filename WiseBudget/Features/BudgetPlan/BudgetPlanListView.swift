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
        GridItem(.adaptive(minimum: 360), spacing: Layout.Spacing.large)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.Spacing.large) {
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

                LazyVGrid(columns: categoryColumns, spacing: Layout.Spacing.medium) {
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
            .padding(.horizontal, Layout.Spacing.medium)
            .padding(.vertical, Layout.Spacing.large)
        }
        .focusedSceneValue(\.resetBudgetPlan, ResetBudgetPlanAction(onResetPlan))
    }
}
