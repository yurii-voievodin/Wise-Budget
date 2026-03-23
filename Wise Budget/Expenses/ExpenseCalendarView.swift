import SwiftUI
import SwiftData

private struct IdentifiableDate: Identifiable {
    let date: Date
    var id: Date { date }
}

struct ExpenseCalendarView: View {
    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    @State private var selectedDate: IdentifiableDate?

    let filter: MonthFilter
    @Bindable var syncService: BankSyncService

    init(filter: MonthFilter, syncService: BankSyncService) {
        self.filter = filter
        self.syncService = syncService

        let startDate = filter.startOfMonth
        let endDate = filter.startOfNextMonth

        self._expenses = Query(
            filter: #Predicate<Expense> { expense in
                expense.date >= startDate && expense.date < endDate
            },
            sort: \.date
        )
        self._incomes = Query(
            filter: #Predicate<Income> { income in
                income.date >= startDate && income.date < endDate
            },
            sort: \.date
        )
    }

    // MARK: - Calendar Data

    private var calendar: Calendar { Calendar.current }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: filter.startOfMonth)?.count ?? 30
    }

    /// Weekday of the 1st day (0 = Sunday .. 6 = Saturday when using Gregorian firstWeekday=1)
    private var firstWeekdayOffset: Int {
        let weekday = calendar.component(.weekday, from: filter.startOfMonth)
        // Adjust so Monday=0 when firstWeekday is 1 (Sunday)
        return (weekday + 5) % 7 // Mon=0, Tue=1 ... Sun=6
    }

    /// Classifies an expense: if its currency or baseCurrency matches defaultCurrency,
    /// returns the amount in defaultCurrency; otherwise returns (originalCurrency, originalAmount).
    private func classifyExpense(_ expense: Expense) -> (currency: String, amount: Decimal) {
        if expense.currency == defaultCurrency {
            return (defaultCurrency, expense.amount)
        } else if expense.baseCurrency == defaultCurrency, let baseAmount = expense.baseCurrencyAmount {
            return (defaultCurrency, baseAmount)
        } else {
            return (expense.currency, expense.amount)
        }
    }

    /// Daily totals grouped by currency, with convertible expenses folded into defaultCurrency.
    private var dailyTotalsByCurrency: [Int: [String: Decimal]] {
        var totals: [Int: [String: Decimal]] = [:]
        for expense in expenses {
            let day = calendar.component(.day, from: expense.date)
            let (currency, amount) = classifyExpense(expense)
            totals[day, default: [:]][currency, default: .zero] += amount
        }
        return totals
    }

    /// Flat daily totals converted to default currency (for heat map intensity)
    private var dailyTotals: [Int: Decimal] {
        var totals: [Int: Decimal] = [:]
        for expense in expenses {
            let day = calendar.component(.day, from: expense.date)
            let amount = expense.convertedAmount(to: defaultCurrency) ?? expense.amount
            totals[day, default: .zero] += amount
        }
        return totals
    }

    private var maxDailyTotal: Decimal {
        dailyTotals.values.max() ?? .zero
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

    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    /// Reordered weekday symbols starting from Monday
    private var orderedWeekdaySymbols: [String] {
        // shortWeekdaySymbols: [Sun, Mon, Tue, Wed, Thu, Fri, Sat]
        let symbols = weekdaySymbols
        return Array(symbols[1...]) + [symbols[0]]
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
            ScrollView {
                VStack(spacing: 16) {
                    totalHeader
                    calendarGrid
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
    }

    // MARK: - Subviews

    private var totalHeader: some View {
        let totals = monthTotalsByCurrency
        let sortedTotals = totals.sorted { a, b in
            if a.key == defaultCurrency { return true }
            if b.key == defaultCurrency { return false }
            return a.key < b.key
        }

        return VStack(spacing: 4) {
            Text("Month Total")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(sortedTotals, id: \.key) { currency, total in
                Text("\(formattedAmount(total)) \(currency)")
                    .font(currency == defaultCurrency ? .title2 : .headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(currency == defaultCurrency ? .primary : .secondary)
            }
        }
    }

    /// Each cell in the calendar grid, with a stable unique ID.
    private enum CalendarCell: Hashable, Identifiable {
        case header(Int)    // index 0–6
        case empty(Int)     // offset index
        case day(Int)       // day number

        var id: Self { self }
    }

    private var calendarCells: [CalendarCell] {
        var cells: [CalendarCell] = []
        for i in 0..<7 { cells.append(.header(i)) }
        for i in 0..<firstWeekdayOffset { cells.append(.empty(i)) }
        for d in 1...daysInMonth { cells.append(.day(d)) }
        return cells
    }

    private var calendarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        let avgIncome = averageDailyIncome
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(calendarCells) { cell in
                switch cell {
                case .header(let index):
                    Text(orderedWeekdaySymbols[index])
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                case .empty:
                    Color.clear
                        .frame(height: 64)
                case .day(let day):
                    dayCellView(day: day, averageDailyIncome: avgIncome)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if expensesForDay(day).isEmpty {
                                selectedDate = nil
                            } else {
                                let date = calendar.date(from: DateComponents(year: filter.year, month: filter.month, day: day)) ?? Date()
                                selectedDate = IdentifiableDate(date: date)
                            }
                        }
                }
            }
        }
        .popover(item: $selectedDate) { item in
            ExpenseDayDetailView(date: item.date)
        }
    }

    private func dayCellView(day: Int, averageDailyIncome: Decimal) -> some View {
        let total = dailyTotals[day]
        let currencyTotals = dailyTotalsByCurrency[day] ?? [:]
        let (bgColor, bgOpacity) = colorForDay(total: total, averageDailyIncome: averageDailyIncome)

        return VStack(spacing: 2) {
            Text("\(day)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(isToday(day: day) ? .white : .primary)
                .frame(width: 22, height: 22)
                .background {
                    if isToday(day: day) {
                        Circle().fill(.blue)
                    }
                }

            if !currencyTotals.isEmpty {
                let sorted = currencyTotals.sorted { a, b in
                    if a.key == defaultCurrency { return true }
                    if b.key == defaultCurrency { return false }
                    return a.key < b.key
                }
                ForEach(sorted, id: \.key) { currency, amount in
                    Text("\(formattedAmount(amount)) \(currency)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 64)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(bgColor.opacity(bgOpacity))
        )
    }

    private func expensesForDay(_ day: Int) -> [Expense] {
        expenses.filter { calendar.component(.day, from: $0.date) == day }
    }

    // MARK: - Helpers

    private func isToday(day: Int) -> Bool {
        let today = calendar.dateComponents([.year, .month, .day], from: Date())
        return today.year == filter.year && today.month == filter.month && today.day == day
    }

    private static let heatMapMinOpacity = 0.05
    private static let heatMapOpacityRange = 0.25
    private static let noExpenseOpacity = 0.06

    private func colorForDay(total: Decimal?, averageDailyIncome: Decimal) -> (Color, Double) {
        guard let total, total > 0 else {
            return (.green, Self.noExpenseOpacity)
        }

        if averageDailyIncome > 0 && total <= averageDailyIncome {
            let ratio = NSDecimalNumber(decimal: total / averageDailyIncome).doubleValue
            let opacity = Self.heatMapMinOpacity + ratio * Self.heatMapOpacityRange
            return (.yellow, opacity)
        }

        guard maxDailyTotal > 0 else { return (.red, Self.heatMapMinOpacity) }
        let ratio = NSDecimalNumber(decimal: total / maxDailyTotal).doubleValue
        let opacity = Self.heatMapMinOpacity + ratio * Self.heatMapOpacityRange
        return (.red, opacity)
    }

    private static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private func formattedAmount(_ value: Decimal) -> String {
        Self.amountFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }
}
