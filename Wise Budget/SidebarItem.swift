import Foundation

enum SidebarItem: String, CaseIterable, Identifiable {
    case expenses = "Expenses"
    case income = "Income"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .expenses: "arrow.down.circle"
        case .income: "arrow.up.circle"
        }
    }
}
