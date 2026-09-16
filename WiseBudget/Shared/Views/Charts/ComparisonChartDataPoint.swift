import Foundation

struct ComparisonChartDataPoint: Identifiable {
    let id = UUID()
    let monthKey: MonthKey
    let categoryName: String
    let total: Double
}
