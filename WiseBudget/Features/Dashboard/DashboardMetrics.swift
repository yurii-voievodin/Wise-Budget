import Foundation

struct DashboardMetrics {
    let totalIncome: Decimal
    let totalExpenses: Decimal
    let daysInMonth: Int
    let daysElapsedInMonth: Int
    let isCurrentMonth: Bool

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
        return max(daysInMonth - daysElapsedInMonth + 1, 0)
    }

    var dailyAllowance: Decimal {
        guard daysRemainingInMonth > 0 else { return .zero }
        return balance / Decimal(daysRemainingInMonth)
    }

    private var currentSpendPace: Decimal {
        guard daysElapsedInMonth > 0 else { return .zero }
        return totalExpenses / Decimal(daysElapsedInMonth)
    }

    var shouldShowBudgetPacing: Bool {
        isCurrentMonth
            && balance > .zero
            && daysRemainingInMonth > 0
            && currentSpendPace > dailyAllowance
    }
}
