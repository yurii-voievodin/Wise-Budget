import Foundation
import UserNotifications

/// Builds and posts the user-facing notification summarizing a bank sync run.
struct SyncNotifier {
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func notify(totals: ImportResult, errors: [String]) async {
        await post(message: summaryMessage(totals: totals, errors: errors))
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

    private static func post(message: String) async {
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
