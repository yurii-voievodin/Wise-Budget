import Foundation
import SwiftData
import Observation
import UserNotifications

struct SyncProgress: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case indeterminate
        case determinate(current: Int, total: Int)
    }

    let bank: String
    let detail: String
    let kind: Kind
}

@Observable
@MainActor
final class BankSyncService {
    private(set) var isSyncing = false
    private(set) var syncResultMessage: String?
    private(set) var progress: SyncProgress?

    private var lastSyncDate: Date?
    private var currentSyncTask: Task<Void, Never>?

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

        currentSyncTask = Task { @MainActor [weak self] in
            defer {
                self?.isSyncing = false
                self?.progress = nil
                self?.currentSyncTask = nil
            }

            let onProgress: @Sendable (SyncProgress) -> Void = { [weak self] p in
                Task { @MainActor in
                    guard let self, self.progress != p else { return }
                    self.progress = p
                }
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
                } catch is CancellationError {
                    return
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
                } catch is CancellationError {
                    return
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
            self?.syncResultMessage = message
            self?.lastSyncDate = Date.now
            await Self.postSyncNotification(message: message)
        }
    }

    /// Cancels any in-flight sync. Safe to call when no sync is running.
    func cancel() {
        currentSyncTask?.cancel()
    }

    func refreshConnectionStatus() {
        hasBankToken = Self.checkBankToken()
    }

    private static func checkBankToken() -> Bool {
        KeychainHelper.loadToken(service: KeychainHelper.monobankService) != nil
            || KeychainHelper.loadToken(service: KeychainHelper.wiseService) != nil
    }

    /// Auto-triggers a sync of the current month for app launch and activation.
    /// Throttled to at most once per hour; the timestamp is persisted so the
    /// throttle also holds across relaunches, not just within one session.
    func autoSyncIfNeeded(context: ModelContext) {
        refreshConnectionStatus()
        guard hasBankToken, !isSyncing else { return }

        let defaults = UserDefaults.standard
        let lastAttempt = defaults.double(forKey: Self.autoSyncLastAttemptKey)
        guard Date.now.timeIntervalSince1970 - lastAttempt >= Self.autoSyncInterval else { return }
        defaults.set(Date.now.timeIntervalSince1970, forKey: Self.autoSyncLastAttemptKey)

        let filter = MonthFilter.currentMonth()
        sync(context: context, from: filter.startOfMonth, to: filter.startOfNextMonth)
    }

    /// Request notification authorization. Call once at app launch.
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
