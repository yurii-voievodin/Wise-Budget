import Foundation

enum SidebarItem: String, CaseIterable, Identifiable {
    case budgetPlan = "Budget Plan"
    case expenses = "Expenses"
    case income = "Income"
    case settings = "Settings"
    case connections = "Connections"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .expenses: "arrow.down.circle"
        case .income: "arrow.up.circle"
        case .budgetPlan: "chart.bar"
        case .settings: "gearshape"
        case .connections: "link"
        }
    }
}
