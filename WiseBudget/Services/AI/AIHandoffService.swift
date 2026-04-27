import AppKit
import Foundation

/// Hands off the prepared prompt to a chosen AI chat provider.
@MainActor
enum AIHandoffService {

    static let openerPrompt = "Could you analyze my spending and give me suggestions. I'll paste my transactions next."

    /// Web handoff: copy payload to the clipboard, open the provider's web
    /// opener URL in the default browser, and surface a system notification
    /// so the user knows where to paste once focus has moved.
    static func handoff(payload: String, provider: AIProvider) {
        copyToClipboard(payload)
        NSWorkspace.shared.open(provider.openerURL(prompt: openerPrompt))
        AIHandoffNotification.notifyReadyToPaste(provider: provider)
    }

    /// Native handoff: copy payload, attempt any registered URL-scheme
    /// prefill (option 2), then activate the locally installed app and
    /// post the same paste notification. Falls back silently if the
    /// scheme probe fails — the app still gets activated.
    static func handoffToLocalApp(payload: String, provider: AIProvider, appURL: URL) {
        copyToClipboard(payload)

        let prefillURLs = provider.localAppPrefillURLs(prompt: openerPrompt)

        if let firstScheme = prefillURLs.first {
            NSWorkspace.shared.open([firstScheme], withApplicationAt: appURL, configuration: activatingConfiguration()) { app, error in
                if app == nil || error != nil {
                    Task { @MainActor in
                        NSWorkspace.shared.openApplication(at: appURL, configuration: activatingConfiguration(), completionHandler: nil)
                    }
                }
            }
        } else {
            NSWorkspace.shared.openApplication(at: appURL, configuration: activatingConfiguration(), completionHandler: nil)
        }

        AIHandoffNotification.notifyReadyToPaste(provider: provider)
    }

    private static func copyToClipboard(_ payload: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(payload, forType: .string)
    }

    private static func activatingConfiguration() -> NSWorkspace.OpenConfiguration {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        return configuration
    }
}
