import Foundation
import SwiftData
import Observation

struct BankSyncFailure: Identifiable {
    let id = UUID()
    let bank: Bank
    let message: String
}

@Observable
final class BankSyncService {
    // MARK: - Public state

    private(set) var isSyncing = false
    private(set) var currentBank: Bank?
    private(set) var lastSyncErrors: [BankSyncFailure] = []
    private(set) var hasBankToken = BankSyncService.checkBankToken()

    // MARK: - Private state

    private var lastSyncDate: Date?

    // MARK: - Public API

    var isSyncCooldown: Bool {
        guard let lastSync = lastSyncDate else { return false }
        return Date.now.timeIntervalSince(lastSync) < 60
    }

    func sync(context: ModelContext, from startOfMonth: Date, to endOfMonth: Date, fullResync: Bool = false) {
        guard !isSyncing, hasBankToken else { return }
        isSyncing = true

        Task {
            await performSync(context: context, from: startOfMonth, to: endOfMonth, fullResync: fullResync)
        }
    }

    func refreshConnectionStatus() {
        hasBankToken = Self.checkBankToken()
    }

    func autoSyncIfNeeded(context: ModelContext) {
        guard !isSyncing, AutoSyncScheduler.isDue() else { return }

        refreshConnectionStatus()
        guard hasBankToken else { return }
        AutoSyncScheduler.recordAttempt()

        let filter = MonthFilter.currentMonth()
        sync(context: context, from: filter.startOfMonth, to: filter.startOfNextMonth)
    }

    // MARK: - Private

    private static let incrementalOverlap: TimeInterval = 3 * 24 * 60 * 60

    private func performSync(context: ModelContext, from startOfMonth: Date, to endOfMonth: Date, fullResync: Bool) async {
        defer {
            isSyncing = false
            currentBank = nil
        }

        let syncTo = endOfMonth.timeIntervalSince1970

        let banks = Bank.allCases.filter { KeychainHelper.loadToken(service: $0.keychainService) != nil }

        var totals = ImportResult()
        var errors: [BankSyncFailure] = []
        for bank in banks {
            currentBank = bank
            let syncFrom = fullResync
                ? startOfMonth.timeIntervalSince1970
                : Self.incrementalStart(for: bank, requestedStart: startOfMonth).timeIntervalSince1970
            do {
                let result = try await bank.syncService.sync(context: context, fromTimestamp: syncFrom, toTimestamp: syncTo)
                totals.expensesImported += result.expensesImported
                totals.incomesImported += result.incomesImported
                totals.duplicatesSkipped += result.duplicatesSkipped
                let now = Date.now
                UserDefaults.standard.set(now.timeIntervalSince1970, forKey: bank.lastSyncKey)
                UserDefaults.standard.set(min(endOfMonth, now).timeIntervalSince1970, forKey: bank.syncedUpToKey)
            } catch {
                errors.append(BankSyncFailure(bank: bank, message: error.localizedDescription))
            }
        }

        lastSyncDate = Date.now
        lastSyncErrors = errors
        await SyncNotifier.notify(totals: totals)
    }

    static func incrementalStart(for bank: Bank, requestedStart: Date) -> Date {
        let stored = UserDefaults.standard.double(forKey: bank.syncedUpToKey)
        guard stored > 0 else { return requestedStart }

        let syncedUpTo = Date(timeIntervalSince1970: stored)
        return max(requestedStart, syncedUpTo.addingTimeInterval(-incrementalOverlap))
    }

    private static func checkBankToken() -> Bool {
        Bank.allCases.contains { KeychainHelper.loadToken(service: $0.keychainService) != nil }
    }
}
