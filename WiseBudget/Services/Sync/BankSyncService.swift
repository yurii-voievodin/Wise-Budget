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
final class BankSyncService {
    private(set) var isSyncing = false
    private(set) var syncResultMessage: String?
    private(set) var progress: SyncProgress?

    private var lastSyncDate: Date?
    private var currentSyncTask: Task<Void, Never>?

    /// Whether any bank token (Monobank or Wise) is stored in the Keychain.
    var hasBankToken: Bool {
        KeychainHelper.loadToken(service: KeychainHelper.monobankService) != nil
        || KeychainHelper.loadToken(service: KeychainHelper.wiseService) != nil
    }

    /// Whether the 1-minute cooldown after a sync is still active.
    var isSyncCooldown: Bool {
        guard let lastSync = lastSyncDate else { return false }
        return Date.now.timeIntervalSince(lastSync) < 60
    }

    /// Syncs all connected banks for the given month (startOfMonth ..< endOfMonth).
    func sync(context: ModelContext, from startOfMonth: Date, to endOfMonth: Date) {
        guard !isSyncing else { return }
        isSyncing = true

        currentSyncTask = Task { [weak self] in
            defer {
                self?.isSyncing = false
                self?.progress = nil
                self?.lastSyncDate = Date.now
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
            await Self.postSyncNotification(message: message)
        }
    }

    /// Cancels any in-flight sync. Safe to call when no sync is running.
    func cancel() {
        currentSyncTask?.cancel()
    }

    /// Syncs Monobank only, from the last successful sync (or start of the current month) up to now.
    /// Returns the import result or throws if the sync fails.
    @discardableResult
    static func syncMonobankIncremental(context: ModelContext) async throws -> ImportResult {
        let lastSync = UserDefaults.standard.double(forKey: "monobankLastSync")
        let fromTs: Double
        if lastSync > 0 {
            fromTs = lastSync
        } else {
            let comps = Calendar.current.dateComponents([.year, .month], from: Date.now)
            fromTs = (Calendar.current.date(from: comps) ?? Date.now).timeIntervalSince1970
        }
        let result = try await MonobankSyncService.sync(
            context: context,
            fromTimestamp: fromTs,
            toTimestamp: Date.now.timeIntervalSince1970
        )
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "monobankLastSync")
        return result
    }

    /// Syncs Wise only, from the last successful sync (or start of the current month) up to now.
    /// Returns the import result or throws if the sync fails.
    @discardableResult
    static func syncWiseIncremental(context: ModelContext) async throws -> ImportResult {
        let lastSync = UserDefaults.standard.double(forKey: "wiseLastSync")
        let fromTs: Double
        if lastSync > 0 {
            fromTs = lastSync
        } else {
            let comps = Calendar.current.dateComponents([.year, .month], from: Date.now)
            fromTs = (Calendar.current.date(from: comps) ?? Date.now).timeIntervalSince1970
        }
        let result = try await WiseSyncService.sync(
            context: context,
            fromTimestamp: fromTs,
            toTimestamp: Date.now.timeIntervalSince1970
        )
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "wiseLastSync")
        return result
    }

    /// Posts a local notification summarizing a single-bank sync. Shared formatting.
    static func formatResultMessage(_ result: ImportResult) -> String {
        if result.expensesImported == 0 && result.incomesImported == 0 {
            return "Already up to date. \(result.duplicatesSkipped) duplicates skipped."
        }
        return "\(result.expensesImported) expenses, \(result.incomesImported) incomes imported. \(result.duplicatesSkipped) duplicates skipped."
    }

    static func postNotification(title: String, message: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
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
