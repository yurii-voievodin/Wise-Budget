import Foundation

enum CashflowTimeRange: String, CaseIterable, Identifiable {
    case sixMonths = "6 Months"
    case year = "Year"
    case lifetime = "Lifetime"

    var id: Self { self }

    static let storageKey = "cashflow.timeRange"
}
