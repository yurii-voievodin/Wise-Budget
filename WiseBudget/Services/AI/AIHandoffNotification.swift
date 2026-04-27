import Foundation
import UserNotifications

/// Posts a macOS user notification telling the user to paste the prepared
/// payload into the chosen AI provider. Visible regardless of which app is
/// in focus, so the user sees it after the browser has stolen focus. 
@MainActor
enum AIHandoffNotification {
    private static let identifier = "wisebudget.aiHandoff.readyToPaste"

    static func notifyReadyToPaste(provider: AIProvider) {
        let providerName = provider.displayName
        let requestIdentifier = identifier
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Ready to paste in \(providerName)"
            content.body = "Press ⌘V in the \(providerName) composer to send your transactions for analysis."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: requestIdentifier,
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
    }
}
