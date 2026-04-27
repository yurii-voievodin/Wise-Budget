import Testing
import Foundation
@testable import WiseBudget

@MainActor
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

    @Test func onlyClaudeAndGeminiUseEmbeddedWebView() {
        #expect(AIProvider.claude.usesEmbeddedWebView)
        #expect(AIProvider.gemini.usesEmbeddedWebView)
        #expect(!AIProvider.chatgpt.usesEmbeddedWebView)
    }

    @Test func embeddedURLsHaveNoQueryItems() throws {
        for provider in AIProvider.allCases {
            let components = try #require(URLComponents(url: provider.embeddedURL, resolvingAgainstBaseURL: false))
            #expect(components.queryItems == nil)
        }
        #expect(AIProvider.claude.embeddedURL.absoluteString == "https://claude.ai/new")
        #expect(AIProvider.gemini.embeddedURL.absoluteString == "https://gemini.google.com/app")
    }

    @Test func autoPasteScriptReferencesPayloadArgumentAndReturnsBool() {
        // Body should reference `payload` (the named argument passed via
        // WebPage.callJavaScript(_:arguments:)) and return true/false so
        // the Swift caller can detect a missed selector and fall back to
        // the clipboard.
        let body = AIProvider.claude.autoPasteScriptBody
        #expect(body.contains("payload"))
        #expect(body.contains("return true"))
        #expect(body.contains("return false"))
    }

    @Test func autoPasteScriptEmbedsExpectedSelectors() {
        #expect(AIProvider.claude.autoPasteScriptBody.contains("ProseMirror"))

        let geminiBody = AIProvider.gemini.autoPasteScriptBody
        #expect(geminiBody.contains("rich-textarea"))
        #expect(geminiBody.contains("ql-editor"))
    }
}
