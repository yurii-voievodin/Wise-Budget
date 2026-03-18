import SwiftUI
import SwiftData

struct BudgetPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetPlan.year) private var allPlans: [BudgetPlan]
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]
    @Query private var allExpenses: [Expense]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    @State private var displayedYear: Int
    @State private var displayedMonth: Int
    @State private var showResetConfirmation = false

    init() {
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        _displayedYear = State(initialValue: now.year!)
        _displayedMonth = State(initialValue: now.month!)
    }

    private var currentPlan: BudgetPlan? {
        allPlans.first { $0.year == displayedYear && $0.month == displayedMonth }
    }

    private var monthStart: Date {
        Calendar.current.date(from: DateComponents(year: displayedYear, month: displayedMonth, day: 1))!
    }

    private var nextMonthStart: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: monthStart)!
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
        let plan = BudgetPlan(year: displayedYear, month: displayedMonth, currency: defaultCurrency)
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
                    Label(
                        "\(unconvertibleExpenseCount) expense(s) in foreign currency excluded",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
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
            ToolbarItem {
                if currentPlan != nil {
                    Button("Reset Plan", role: .destructive) {
                        showResetConfirmation = true
                    }
                }
            }
        }
        .confirmationDialog(
            "Reset Plan",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Plan", role: .destructive) {
                resetPlan()
            }
        } message: {
            Text("This will reset all planned amounts to zero and update the currency to \(defaultCurrency).")
        }
    }

    private var monthTitle: String {
        monthStart.formatted(.dateTime.month(.wide).year())
    }

    private func resetPlan() {
        guard let plan = currentPlan else { return }
        plan.currency = defaultCurrency
        for item in plan.items {
            item.plannedAmount = Decimal.zero
        }
    }

    private func moveMonth(by delta: Int) {
        var comps = DateComponents(year: displayedYear, month: displayedMonth)
        comps.month! += delta
        let date = Calendar.current.date(from: comps)!
        let newComps = Calendar.current.dateComponents([.year, .month], from: date)
        displayedYear = newComps.year!
        displayedMonth = newComps.month!
    }


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
        BudgetPlanView()
    }
    .modelContainer(PreviewSampleData.container)
}

