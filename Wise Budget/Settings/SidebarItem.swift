import Foundation

enum SidebarItem: String, CaseIterable, Identifiable {
    case budgetPlan = "Budget Plan"
    case expenses = "Expenses"
    case income = "Income"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .expenses: "arrow.up.circle"
        case .income: "arrow.down.circle"
        case .budgetPlan: "chart.bar"
        }
    }
}
