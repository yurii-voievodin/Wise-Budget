import Foundation

struct CurrencyOption: Identifiable {
    let code: String
    let label: String
    var id: String { code }
}
