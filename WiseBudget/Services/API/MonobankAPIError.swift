import Foundation

enum MonobankAPIError: LocalizedError {
    case noToken
    case invalidToken
    case rateLimited
    case serverError(Int)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "No Monobank token found. Please connect your account."
        case .invalidToken:
            return "Invalid or expired token. Please reconnect your Monobank account."
        case .rateLimited:
            return "Too many requests. Please wait a minute and try again."
        case .serverError(let code):
            return "Monobank server error (HTTP \(code))."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse Monobank response: \(error.localizedDescription)"
        }
    }
}
