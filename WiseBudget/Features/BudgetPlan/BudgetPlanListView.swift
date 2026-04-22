import SwiftUI
import SwiftData

struct BudgetPlanListView: View {
    let categories: [ExpenseCategory]
    let plan: BudgetPlan
    let planCurrency: String
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

    var body: some View {
        List {
            BudgetSummarySection(
                monthlyBudget: monthlyBudget,
                planCurrency: planCurrency,
                totalPlanned: totalPlanned,
                unplannedAmount: unplannedAmount,
                totalActual: totalActual,
                unconvertibleExpenseCount: unconvertibleExpenseCount,
                onMonthlyBudgetChange: onMonthlyBudgetChange,
                onShowForeignExpenses: onShowForeignExpenses
            )

            Section("Categories") {
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
        .focusedSceneValue(\.resetBudgetPlan, onResetPlan)
    }
}
