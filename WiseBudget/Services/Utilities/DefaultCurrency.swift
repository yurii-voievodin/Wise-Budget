import Foundation

/// Centralizes lookup of the user's default currency. The chosen value lives
/// in `UserDefaults` under `userDefaultsKey`; when no preference is stored we
/// fall back to the system locale's currency, then to `"USD"`.
enum DefaultCurrency {
    static let userDefaultsKey = "defaultCurrency"

    /// Default to use when no preference is stored. Use this as the default
    /// value for `@AppStorage(DefaultCurrency.userDefaultsKey)`.
    static var localeFallback: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    /// Reads the stored default currency from `UserDefaults`. Use this from
    /// non-SwiftUI contexts (service code, form-sheet initializers, preview
    /// helpers) where `@AppStorage` isn't available.
    static func resolve() -> String {
        UserDefaults.standard.string(forKey: userDefaultsKey) ?? localeFallback
    }
}
