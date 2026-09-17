import Testing
import Foundation
@testable import WiseBudget

struct AIProviderTests {

    @Test func claudeURLHasNewPathAndQueryItems() throws {
        let url = AIProvider.claude.openerURL(prompt: "hello world")
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.host == "claude.ai")
        #expect(components.path == "/new")

        let items = try #require(components.queryItems)
        #expect(items.contains(URLQueryItem(name: "q", value: "hello world")))
        #expect(items.contains(URLQueryItem(name: "api_model", value: "claude-haiku-4-5")))
    }

    @Test func chatgptURLHasQueryItem() throws {
        let url = AIProvider.chatgpt.openerURL(prompt: "hello world")
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.host == "chatgpt.com")

        let items = try #require(components.queryItems)
        #expect(items.contains(URLQueryItem(name: "q", value: "hello world")))
    }

    @Test func geminiURLHasAppPath() throws {
        let url = AIProvider.gemini.openerURL(prompt: "hello world")
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.host == "gemini.google.com")
        #expect(components.path == "/app")
        #expect(components.queryItems == nil)
    }

    @Test func openerURLPercentEncodesPrompt() throws {
        let url = AIProvider.claude.openerURL(prompt: "hello world & friends")
        let absolute = url.absoluteString
        #expect(absolute.contains("hello%20world%20%26%20friends") || absolute.contains("hello+world+%26+friends"))
    }

    @Test func displayNamesAreStable() {
        #expect(AIProvider.claude.displayName == "Claude")
        #expect(AIProvider.chatgpt.displayName == "ChatGPT")
        #expect(AIProvider.gemini.displayName == "Gemini")
    }

    @Test func allCasesContainsAllThreeProviders() {
        #expect(Set(AIProvider.allCases) == Set([.claude, .chatgpt, .gemini]))
    }

    @Test func localAppBundleIDsForNativeProviders() {
        #expect(AIProvider.claude.localAppBundleID == "com.anthropic.claudefordesktop")
        #expect(AIProvider.chatgpt.localAppBundleID == "com.openai.chat")
        #expect(AIProvider.gemini.localAppBundleID == nil)
    }

    @Test func localAppPrefillURLsAreEmptyByDefault() {
        // Option-2 URL-scheme probing is structurally supported but no
        // schemes are populated yet. When schemes get added, expand this
        // test to cover the encoded prompt round-trip.
        for provider in AIProvider.allCases {
            #expect(provider.localAppPrefillURLs(prompt: "any prompt").isEmpty)
        }
    }
}
