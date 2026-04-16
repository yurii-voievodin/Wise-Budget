import Foundation
import SwiftData

nonisolated enum CachedInsightKind: String, Sendable {
    case monthSummary
    case trends6m
    case trendsYear
}

@Model
final nonisolated class CachedInsight {
    var kindRaw: String
    var scopeKey: String
    var currency: String
    var localeIdentifier: String
    var dataHash: String
    var content: String
    var createdAt: Date

    init(
        kind: CachedInsightKind,
        scopeKey: String,
        currency: String,
        localeIdentifier: String,
        dataHash: String,
        content: String,
        createdAt: Date = .now
    ) {
        self.kindRaw = kind.rawValue
        self.scopeKey = scopeKey
        self.currency = currency
        self.localeIdentifier = localeIdentifier
        self.dataHash = dataHash
        self.content = content
        self.createdAt = createdAt
    }
}
