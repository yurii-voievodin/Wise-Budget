import SwiftUI

private struct IdentifiableDate: Identifiable {
    let date: Date
    var id: Date { date }
}

struct ExpenseCalendarGrid: View {
    let filter: MonthFilter
    let defaultCurrency: String
    let dailyTotalsByCurrency: [Int: [String: Decimal]]
    let dailyTotals: [Int: Decimal]
    let maxDailyTotal: Decimal
    let averageDailyIncome: Decimal
    let daysWithExpenses: Set<Int>

    @State private var selectedDate: IdentifiableDate?

    private var calendar: Calendar { Calendar.current }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: filter.startOfMonth)?.count ?? 30
    }

    private var firstWeekdayOffset: Int {
        let weekday = calendar.component(.weekday, from: filter.startOfMonth)
        return (weekday + 5) % 7
    }

    /// Weekday symbols reordered to start on Monday.
    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        return Array(symbols[1...]) + [symbols[0]]
    }

    private enum CalendarCell: Hashable, Identifiable {
        case header(Int)
        case empty(Int)
        case day(Int)

        var id: Self { self }
    }

    private var calendarCells: [CalendarCell] {
        var cells: [CalendarCell] = []
        for i in 0..<7 { cells.append(.header(i)) }
        for i in 0..<firstWeekdayOffset { cells.append(.empty(i)) }
        for d in 1...daysInMonth { cells.append(.day(d)) }
        return cells
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(calendarCells) { cell in
                cellView(for: cell)
            }
        }
    }

    @ViewBuilder
    private func cellView(for cell: CalendarCell) -> some View {
        switch cell {
        case .header(let index):
            Text(orderedWeekdaySymbols[index])
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary.opacity(0.7))
                .frame(maxWidth: .infinity)
        case .empty:
            Color.clear
                .frame(height: 64)
        case .day(let day):
            dayButton(day: day)
        }
    }

    private func dayButton(day: Int) -> some View {
        let isSelected = selectedDate.map { calendar.component(.day, from: $0.date) == day } ?? false
        return Button {
            if daysWithExpenses.contains(day) {
                let date = calendar.date(from: DateComponents(year: filter.year, month: filter.month, day: day)) ?? Date.now
                selectedDate = IdentifiableDate(date: date)
            } else {
                selectedDate = nil
            }
        } label: {
            dayCellView(day: day)
        }
        .buttonStyle(.plain)
        .overlay {
            if isSelected {
                Color.clear
                    .popover(item: $selectedDate) { item in
                        ExpenseDayDetailView(date: item.date)
                    }
            }
        }
    }

    private func dayCellView(day: Int) -> some View {
        let total = dailyTotals[day]
        let (bgColor, bgOpacity) = colorForDay(total: total)

        return ExpenseCalendarDayCellView(
            day: day,
            isToday: isToday(day: day),
            defaultCurrency: defaultCurrency,
            currencyTotals: dailyTotalsByCurrency[day] ?? [:],
            backgroundColor: bgColor,
            backgroundOpacity: bgOpacity
        )
    }

    private func isToday(day: Int) -> Bool {
        let today = calendar.dateComponents([.year, .month, .day], from: Date.now)
        return today.year == filter.year && today.month == filter.month && today.day == day
    }

    private static let heatMapMinOpacity = 0.10
    private static let heatMapOpacityRange = 0.25
    private static let noExpenseOpacity = 0.06

    private func colorForDay(total: Decimal?) -> (Color, Double) {
        guard let total, total > 0 else {
            return (.income, Self.noExpenseOpacity)
        }

        if averageDailyIncome > 0 && total <= averageDailyIncome {
            let ratio = NSDecimalNumber(decimal: total / averageDailyIncome).doubleValue
            let opacity = Self.heatMapMinOpacity + ratio * Self.heatMapOpacityRange
            return (.yellow, opacity)
        }

        guard maxDailyTotal > 0 else { return (.expense, Self.heatMapMinOpacity) }
        let ratio = NSDecimalNumber(decimal: total / maxDailyTotal).doubleValue
        let opacity = Self.heatMapMinOpacity + ratio * Self.heatMapOpacityRange
        return (.expense, opacity)
    }
}
