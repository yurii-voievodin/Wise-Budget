import Foundation
import SwiftData
import Observation

@Observable
final class BankSyncService {
    private(set) var isSyncing = false
    private(set) var currentBank: Bank?

    private var lastSyncDate: Date?

    private(set) var hasBankToken = BankSyncService.checkBankToken()

    /// Whether the 1-minute cooldown after a sync is still active.
    var isSyncCooldown: Bool {
        guard let lastSync = lastSyncDate else { return false }
        return Date.now.timeIntervalSince(lastSync) < 60
    }

    /// Syncs all connected banks for the given month (startOfMonth ..< endOfMonth).
    func sync(context: ModelContext, from startOfMonth: Date, to endOfMonth: Date) {
        guard !isSyncing, hasBankToken else { return }
        isSyncing = true

        Task {
            await performSync(context: context, from: startOfMonth, to: endOfMonth)
        }
    }

    private func performSync(context: ModelContext, from startOfMonth: Date, to endOfMonth: Date) async {
        defer {
            isSyncing = false
            currentBank = nil
        }

        let syncFrom = startOfMonth.timeIntervalSince1970
        let syncTo = endOfMonth.timeIntervalSince1970

        let banks = Bank.allCases.filter { KeychainHelper.loadToken(service: $0.keychainService) != nil }

        var totals = ImportResult()
        var errors: [String] = []
        for bank in banks {
            currentBank = bank
            do {
                let result = try await bank.syncService.sync(context: context, fromTimestamp: syncFrom, toTimestamp: syncTo)
                totals.expensesImported += result.expensesImported
                totals.incomesImported += result.incomesImported
                totals.duplicatesSkipped += result.duplicatesSkipped
                UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: bank.lastSyncKey)
            } catch {
                errors.append("\(bank.displayName): \(error.localizedDescription)")
            }
        }

        lastSyncDate = Date.now
        await SyncNotifier.notify(totals: totals, errors: errors)
    }

    func refreshConnectionStatus() {
        hasBankToken = Self.checkBankToken()
    }

    private static func checkBankToken() -> Bool {
        Bank.allCases.contains { KeychainHelper.loadToken(service: $0.keychainService) != nil }
    }

    func autoSyncIfNeeded(context: ModelContext) {
        guard !isSyncing, AutoSyncScheduler.isDue() else { return }

        refreshConnectionStatus()
        guard hasBankToken else { return }
        AutoSyncScheduler.recordAttempt()

        let filter = MonthFilter.currentMonth()
        sync(context: context, from: filter.startOfMonth, to: filter.startOfNextMonth)
    }
}
