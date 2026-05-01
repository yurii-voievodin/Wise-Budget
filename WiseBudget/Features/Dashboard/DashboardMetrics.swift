import Foundation

struct DashboardMetrics {
    let totalIncome: Decimal
    let totalExpenses: Decimal
    let daysInMonth: Int
    let isCurrentMonth: Bool
    private let daysElapsedIfCurrent: Int

    init(monthFilter: MonthFilter, totalIncome: Decimal, totalExpenses: Decimal, now: Date = .now) {
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.year, .month, .day], from: now)
        self.totalIncome = totalIncome
        self.totalExpenses = totalExpenses
        self.daysInMonth = calendar.range(of: .day, in: .month, for: monthFilter.startOfMonth)?.count ?? 30
        self.isCurrentMonth = monthFilter.year == nowComponents.year && monthFilter.month == nowComponents.month
        self.daysElapsedIfCurrent = nowComponents.day ?? 0
    }

    var balance: Decimal { totalIncome - totalExpenses }

    var incomeDailyAverage: Decimal {
        guard daysInMonth > 0 else { return .zero }
        return totalIncome / Decimal(daysInMonth)
    }

    var expenseDailyAverage: Decimal {
        guard daysInMonth > 0 else { return .zero }
        return totalExpenses / Decimal(daysInMonth)
    }

    var dailyBalance: Decimal { incomeDailyAverage - expenseDailyAverage }

    var daysRemainingInMonth: Int {
        guard isCurrentMonth else { return 0 }
        return max(daysInMonth - daysElapsedIfCurrent + 1, 0)
    }

    var dailyAllowance: Decimal {
        guard daysRemainingInMonth > 0 else { return .zero }
        return balance / Decimal(daysRemainingInMonth)
    }

    private var currentSpendPace: Decimal {
        guard isCurrentMonth, daysElapsedIfCurrent > 0 else { return .zero }
        return totalExpenses / Decimal(daysElapsedIfCurrent)
    }

    var shouldShowBudgetPacing: Bool {
        isCurrentMonth
            && balance > .zero
            && daysRemainingInMonth > 0
            && currentSpendPace > dailyAllowance
    }
}
