import Foundation

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case budgetPlan = "Budget Plan"
    case expenses = "Expenses"
    case income = "Income"
    case comparison = "Comparison"
    case bankConnections = "Bank Connections"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .expenses: "arrow.up.circle"
        case .income: "arrow.down.circle"
        case .comparison: "chart.bar.xaxis"
        case .budgetPlan: "chart.bar"
        case .bankConnections: "link"
        }
    }
}
