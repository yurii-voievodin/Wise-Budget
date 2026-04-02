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

    @State private var resetAction: (() -> Void)?

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
                expense.date >= startDate && expense.date < endDate
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

    private func plannedBinding(for category: ExpenseCategory) -> Binding<String> {
        Binding(
            get: {
                let amount = planItem(for: category)?.plannedAmount ?? Decimal.zero
                return amount == Decimal.zero ? "" : "\(amount)"
            },
            set: { newValue in
                let value = max(Decimal.zero, Decimal(string: newValue) ?? Decimal.zero)
                let plan = ensurePlanExists()
                if let item = planItemsByCategory[category.persistentModelID] {
                    item.plannedAmount = value
                } else {
                    let item = BudgetPlanItem(plannedAmount: value, plan: plan, category: category)
                    modelContext.insert(item)
                }
            }
        )
    }

    private var totalPlanned: Decimal {
        currentPlan?.items.reduce(Decimal.zero) { $0 + $1.plannedAmount } ?? Decimal.zero
    }

    private var totalActual: Decimal {
        expenses.reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: planCurrency) ?? Decimal.zero) }
    }

    private var unconvertibleExpenseCount: Int {
        expenses.filter { $0.convertedAmount(to: planCurrency) == nil }.count
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

    private var monthlyBudgetBinding: Binding<String> {
        Binding(
            get: {
                let amount = currentPlan?.monthlyBudget ?? Decimal.zero
                return amount == Decimal.zero ? "" : "\(amount)"
            },
            set: { newValue in
                let value = max(Decimal.zero, Decimal(string: newValue) ?? Decimal.zero)
                let plan = ensurePlanExists()
                plan.monthlyBudget = value
            }
        )
    }

    var body: some View {
        if currentPlan == nil {
            BudgetEmptyStateView(filter: filter)
        } else {
            budgetList
        }
    }

    private var budgetList: some View {
        List {
            BudgetSummarySection(
                monthlyBudgetBinding: monthlyBudgetBinding,
                planCurrency: planCurrency,
                totalPlanned: totalPlanned,
                monthlyBudget: monthlyBudget,
                unplannedAmount: unplannedAmount,
                totalActual: totalActual,
                unconvertibleExpenseCount: unconvertibleExpenseCount,
                onShowForeignExpenses: {
                    monthFilter.foreignOnly = true
                    selectedSidebarItem = .expenses
                }
            )

            Section("Categories") {
                ForEach(categories) { category in
                    let actual = actualSpending(for: category)

                    BudgetCategoryRow(
                        categoryName: category.name,
                        categoryIcon: category.displayIconName,
                        actual: actual,
                        planned: planItem(for: category)?.plannedAmount ?? Decimal.zero,
                        currency: planCurrency,
                        plannedText: plannedBinding(for: category),
                        onCategoryTap: {
                            expenseCategoryFilter = category.name
                            selectedSidebarItem = .expenses
                        }
                    )
                }
            }
        }
        .focusedSceneValue(\.resetBudgetPlan, resetAction)
        .onAppear { updateResetAction() }
    }

    private func updateResetAction() {
        guard let plan = currentPlan else { resetAction = nil; return }
        resetAction = {
            modelContext.delete(plan)
        }
    }
}
