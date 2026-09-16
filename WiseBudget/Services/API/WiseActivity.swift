import Foundation

struct WiseActivity: Codable, Identifiable {
    let id: String
    let type: String
    let resource: WiseActivityResource?
    let title: String?
    let description: String?
    let primaryAmount: String? // Formatted, e.g. "10.00 EUR" or "-10.00 EUR"
    let secondaryAmount: String?
    let status: String?
    let createdOn: String? // ISO 8601
    let updatedOn: String?
}
