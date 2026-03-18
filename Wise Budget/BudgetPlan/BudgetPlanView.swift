import SwiftUI
import SwiftData

struct BudgetPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetPlan.year) private var allPlans: [BudgetPlan]
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]
    @Query private var allExpenses: [Expense]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    @Binding var selectedSidebarItem: SidebarItem
    @Binding var monthFilter: MonthFilter

    @State private var resetAction: (() -> Void)?

    private var currentPlan: BudgetPlan? {
        allPlans.first { $0.year == monthFilter.year && $0.month == monthFilter.month }
    }

    private var monthStart: Date {
        monthFilter.startOfMonth
    }

    private var nextMonthStart: Date {
        monthFilter.startOfNextMonth
    }

    private var monthExpenses: [Expense] {
        allExpenses.filter { $0.date >= monthStart && $0.date < nextMonthStart }
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
        monthExpenses
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
        let plan = BudgetPlan(year: monthFilter.year, month: monthFilter.month, currency: defaultCurrency)
        modelContext.insert(plan)
        for category in categories {
            let item = BudgetPlanItem(plannedAmount: 0, plan: plan, category: category)
            modelContext.insert(item)
        }
        return plan
    }

    private func plannedBinding(for category: ExpenseCategory) -> Binding<Decimal> {
        Binding(
            get: { planItem(for: category)?.plannedAmount ?? Decimal.zero },
            set: { newValue in
                let plan = ensurePlanExists()
                if let item = plan.items.first(where: {
                    $0.category?.persistentModelID == category.persistentModelID
                }) {
                    item.plannedAmount = newValue
                } else {
                    let item = BudgetPlanItem(plannedAmount: newValue, plan: plan, category: category)
                    modelContext.insert(item)
                }
            }
        )
    }

    private var totalPlanned: Decimal {
        currentPlan?.items.reduce(Decimal.zero) { $0 + $1.plannedAmount } ?? Decimal.zero
    }

    private var totalActual: Decimal {
        monthExpenses.reduce(Decimal.zero) { $0 + (budgetAmount(for: $1) ?? Decimal.zero) }
    }

    /// Number of expenses this month that can't be converted to the plan's currency.
    private var unconvertibleExpenseCount: Int {
        monthExpenses.filter { budgetAmount(for: $0) == nil }.count
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
                            Text(category.name)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(actual, format: .number)")
                                .foregroundStyle(.secondary)
                            Text("/")
                                .foregroundStyle(.secondary)
                            TextField(
                                "0",
                                value: plannedBinding(for: category),
                                format: .number
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
        .navigationTitle(monthTitle)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 4) {
                    Button {
                        moveMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    Button {
                        moveMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }
            }
        }
        .focusedSceneValue(\.resetBudgetPlan, resetAction)
        .onAppear { updateResetAction() }
        .onChange(of: monthFilter.year) { updateResetAction() }
        .onChange(of: monthFilter.month) { updateResetAction() }
        .onChange(of: totalPlanned) { updateResetAction() }
    }

    private var monthTitle: String {
        monthStart.formatted(.dateTime.month(.wide).year())
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

    private func moveMonth(by delta: Int) {
        let moved = monthFilter.moved(by: delta)
        monthFilter.year = moved.year
        monthFilter.month = moved.month
    }


}

extension FocusedValues {
    @Entry var resetBudgetPlan: (() -> Void)? = nil
}

struct BudgetProgressBar: View {
    let spent: Decimal
    let planned: Decimal

    private var progress: Double {
        guard planned > 0 else { return 0 }
        return min(Double(truncating: spent as NSDecimalNumber) / Double(truncating: planned as NSDecimalNumber), 1.0)
    }

    private var isOverBudget: Bool {
        spent > planned
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(isOverBudget ? Color.red : Color.accentColor)
                    .frame(width: geo.size.width * progress, height: 8)
            }
        }
        .frame(height: 8)
    }
}
#Preview {
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        BudgetPlanView(selectedSidebarItem: .constant(.budgetPlan), monthFilter: .constant(MonthFilter(year: 2025, month: 1)))
    }
    .modelContainer(PreviewSampleData.container)
}

