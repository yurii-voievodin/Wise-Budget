import Foundation
import SwiftData
import Observation
import UserNotifications

@Observable
final class BankSyncService {
    private(set) var isSyncing = false
    private(set) var currentBank: Bank?

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
                let result = try await run(bank, context: context, syncFrom: syncFrom, syncTo: syncTo)
                totals.expensesImported += result.expensesImported
                totals.incomesImported += result.incomesImported
                totals.duplicatesSkipped += result.duplicatesSkipped
                UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: bank.lastSyncKey)
            } catch {
                errors.append("\(bank.displayName): \(error.localizedDescription)")
            }
        }

        lastSyncDate = Date.now
        await Self.postSyncNotification(message: Self.summaryMessage(totals: totals, errors: errors))
    }

    private func run(_ bank: Bank, context: ModelContext, syncFrom: Double, syncTo: Double) async throws -> ImportResult {
        switch bank {
        case .monobank:
            return try await MonobankSyncService.sync(context: context, fromTimestamp: syncFrom, toTimestamp: syncTo)
        case .wise:
            return try await WiseSyncService.sync(context: context, fromTimestamp: syncFrom, toTimestamp: syncTo)
        }
    }

    private static func summaryMessage(totals: ImportResult, errors: [String]) -> String {
        if !errors.isEmpty {
            return errors.joined(separator: "\n")
        }
        if totals.expensesImported == 0 && totals.incomesImported == 0 {
            return "Already up to date. \(totals.duplicatesSkipped) duplicates skipped."
        }
        return "\(totals.expensesImported) expenses, \(totals.incomesImported) incomes imported. \(totals.duplicatesSkipped) duplicates skipped."
    }

    func refreshConnectionStatus() {
        hasBankToken = Self.checkBankToken()
    }

    private static func checkBankToken() -> Bool {
        Bank.allCases.contains { KeychainHelper.loadToken(service: $0.keychainService) != nil }
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
