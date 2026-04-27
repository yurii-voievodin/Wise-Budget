import AppKit
import Foundation

/// Hands off the prepared prompt to a chosen AI chat provider.
@MainActor
enum AIHandoffService {

    static let openerPrompt = "Could you analyze my spending and give me suggestions. I'll paste my transactions next."

    static func handoff(payload: String, provider: AIProvider) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(payload, forType: .string)
        NSWorkspace.shared.open(provider.openerURL(prompt: openerPrompt))
        AIHandoffNotification.notifyReadyToPaste(provider: provider)
    }
}
