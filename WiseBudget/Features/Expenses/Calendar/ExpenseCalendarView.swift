import SwiftUI
import SwiftData

struct ExpenseCalendarView: View {
    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]

    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback

    let filter: MonthFilter
    @Bindable var syncService: BankSyncService

    init(filter: MonthFilter, syncService: BankSyncService) {
        self.filter = filter
        self.syncService = syncService

        let startDate = filter.startOfMonth
        let endDate = filter.startOfNextMonth

        self._expenses = Query(
            filter: #Predicate<Expense> { expense in
                expense.date >= startDate && expense.date < endDate && !expense.isInternalTransfer
            },
            sort: \.date
        )
        self._incomes = Query(
            filter: #Predicate<Income> { income in
                income.date >= startDate && income.date < endDate && !income.isInternalTransfer
            },
            sort: \.date
        )
    }

    // MARK: - Calendar Data

    private var calendar: Calendar { Calendar.current }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: filter.startOfMonth)?.count ?? 30
    }

    private func classifyExpense(_ expense: Expense) -> (currency: String, amount: Decimal) {
        if let converted = expense.convertedAmount(to: defaultCurrency) {
            return (defaultCurrency, converted)
        }
        return (expense.currency, expense.amount)
    }

    private var dailyTotalsByCurrency: [Int: [String: Decimal]] {
        var totals: [Int: [String: Decimal]] = [:]
        for expense in expenses {
            let day = calendar.component(.day, from: expense.date)
            let (currency, amount) = classifyExpense(expense)
            totals[day, default: [:]][currency, default: .zero] += amount
        }
        return totals
    }

    private var dailyTotals: [Int: Decimal] {
        var totals: [Int: Decimal] = [:]
        for expense in expenses {
            let day = calendar.component(.day, from: expense.date)
            let amount = expense.convertedAmount(to: defaultCurrency) ?? expense.amount
            totals[day, default: .zero] += amount
        }
        return totals
    }

    private var averageDailyIncome: Decimal {
        let total = incomes.reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: defaultCurrency) ?? .zero) }
        guard daysInMonth > 0 else { return .zero }
        return total / Decimal(daysInMonth)
    }

    private var monthTotalsByCurrency: [String: Decimal] {
        var totals: [String: Decimal] = [:]
        for expense in expenses {
            let (currency, amount) = classifyExpense(expense)
            totals[currency, default: .zero] += amount
        }
        return totals
    }

    private var heatMapData: CalendarHeatMapData {
        CalendarHeatMapData(
            dailyTotals: dailyTotals,
            dailyTotalsByCurrency: dailyTotalsByCurrency,
            averageDailyIncome: averageDailyIncome
        )
    }

    // MARK: - Body

    var body: some View {
        if expenses.isEmpty {
            MonthEmptyStateView(
                title: "No Expenses This Month",
                systemImage: "calendar",
                filter: filter,
                syncService: syncService
            )
        } else {
            Form {
                Section {
                    ExpenseCalendarTotalHeader(
                        totals: monthTotalsByCurrency,
                        defaultCurrency: defaultCurrency
                    )
                    ExpenseCalendarGrid(
                        filter: filter,
                        defaultCurrency: defaultCurrency,
                        data: heatMapData
                    )
                }
            }
            .formStyle(.grouped)
        }
    }
}

#Preview {
    ExpenseCalendarView(filter: MonthFilter(year: 2026, month: 3), syncService: BankSyncService())
        .modelContainer(PreviewSampleData.container)
        .frame(width: 600, height: 500)
}
