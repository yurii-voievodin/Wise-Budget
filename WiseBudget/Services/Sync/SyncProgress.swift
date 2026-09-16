import Foundation

struct SyncProgress: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case indeterminate
        case determinate(current: Int, total: Int)
    }

    let bank: String
    let detail: String
    let kind: Kind
}
