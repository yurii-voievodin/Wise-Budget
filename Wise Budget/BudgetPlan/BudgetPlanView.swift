import SwiftUI
import SwiftData

struct BudgetPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetPlan.year) private var allPlans: [BudgetPlan]
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]
    @Query private var allExpenses: [Expense]

    @State private var displayedYear: Int
    @State private var displayedMonth: Int

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

    private func budgetAmount(for expense: Expense) -> Decimal {
        expense.baseCurrencyAmount ?? expense.amount
    }

    private func actualSpending(for category: ExpenseCategory) -> Decimal {
        monthExpenses
            .filter { $0.category?.persistentModelID == category.persistentModelID }
            .reduce(Decimal.zero) { $0 + budgetAmount(for: $1) }
    }

    private func planItem(for category: ExpenseCategory) -> BudgetPlanItem? {
        currentPlan?.items.first {
            $0.category?.persistentModelID == category.persistentModelID
        }
    }

    private var totalPlanned: Decimal {
        currentPlan?.items.reduce(Decimal.zero) { $0 + $1.plannedAmount } ?? Decimal.zero
    }

    private var totalActual: Decimal {
        monthExpenses.reduce(Decimal.zero) { $0 + budgetAmount(for: $1) }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Total Planned")
                    Spacer()
                    Text(totalPlanned, format: .number)
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Total Spent")
                    Spacer()
                    Text(totalActual, format: .number)
                        .fontWeight(.semibold)
                        .foregroundStyle(totalActual > totalPlanned && totalPlanned > 0 ? .red : .primary)
                }
                if totalPlanned > 0 {
                    BudgetProgressBar(spent: totalActual, planned: totalPlanned)
                }
            }

            Section("Categories") {
                ForEach(categories) { category in
                    let planned = planItem(for: category)?.plannedAmount ?? Decimal.zero
                    let actual = actualSpending(for: category)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(category.name)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(actual, format: .number) / \(planned, format: .number)")
                                .foregroundStyle(.secondary)
                        }
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
                if currentPlan == nil {
                    Button("Create Plan") {
                        createPlan()
                    }
                }
            }
            ToolbarItem {
                if currentPlan != nil {
                    Button("Edit Plan") {
                        // handled via sheet
                        isEditingPlan = true
                    }
                }
            }
        }
        .sheet(isPresented: $isEditingPlan) {
            if let plan = currentPlan {
                EditBudgetPlanSheet(plan: plan, categories: categories)
            }
        }
    }

    @State private var isEditingPlan = false

    private var monthTitle: String {
        monthStart.formatted(.dateTime.month(.wide).year())
    }

    private func moveMonth(by delta: Int) {
        var comps = DateComponents(year: displayedYear, month: displayedMonth)
        comps.month! += delta
        let date = Calendar.current.date(from: comps)!
        let newComps = Calendar.current.dateComponents([.year, .month], from: date)
        displayedYear = newComps.year!
        displayedMonth = newComps.month!
    }

    private func createPlan() {
        let plan = BudgetPlan(year: displayedYear, month: displayedMonth)
        modelContext.insert(plan)
        for category in categories {
            let item = BudgetPlanItem(plannedAmount: 0, plan: plan, category: category)
            modelContext.insert(item)
        }
        isEditingPlan = true
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
