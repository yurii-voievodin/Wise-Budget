import Testing
import AppKit
@testable import WiseBudget

@MainActor
struct LocalAIAppDetectorTests {

    /// The detector is essentially a thin wrapper around `NSWorkspace`. We
    /// can't synthetically install a fake bundle ID, but we can assert the
    /// detector reports a consistent state for a known-absent provider
    /// (Gemini has no `localAppBundleID` — should never appear in `apps`).
    @Test func detectorNeverReportsProviderWithoutBundleID() {
        let detector = LocalAIAppDetector()
        #expect(detector.localApp(for: .gemini) == nil)
    }

    /// Detected providers must round-trip the same `URL` and `NSImage`
    /// instances via the lookup helper.
    @Test func localAppLookupMatchesAppsDictionary() {
        let detector = LocalAIAppDetector()
        for (provider, app) in detector.apps {
            let lookup = detector.localApp(for: provider)
            #expect(lookup?.url == app.url)
            #expect(lookup?.icon === app.icon)
        }
    }
}
