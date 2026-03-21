import Foundation
import OSLog

private let logger = Logger(subsystem: "com.wisebudget", category: "WiseAPI")

// MARK: - Response Models

struct WiseProfile: Codable, Identifiable {
    let id: Int
    let type: String
    let fullName: String
}

struct WiseActivitiesResponse: Codable {
    let activities: [WiseActivity]
    let cursor: String?
}

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

struct WiseActivityResource: Codable {
    let type: String?
    let id: String?
}

// MARK: - Error Types

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

// MARK: - API Client

final class WiseAPIClient {
    private let baseURL = "https://api.wise.com"
    private let session: URLSession
    let token: String

    init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }

    func fetchProfiles() async throws -> [WiseProfile] {
        let url = URL(string: "\(baseURL)/v2/profiles")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await performRequest(request)
        try validateResponse(response)

        do {
            let profiles = try JSONDecoder().decode([WiseProfile].self, from: data)
            logger.debug("profiles: \(profiles.count) found")
            return profiles
        } catch {
            logger.error("profiles decoding failed: \(error.localizedDescription)")
            throw WiseAPIError.decodingError(error)
        }
    }

    /// Fetches activities for a profile. Returns all transaction types (card payments, transfers, conversions, etc.).
    /// No SCA required.
    func fetchActivities(profileId: Int, since: Date, until: Date, status: String = "COMPLETED", size: Int = 100, nextCursor: String? = nil) async throws -> WiseActivitiesResponse {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var components = URLComponents(string: "\(baseURL)/v1/profiles/\(profileId)/activities")!
        var queryItems = [
            URLQueryItem(name: "since", value: isoFormatter.string(from: since)),
            URLQueryItem(name: "until", value: isoFormatter.string(from: until)),
            URLQueryItem(name: "status", value: status),
            URLQueryItem(name: "size", value: String(size)),
        ]
        if let cursor = nextCursor {
            queryItems.append(URLQueryItem(name: "nextCursor", value: cursor))
        }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        logger.debug("GET /v1/profiles/\(profileId)/activities (cursor=\(nextCursor ?? "nil"))")

        let (data, response) = try await performRequest(request)
        try validateResponse(response)

        do {
            let activitiesResponse = try JSONDecoder().decode(WiseActivitiesResponse.self, from: data)
            return activitiesResponse
        } catch {
            logger.error("activities decoding failed: \(error.localizedDescription)")
            throw WiseAPIError.decodingError(error)
        }
    }

    /// Fetches ALL completed activities for a profile in a date range, handling pagination automatically.
    func fetchAllActivities(profileId: Int, since: Date, until: Date) async throws -> [WiseActivity] {
        var allActivities: [WiseActivity] = []
        var nextCursor: String? = nil

        while true {
            let response = try await fetchActivities(
                profileId: profileId,
                since: since,
                until: until,
                nextCursor: nextCursor
            )
            allActivities.append(contentsOf: response.activities)

            guard let cursor = response.cursor else {
                break // No more pages
            }
            nextCursor = cursor
        }

        logger.info("fetched \(allActivities.count) total activities for profile \(profileId)")
        return allActivities
    }

    // MARK: - Request Helpers

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        // Log request details
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "unknown"
        logger.debug("REQUEST: \(method) \(url)")

        if let headers = request.allHTTPHeaderFields {
            let safeHeaders = headers.map { key, value in
                if key == "Authorization" {
                    return "\(key): Bearer ***"
                }
                return "\(key): \(value)"
            }.joined(separator: ", ")
            logger.debug("HEADERS: \(safeHeaders)")
        }

        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            logger.debug("BODY: \(bodyString)")
        }

        do {
            let (data, response) = try await session.data(for: request)

            // Log response details
            if let httpResponse = response as? HTTPURLResponse {
                logger.debug("RESPONSE: HTTP \(httpResponse.statusCode)")
            }
            if let rawBody = String(data: data, encoding: .utf8) {
                logger.debug("RESPONSE BODY: \(rawBody)")
            }

            return (data, response)
        } catch {
            logger.error("network request failed: \(error.localizedDescription)")
            throw WiseAPIError.networkError(error)
        }
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw WiseAPIError.invalidToken
        case 403:
            throw WiseAPIError.invalidToken
        case 429:
            throw WiseAPIError.rateLimited
        default:
            throw WiseAPIError.serverError(httpResponse.statusCode)
        }
    }
}
