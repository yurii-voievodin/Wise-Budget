import Foundation

struct CalendarHeatMapData {
    let dailyTotals: [Int: Decimal]
    let dailyTotalsByCurrency: [Int: [String: Decimal]]
    let averageDailyIncome: Decimal

    var maxDailyTotal: Decimal { dailyTotals.values.max() ?? .zero }
    var daysWithExpenses: Set<Int> { Set(dailyTotals.keys) }
}
