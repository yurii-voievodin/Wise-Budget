import SwiftUI
import SwiftData

struct ExpenseCalendarView: View {
    @Query private var expenses: [Expense]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    @State private var selectedDay: Int?

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

    private var monthTotal: Decimal {
        expenses.reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: defaultCurrency) ?? $1.amount) }
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
        VStack(spacing: 4) {
            Text("Month Total")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(monthTotal, format: .number) \(defaultCurrency)")
                .font(.title2)
                .fontWeight(.semibold)
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
                    dayCellView(day: day)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if expensesForDay(day).isEmpty {
                                selectedDay = nil
                            } else {
                                selectedDay = selectedDay == day ? nil : day
                            }
                        }
                        .popover(isPresented: Binding(
                            get: { selectedDay == day },
                            set: { if !$0 { selectedDay = nil } }
                        )) {
                            ExpenseDayDetailView(
                                expenses: expensesForDay(day),
                                date: calendar.date(from: DateComponents(year: filter.year, month: filter.month, day: day)) ?? Date()
                            )
                        }
                }
            }
        }
    }

    private func dayCellView(day: Int) -> some View {
        let total = dailyTotals[day]
        let intensity = intensityForDay(total: total)

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

            if let total {
                Text("\(formattedAmount(total)) \(defaultCurrency)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.red.opacity(intensity))
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

    private func intensityForDay(total: Decimal?) -> Double {
        guard let total, total > 0, maxDailyTotal > 0 else { return 0 }
        let ratio = NSDecimalNumber(decimal: total / maxDailyTotal).doubleValue
        return Self.heatMapMinOpacity + ratio * Self.heatMapOpacityRange
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
