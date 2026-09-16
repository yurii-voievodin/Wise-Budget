import Foundation

struct MonobankClientInfo: Codable {
    let clientId: String?
    let name: String?
    let accounts: [MonobankAccount]
}
