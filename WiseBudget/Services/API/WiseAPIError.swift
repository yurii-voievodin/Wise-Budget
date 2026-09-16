import Foundation

enum WiseAPIError: LocalizedError {
    case noToken
    case invalidToken
    case rateLimited
    case serverError(Int)
    case networkError(Error)
    case decodingError(Error)
    case noProfile

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "No Wise token found. Please connect your account."
        case .invalidToken:
            return "Invalid or expired token. Please reconnect your Wise account."
        case .rateLimited:
            return "Too many requests. Please wait a minute and try again."
        case .serverError(let code):
            return "Wise server error (HTTP \(code))."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse Wise response: \(error.localizedDescription)"
        case .noProfile:
            return "No Wise profile found for this token."
        }
    }
}
