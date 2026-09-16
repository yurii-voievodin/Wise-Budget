import Foundation
import SwiftData

struct DashboardRecentTransaction: Identifiable {
    let id: PersistentIdentifier
    let descriptionText: String?
    let categoryName: String?
    let categoryIcon: String?
    let item: CurrencyConvertible
    let isExpense: Bool
    let date: Date
}
