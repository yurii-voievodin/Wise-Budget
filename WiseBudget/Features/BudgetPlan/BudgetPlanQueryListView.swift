import SwiftUI
import SwiftData

struct BudgetPlanQueryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [BudgetPlan]
    @Query private var expenses: [Expense]
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    @Binding var selectedSidebarItem: SidebarItem
    @Binding var monthFilter: MonthFilter
    @Binding var expenseCategoryFilter: String?
    let filter: MonthFilter

    init(filter: MonthFilter, selectedSidebarItem: Binding<SidebarItem>, monthFilter: Binding<MonthFilter>, expenseCategoryFilter: Binding<String?>) {
        self.filter = filter
        self._selectedSidebarItem = selectedSidebarItem
        self._monthFilter = monthFilter
        self._expenseCategoryFilter = expenseCategoryFilter

        let filterYear = filter.year
        let filterMonth = filter.month

        self._plans = Query(
            filter: #Predicate<BudgetPlan> { plan in
                plan.year == filterYear && plan.month == filterMonth
            }
        )

        let startDate = filter.startOfMonth
        let endDate = filter.startOfNextMonth

        self._expenses = Query(
            filter: #Predicate<Expense> { expense in
                expense.date >= startDate && expense.date < endDate && !expense.isInternalTransfer
            }
        )
    }

    private var currentPlan: BudgetPlan? {
        plans.first
    }

    private func actualSpending(for category: ExpenseCategory) -> Decimal {
        expenses
            .filter { $0.category?.persistentModelID == category.persistentModelID }
            .reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: planCurrency) ?? Decimal.zero) }
    }

    private var categoryIds: Set<PersistentIdentifier> {
        Set(categories.map(\.persistentModelID))
    }

    private var planItemsByCategory: [PersistentIdentifier: BudgetPlanItem] {
        guard let plan = currentPlan else { return [:] }
        let validIds = categoryIds
        return Dictionary(uniqueKeysWithValues: plan.items.compactMap { item in
            guard let id = item.category?.persistentModelID, validIds.contains(id) else { return nil }
            return (id, item)
        })
    }

    private func planItem(for category: ExpenseCategory) -> BudgetPlanItem? {
        planItemsByCategory[category.persistentModelID]
    }

    private func plannedAmount(for category: ExpenseCategory) -> Decimal {
        planItem(for: category)?.plannedAmount ?? .zero
    }

    private func ensurePlanExists() -> BudgetPlan {
        if let plan = currentPlan { return plan }
        let plan = BudgetPlan(year: filter.year, month: filter.month, currency: defaultCurrency)
        modelContext.insert(plan)
        for category in categories {
            let item = BudgetPlanItem(plannedAmount: 0, plan: plan, category: category)
            modelContext.insert(item)
        }
        return plan
    }

    private func updatePlannedAmount(for category: ExpenseCategory, to value: Decimal) {
        let plan = ensurePlanExists()
        if let item = planItemsByCategory[category.persistentModelID] {
            item.plannedAmount = value
        } else {
            let item = BudgetPlanItem(plannedAmount: value, plan: plan, category: category)
            modelContext.insert(item)
        }
    }

    private func updateMonthlyBudget(to value: Decimal) {
        let plan = ensurePlanExists()
        plan.monthlyBudget = value
    }

    private var totalPlanned: Decimal {
        currentPlan?.items.reduce(Decimal.zero) { $0 + $1.plannedAmount } ?? Decimal.zero
    }

    private var totalActual: Decimal {
        expenses.reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: planCurrency) ?? Decimal.zero) }
    }

    private var unconvertibleExpenseCount: Int {
        expenses.count(where: { $0.convertedAmount(to: planCurrency) == nil })
    }

    private var planCurrency: String {
        currentPlan?.currency ?? defaultCurrency
    }

    private var monthlyBudget: Decimal {
        currentPlan?.monthlyBudget ?? Decimal.zero
    }

    private var unplannedAmount: Decimal {
        monthlyBudget - totalPlanned
    }

    var body: some View {
        if let plan = currentPlan {
            BudgetPlanListView(
                categories: categories,
                plan: plan,
                planCurrency: planCurrency,
                totalPlanned: totalPlanned,
                totalActual: totalActual,
                monthlyBudget: monthlyBudget,
                unplannedAmount: unplannedAmount,
                unconvertibleExpenseCount: unconvertibleExpenseCount,
                actualSpending: actualSpending,
                plannedAmount: plannedAmount,
                onPlannedChange: updatePlannedAmount,
                onMonthlyBudgetChange: updateMonthlyBudget,
                onShowForeignExpenses: showForeignExpenses,
                onCategoryTap: showExpensesForCategory,
                onResetPlan: { resetPlan(plan) }
            )
        } else {
            BudgetEmptyStateView(filter: filter)
        }
    }

    private func showForeignExpenses() {
        monthFilter.foreignOnly = true
        selectedSidebarItem = .expenses
    }

    private func showExpensesForCategory(_ category: ExpenseCategory) {
        expenseCategoryFilter = category.name
        selectedSidebarItem = .expenses
    }

    private func resetPlan(_ plan: BudgetPlan) {
        modelContext.delete(plan)
    }
}

#Preview {
    @Previewable @State var selectedSidebarItem: SidebarItem = .budgetPlan
    @Previewable @State var monthFilter = MonthFilter(year: 2026, month: 3)
    @Previewable @State var expenseCategoryFilter: String? = nil
    BudgetPlanQueryListView(
        filter: MonthFilter(year: 2026, month: 3),
        selectedSidebarItem: $selectedSidebarItem,
        monthFilter: $monthFilter,
        expenseCategoryFilter: $expenseCategoryFilter
    )
    .modelContainer(PreviewSampleData.container)
    .frame(width: 600, height: 500)
}
