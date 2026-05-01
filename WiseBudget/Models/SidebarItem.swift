import Foundation

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case budgetPlan = "Budget Plan"
    case expenses = "Expenses"
    case income = "Income"
    case cashflow = "Cashflow"
    case bankConnections = "Bank Connections"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .expenses: "arrow.up.circle"
        case .income: "arrow.down.circle"
        case .cashflow: "arrow.up.arrow.down"
        case .budgetPlan: "chart.bar"
        case .bankConnections: "link"
        }
    }
}
