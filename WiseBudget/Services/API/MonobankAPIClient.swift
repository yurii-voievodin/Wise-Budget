import Foundation
import OSLog

private let logger = Logger(subsystem: "com.wisebudget", category: "MonobankAPI")

// MARK: - Response Models

struct MonobankClientInfo: Codable {
    let clientId: String?
    let name: String?
    let accounts: [MonobankAccount]
}

struct MonobankAccount: Codable, Identifiable {
    let id: String
    let currencyCode: Int
    let cashbackType: String?
    let balance: Int
    let type: String?
    let maskedPan: [String]?
    let iban: String?
}

nonisolated struct MonobankStatement: Codable, Identifiable {
    let id: String
    let time: Int
    let description: String
    let mcc: Int
    let originalMcc: Int?
    let amount: Int
    let operationAmount: Int
    let currencyCode: Int
    let balance: Int
    let hold: Bool
    let cashbackAmount: Int?
    let comment: String?
    let counterIban: String?
}

// MARK: - Error Types

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

// MARK: - API Client

final class MonobankAPIClient {
    private let baseURL = "https://api.monobank.ua"
    private let session: URLSession
    let token: String

    init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }

    func fetchClientInfo() async throws -> MonobankClientInfo {
        let url = URL(string: "\(baseURL)/personal/client-info")!
        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "X-Token")

        logger.debug("GET /personal/client-info")

        let (data, response) = try await performRequest(request)
        try validateResponse(response, for: "/personal/client-info")

        do {
            let clientInfo = try JSONDecoder().decode(MonobankClientInfo.self, from: data)
            logger.debug("client-info: name=\(clientInfo.name ?? "nil", privacy: .private), accounts=\(clientInfo.accounts.count)")
            return clientInfo
        } catch {
            logger.error("client-info decoding failed: \(error.localizedDescription)")
            throw MonobankAPIError.decodingError(error)
        }
    }

    func fetchStatements(accountId: String, from: Date, to: Date) async throws -> [MonobankStatement] {
        let fromTimestamp = Int(from.timeIntervalSince1970)
        let toTimestamp = Int(to.timeIntervalSince1970)
        let url = URL(string: "\(baseURL)/personal/statement/\(accountId)/\(fromTimestamp)/\(toTimestamp)")!

        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "X-Token")

        logger.debug("GET /personal/statement/\(accountId, privacy: .private)/\(fromTimestamp)/\(toTimestamp)")

        let (data, response) = try await performRequest(request)
        try validateResponse(response, for: "/personal/statement/\(accountId)")

        do {
            let statements = try JSONDecoder().decode([MonobankStatement].self, from: data)
            logger.debug("statement response: \(statements.count) transactions for account \(accountId, privacy: .private)")
            return statements
        } catch {
            logger.error("statement decoding failed: \(error.localizedDescription)")
            throw MonobankAPIError.decodingError(error)
        }
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        // Log request details
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "unknown"
        logger.debug("REQUEST: \(method) \(url, privacy: .private)")

        if let headers = request.allHTTPHeaderFields {
            let safeHeaders = headers.map { key, value in
                if key == "X-Token" {
                    return "\(key): ***"
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
            throw MonobankAPIError.networkError(error)
        }
    }

    private func validateResponse(_ response: URLResponse, for endpoint: String) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }

        logger.debug("\(endpoint, privacy: .private) -> HTTP \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401, 403:
            logger.error("\(endpoint, privacy: .private): invalid token (HTTP \(httpResponse.statusCode))")
            throw MonobankAPIError.invalidToken
        case 429:
            logger.warning("\(endpoint, privacy: .private): rate limited (HTTP 429)")
            throw MonobankAPIError.rateLimited
        default:
            logger.error("\(endpoint, privacy: .private): server error (HTTP \(httpResponse.statusCode))")
            throw MonobankAPIError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Currency Code Mapping (ISO 4217 numeric → string)

    nonisolated static let currencyCodeMap: [Int: String] = [
        980: "UAH",
        840: "USD",
        978: "EUR",
        826: "GBP",
        985: "PLN",
        203: "CZK",
        756: "CHF",
        392: "JPY",
        156: "CNY",
        949: "TRY",
        348: "HUF",
        946: "RON",
        975: "BGN",
        208: "DKK",
        752: "SEK",
        578: "NOK",
        036: "AUD",
        124: "CAD",
        554: "NZD",
        702: "SGD",
        344: "HKD",
        410: "KRW",
        376: "ILS",
        682: "SAR",
        784: "AED",
        764: "THB",
        484: "MXN",
        986: "BRL",
        710: "ZAR",
        356: "INR",
    ]

    nonisolated static func currencyString(for code: Int) -> String {
        currencyCodeMap[code] ?? "UAH"
    }
}
