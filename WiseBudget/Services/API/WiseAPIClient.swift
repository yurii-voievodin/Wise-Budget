import Foundation
import OSLog

private let logger = Logger(subsystem: "com.wisebudget", category: "WiseAPI")

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

        logger.debug("GET /v1/profiles/\(profileId, privacy: .private)/activities (cursor=\(nextCursor ?? "nil", privacy: .private))")

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
        var seenCursors: Set<String> = []

        while true {
            try Task.checkCancellation()
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
            // Guard against a misbehaving server that returns the same cursor twice.
            guard seenCursors.insert(cursor).inserted else {
                logger.warning("duplicate cursor received, stopping pagination")
                break
            }
            nextCursor = cursor
        }

        logger.info("fetched \(allActivities.count) total activities for profile \(profileId, privacy: .private)")
        return allActivities
    }

    /// Fetches the exchange rate for a currency pair at a specific point in time.
    func fetchRate(source: String, target: String, time: Date) async throws -> WiseRate {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        var components = URLComponents(string: "\(baseURL)/v1/rates")!
        components.queryItems = [
            URLQueryItem(name: "source", value: source),
            URLQueryItem(name: "target", value: target),
            URLQueryItem(name: "time", value: isoFormatter.string(from: time)),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        logger.debug("GET /v1/rates?source=\(source)&target=\(target)")

        let (data, response) = try await performRequest(request)
        try validateResponse(response)

        do {
            let rates = try JSONDecoder().decode([WiseRate].self, from: data)
            guard let rate = rates.first else {
                throw WiseAPIError.decodingError(NSError(domain: "WiseAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "No rate returned"]))
            }
            return rate
        } catch let error as WiseAPIError {
            throw error
        } catch {
            logger.error("rate decoding failed: \(error.localizedDescription)")
            throw WiseAPIError.decodingError(error)
        }
    }

    // MARK: - Request Helpers

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var request = request
        // Pin response formatting to en-US so locale-formatted fields like
        // `primaryAmount` ("19.07 EUR") use a dot decimal separator regardless
        // of the device's preferred languages.
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        // Log request details
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "unknown"
        logger.debug("REQUEST: \(method) \(url, privacy: .private)")

        if let headers = request.allHTTPHeaderFields {
            let safeHeaders = headers.map { key, value in
                if key == "Authorization" {
                    return "\(key): Bearer ***"
                }
                return "\(key): \(value)"
            }.joined(separator: ", ")
            logger.debug("HEADERS: \(safeHeaders, privacy: .private)")
        }

        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            logger.debug("BODY: \(bodyString, privacy: .private)")
        }

        do {
            let (data, response) = try await session.data(for: request)

            // Log response details
            if let httpResponse = response as? HTTPURLResponse {
                logger.debug("RESPONSE: HTTP \(httpResponse.statusCode)")
            }
            if let rawBody = String(data: data, encoding: .utf8) {
                logger.debug("RESPONSE BODY: \(rawBody, privacy: .private)")
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
