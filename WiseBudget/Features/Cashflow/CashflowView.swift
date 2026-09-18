import SwiftUI
import SwiftData

struct CashflowView: View {
    @Query(filter: #Predicate<Expense> { !$0.isInternalTransfer }, sort: \Expense.date) private var allExpenses: [Expense]
    @Query(filter: #Predicate<Income> { !$0.isInternalTransfer }, sort: \Income.date) private var allIncomes: [Income]
    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback
    @AppStorage(CashflowTimeRange.storageKey) private var timeRange: CashflowTimeRange = .sixMonths

    let filter: MonthFilter
    var onSelectExpenseMonth: ((MonthKey) -> Void)? = nil
    var onSelectIncomeMonth: ((MonthKey) -> Void)? = nil

    enum CashflowTab: Hashable {
        case overview
        case expenses
        case income
    }

    @State private var selectedTab: CashflowTab = .overview

    private var aggregate: CashflowAggregate {
        CashflowAggregate.make(
            timeRange: timeRange,
            filter: filter,
            expenses: allExpenses,
            incomes: allIncomes,
            currency: defaultCurrency
        )
    }

    var body: some View {
        Group {
            switch selectedTab {
            case .overview:
                CashflowOverviewContent(aggregate: aggregate, currency: defaultCurrency)
            case .expenses:
                ExpenseComparisonView(filter: filter, timeRange: $timeRange, onSelectMonth: selectExpenseMonth)
                    .id(filter)
            case .income:
                IncomeComparisonView(filter: filter, timeRange: $timeRange, onSelectMonth: selectIncomeMonth)
                    .id(filter)
            }
        }
        .toolbar {
            ToolbarItem {
                CashflowSectionPicker(selectedTab: $selectedTab)
            }
            ToolbarItem(placement: .primaryAction) {
                CashflowTimeRangeMenu(timeRange: $timeRange)
            }
        }
        .navigationTitle("")
    }

    private func selectExpenseMonth(_ month: MonthKey) {
        onSelectExpenseMonth?(month)
    }

    private func selectIncomeMonth(_ month: MonthKey) {
        onSelectIncomeMonth?(month)
    }
}

#Preview {
    CashflowView(filter: MonthFilter(year: 2026, month: 3))
        .modelContainer(PreviewSampleData.container)
        .frame(width: 600, height: 700)
}
