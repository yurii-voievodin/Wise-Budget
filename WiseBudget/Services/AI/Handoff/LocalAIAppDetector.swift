import AppKit
import Foundation
import Observation

/// Observable registry of native macOS apps that host an `AIProvider`. Looks
/// up each provider's bundle identifier through `NSWorkspace`, keeps the
/// resolved app URL + cached icon, and refreshes whenever an app is
/// installed, launched, or removed. The toolbar reads this to decide whether
/// to surface "Open in {App}" rows alongside the web handoff.
@Observable
final class LocalAIAppDetector {

    struct LocalApp: Equatable, Sendable {
        let url: URL
        let icon: NSImage
    }

    private(set) var apps: [AIProvider: LocalApp] = [:]

    init() {
        refresh()

        let center = NSWorkspace.shared.notificationCenter
        let names: [NSNotification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ]
        for name in names {
            // Tokens are intentionally not retained — the detector is owned
            // by the App scene and lives for the full app lifetime, so the
            // observer block is cleaned up by the OS at process exit.
            _ = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.refresh()
                }
            }
        }
    }

    func localApp(for provider: AIProvider) -> LocalApp? {
        apps[provider]
    }

    private func refresh() {
        var resolved: [AIProvider: LocalApp] = [:]
        let workspace = NSWorkspace.shared
        for provider in AIProvider.allCases {
            guard let bundleID = provider.localAppBundleID else { continue }
            guard let url = workspace.urlForApplication(withBundleIdentifier: bundleID) else { continue }
            let icon = workspace.icon(forFile: url.path)
            resolved[provider] = LocalApp(url: url, icon: icon)
        }
        if resolved != apps {
            apps = resolved
        }
    }
}
