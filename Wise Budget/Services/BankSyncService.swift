import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class BankSyncService {
    private(set) var isSyncing = false
    private(set) var syncResultMessage: String?
    var showSyncAlert = false

    private var lastSyncDate: Date?

    /// Whether any bank token (Monobank or Wise) is stored in the Keychain.
    var hasBankToken: Bool {
        KeychainHelper.loadToken(service: KeychainHelper.monobankService) != nil
        || KeychainHelper.loadToken(service: KeychainHelper.wiseService) != nil
    }

    /// Whether the 1-minute cooldown after a sync is still active.
    var isSyncCooldown: Bool {
        guard let lastSync = lastSyncDate else { return false }
        return Date().timeIntervalSince(lastSync) < 60
    }

    /// Syncs all connected banks starting from the given date.
    func sync(context: ModelContext, from startOfMonth: Date) {
        guard !isSyncing else { return }
        isSyncing = true

        Task {
            var totalExpenses = 0
            var totalIncomes = 0
            var totalDuplicates = 0
            var errors: [String] = []

            let syncFrom = startOfMonth.timeIntervalSince1970

            if KeychainHelper.loadToken(service: KeychainHelper.monobankService) != nil {
                do {
                    let result = try await MonobankSyncService.sync(
                        context: context,
                        lastSyncTimestamp: syncFrom
                    )
                    totalExpenses += result.expensesImported
                    totalIncomes += result.incomesImported
                    totalDuplicates += result.duplicatesSkipped
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "monobankLastSync")
                } catch {
                    errors.append("Monobank: \(error.localizedDescription)")
                }
            }

            if KeychainHelper.loadToken(service: KeychainHelper.wiseService) != nil {
                do {
                    let result = try await WiseSyncService.sync(
                        context: context,
                        lastSyncTimestamp: syncFrom
                    )
                    totalExpenses += result.expensesImported
                    totalIncomes += result.incomesImported
                    totalDuplicates += result.duplicatesSkipped
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "wiseLastSync")
                } catch {
                    errors.append("Wise: \(error.localizedDescription)")
                }
            }

            isSyncing = false
            lastSyncDate = Date()
            if !errors.isEmpty {
                syncResultMessage = errors.joined(separator: "\n")
            } else if totalExpenses == 0 && totalIncomes == 0 {
                syncResultMessage = "Already up to date. \(totalDuplicates) duplicates skipped."
            } else {
                syncResultMessage = "\(totalExpenses) expenses, \(totalIncomes) incomes imported. \(totalDuplicates) duplicates skipped."
            }
            showSyncAlert = true
        }
    }
}
