import SwiftUI
import SwiftData

struct BudgetStatisticsView: View {
    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    let filter: MonthFilter

    init(filter: MonthFilter) {
        self.filter = filter

        let startDate = filter.startOfMonth
        let endDate = filter.startOfNextMonth

        self._expenses = Query(
            filter: #Predicate<Expense> { expense in
                expense.date >= startDate && expense.date < endDate
            }
        )

        self._incomes = Query(
            filter: #Predicate<Income> { income in
                income.date >= startDate && income.date < endDate
            }
        )
    }

    // MARK: - Computed Statistics

    private var totalExpenses: Decimal {
        expenses.reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: defaultCurrency) ?? .zero) }
    }

    private var totalIncome: Decimal {
        incomes.reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: defaultCurrency) ?? .zero) }
    }

    private var monthlyBalance: Decimal {
        totalIncome - totalExpenses
    }

    private var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: filter.startOfMonth)?.count ?? 30
    }

    private var expenseDailyAverage: Decimal {
        guard daysInMonth > 0 else { return .zero }
        return totalExpenses / Decimal(daysInMonth)
    }

    private var incomeDailyAverage: Decimal {
        guard daysInMonth > 0 else { return .zero }
        return totalIncome / Decimal(daysInMonth)
    }

    private var dailyBalance: Decimal {
        incomeDailyAverage - expenseDailyAverage
    }

    // MARK: - Body

    var body: some View {
        if expenses.isEmpty && incomes.isEmpty {
            emptyState
        } else {
            Form {
                monthTotalsSection
                dailyAveragesSection
            }
            .formStyle(.grouped)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Data This Month")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Add expenses or income to see statistics.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var monthTotalsSection: some View {
        Section("Month Totals") {
            LabeledContent("Income") {
                Text("\(totalIncome, format: .number.precision(.fractionLength(2))) \(defaultCurrency)")
                    .monospacedDigit()
                    .foregroundStyle(.green)
            }
            LabeledContent("Expenses") {
                Text("\(totalExpenses, format: .number.precision(.fractionLength(2))) \(defaultCurrency)")
                    .monospacedDigit()
                    .foregroundStyle(.red)
            }
            LabeledContent("Balance") {
                Text("\(monthlyBalance >= .zero ? "+" : "")\(monthlyBalance, format: .number.precision(.fractionLength(2))) \(defaultCurrency)")
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(monthlyBalance >= .zero ? .green : .red)
            }
        }
    }

    private var dailyAveragesSection: some View {
        Section("Daily Averages") {
            LabeledContent("Income") {
                Text("\(incomeDailyAverage, format: .number.precision(.fractionLength(2))) \(defaultCurrency)")
                    .monospacedDigit()
                    .foregroundStyle(.green)
            }
            LabeledContent("Expenses") {
                Text("\(expenseDailyAverage, format: .number.precision(.fractionLength(2))) \(defaultCurrency)")
                    .monospacedDigit()
                    .foregroundStyle(.red)
            }
            LabeledContent("Balance") {
                Text("\(dailyBalance >= .zero ? "+" : "")\(dailyBalance, format: .number.precision(.fractionLength(2))) \(defaultCurrency)")
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(dailyBalance >= .zero ? .green : .red)
            }
        }
    }
}
