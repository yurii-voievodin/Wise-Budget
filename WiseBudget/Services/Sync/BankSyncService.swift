import Foundation
import SwiftData
import Observation
import UserNotifications

@Observable
@MainActor
final class BankSyncService {
    private(set) var isSyncing = false
    private(set) var progress: SyncProgress?

    private var lastSyncDate: Date?

    private static let autoSyncLastAttemptKey = "autoSyncLastAttemptDate"
    private static let autoSyncInterval: TimeInterval = 3600

    private(set) var hasBankToken = BankSyncService.checkBankToken()

    /// Whether the 1-minute cooldown after a sync is still active.
    var isSyncCooldown: Bool {
        guard let lastSync = lastSyncDate else { return false }
        return Date.now.timeIntervalSince(lastSync) < 60
    }

    /// Syncs all connected banks for the given month (startOfMonth ..< endOfMonth).
    func sync(context: ModelContext, from startOfMonth: Date, to endOfMonth: Date) {
        guard !isSyncing else { return }
        isSyncing = true

        Task {
            defer {
                isSyncing = false
                progress = nil
            }

            let onProgress: @MainActor (SyncProgress) -> Void = { p in
                guard self.progress != p else { return }
                self.progress = p
            }

            var totalExpenses = 0
            var totalIncomes = 0
            var totalDuplicates = 0
            var errors: [String] = []

            let syncFrom = startOfMonth.timeIntervalSince1970
            let syncTo = endOfMonth.timeIntervalSince1970

            if KeychainHelper.loadToken(service: KeychainHelper.monobankService) != nil {
                do {
                    let result = try await MonobankSyncService.sync(
                        context: context,
                        fromTimestamp: syncFrom,
                        toTimestamp: syncTo,
                        onProgress: onProgress
                    )
                    totalExpenses += result.expensesImported
                    totalIncomes += result.incomesImported
                    totalDuplicates += result.duplicatesSkipped
                    UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "monobankLastSync")
                } catch {
                    errors.append("Monobank: \(error.localizedDescription)")
                }
            }

            if KeychainHelper.loadToken(service: KeychainHelper.wiseService) != nil {
                do {
                    let result = try await WiseSyncService.sync(
                        context: context,
                        fromTimestamp: syncFrom,
                        toTimestamp: syncTo,
                        onProgress: onProgress
                    )
                    totalExpenses += result.expensesImported
                    totalIncomes += result.incomesImported
                    totalDuplicates += result.duplicatesSkipped
                    UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "wiseLastSync")
                } catch {
                    errors.append("Wise: \(error.localizedDescription)")
                }
            }

            let message: String
            if !errors.isEmpty {
                message = errors.joined(separator: "\n")
            } else if totalExpenses == 0 && totalIncomes == 0 {
                message = "Already up to date. \(totalDuplicates) duplicates skipped."
            } else {
                message = "\(totalExpenses) expenses, \(totalIncomes) incomes imported. \(totalDuplicates) duplicates skipped."
            }
            lastSyncDate = Date.now
            await Self.postSyncNotification(message: message)
        }
    }

    func refreshConnectionStatus() {
        hasBankToken = Self.checkBankToken()
    }

    private static func checkBankToken() -> Bool {
        KeychainHelper.loadToken(service: KeychainHelper.monobankService) != nil
            || KeychainHelper.loadToken(service: KeychainHelper.wiseService) != nil
    }

    func autoSyncIfNeeded(context: ModelContext) {
        guard !isSyncing else { return }

        let defaults = UserDefaults.standard
        let lastAttempt = defaults.double(forKey: Self.autoSyncLastAttemptKey)
        guard Date.now.timeIntervalSince1970 - lastAttempt >= Self.autoSyncInterval else { return }

        refreshConnectionStatus()
        guard hasBankToken else { return }
        defaults.set(Date.now.timeIntervalSince1970, forKey: Self.autoSyncLastAttemptKey)

        let filter = MonthFilter.currentMonth()
        sync(context: context, from: filter.startOfMonth, to: filter.startOfNextMonth)
    }

    static func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    private static func postSyncNotification(message: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Bank Sync"
        content.body = message
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
