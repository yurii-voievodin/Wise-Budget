import Foundation

struct MonobankAccount: Codable, Identifiable {
    let id: String
    let currencyCode: Int
    let cashbackType: String?
    let balance: Int
    let type: String?
    let maskedPan: [String]?
    let iban: String?
}
