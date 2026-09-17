import Foundation
import SwiftData

protocol BankSyncing {
    static func sync(context: ModelContext, fromTimestamp: Double, toTimestamp: Double) async throws -> ImportResult
}

enum Bank: CaseIterable {
    case wise
    case monobank

    var displayName: String {
        switch self {
        case .wise: return "Wise"
        case .monobank: return "Monobank"
        }
    }

    var keychainService: String {
        switch self {
        case .wise: return KeychainHelper.wiseService
        case .monobank: return KeychainHelper.monobankService
        }
    }

    var lastSyncKey: String {
        switch self {
        case .wise: return "wiseLastSync"
        case .monobank: return "monobankLastSync"
        }
    }

    var syncService: BankSyncing.Type {
        switch self {
        case .wise: return WiseSyncService.self
        case .monobank: return MonobankSyncService.self
        }
    }
}
