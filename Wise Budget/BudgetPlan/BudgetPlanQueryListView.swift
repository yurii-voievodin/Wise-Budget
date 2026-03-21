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
    let filter: MonthFilter

    @State private var resetAction: (() -> Void)?

    init(filter: MonthFilter, selectedSidebarItem: Binding<SidebarItem>, monthFilter: Binding<MonthFilter>) {
        self.filter = filter
        self._selectedSidebarItem = selectedSidebarItem
        self._monthFilter = monthFilter

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

    /// Returns the expense amount in the plan's currency, or nil if it can't be converted.
    private func budgetAmount(for expense: Expense) -> Decimal? {
        let planCurrency = currentPlan?.currency ?? defaultCurrency
        // Expense is already in the plan's currency
        if expense.currency == planCurrency {
            return expense.amount
        }
        // Expense has a base currency amount that matches the plan's currency
        if let baseAmount = expense.baseCurrencyAmount,
           expense.baseCurrency == planCurrency {
            return baseAmount
        }
        // Cannot convert — foreign currency without matching base amount
        return nil
    }

    private func actualSpending(for category: ExpenseCategory) -> Decimal {
        expenses
            .filter { $0.category?.persistentModelID == category.persistentModelID }
            .reduce(Decimal.zero) { $0 + (budgetAmount(for: $1) ?? Decimal.zero) }
    }

    private func planItem(for category: ExpenseCategory) -> BudgetPlanItem? {
        currentPlan?.items.first {
            $0.category?.persistentModelID == category.persistentModelID
        }
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
                let value = Decimal(string: newValue) ?? Decimal.zero
                let plan = ensurePlanExists()
                if let item = plan.items.first(where: {
                    $0.category?.persistentModelID == category.persistentModelID
                }) {
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
        expenses.reduce(Decimal.zero) { $0 + (budgetAmount(for: $1) ?? Decimal.zero) }
    }

    /// Number of expenses this month that can't be converted to the plan's currency.
    private var unconvertibleExpenseCount: Int {
        expenses.filter { budgetAmount(for: $0) == nil }.count
    }

    private var planCurrency: String {
        currentPlan?.currency ?? defaultCurrency
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Total Planned")
                    Spacer()
                    Text("\(totalPlanned, format: .number) \(planCurrency)")
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Total Spent")
                    Spacer()
                    Text("\(totalActual, format: .number) \(planCurrency)")
                        .fontWeight(.semibold)
                        .foregroundStyle(totalActual > totalPlanned && totalPlanned > 0 ? .red : .primary)
                }
                if totalPlanned > 0 {
                    BudgetProgressBar(spent: totalActual, planned: totalPlanned)
                }
                if unconvertibleExpenseCount > 0 {
                    Button {
                        monthFilter.foreignOnly = true
                        selectedSidebarItem = .expenses
                    } label: {
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

            Section("Categories") {
                ForEach(categories) { category in
                    let actual = actualSpending(for: category)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(category.name, systemImage: category.displayIconName)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(actual, format: .number)")
                                .foregroundStyle(.secondary)
                            Text("/")
                                .foregroundStyle(.secondary)
                            TextField(
                                "0",
                                text: plannedBinding(for: category)
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                            Text(planCurrency)
                                .foregroundStyle(.secondary)
                        }
                        let planned = planItem(for: category)?.plannedAmount ?? Decimal.zero
                        if planned > 0 {
                            BudgetProgressBar(spent: actual, planned: planned)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .focusedSceneValue(\.resetBudgetPlan, resetAction)
        .onAppear { updateResetAction() }
        .onChange(of: totalPlanned) { updateResetAction() }
    }

    private func updateResetAction() {
        guard let plan = currentPlan else { resetAction = nil; return }
        let hasNonZeroAmount = plan.items.contains { $0.plannedAmount != Decimal.zero }
        let currencyDiffers = plan.currency != defaultCurrency
        guard hasNonZeroAmount || currencyDiffers else { resetAction = nil; return }
        let currency = defaultCurrency
        resetAction = {
            plan.currency = currency
            for item in plan.items {
                item.plannedAmount = Decimal.zero
            }
        }
    }
}
