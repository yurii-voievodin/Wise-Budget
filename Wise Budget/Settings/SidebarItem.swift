import Foundation

enum SidebarItem: String, CaseIterable, Identifiable {
    case expenses = "Expenses"
    case income = "Income"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .expenses: "arrow.down.circle"
        case .income: "arrow.up.circle"
        case .settings: "gearshape"
        }
    }
}
