import Foundation

/// AI chat providers reachable from the Dashboard "Ask AI" menu.
///
/// Each case knows how to build an opener URL that prefills the chat
/// composer with a generic, data-free prompt. The actual transaction data
/// always travels via the clipboard — see `AIHandoffService`.
enum AIProvider: String, CaseIterable, Identifiable, Sendable, Codable, Hashable {
    case claude
    case chatgpt
    case gemini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude:  return "Claude"
        case .chatgpt: return "ChatGPT"
        case .gemini:  return "Gemini"
        }
    }

    var iconName: String {
        switch self {
        case .claude:  return "bubble.left.and.text.bubble.right"
        case .chatgpt: return "text.bubble"
        case .gemini:  return "sparkles"
        }
    }

    /// Whether the provider opens inside the app in an embedded web view
    /// instead of being handed off to the default browser.
    var usesEmbeddedWebView: Bool {
        switch self {
        case .claude, .gemini: return true
        case .chatgpt:         return false
        }
    }

    /// Entry point loaded by the embedded web view. No `?q=` parameter —
    /// the prompt is injected into the composer via JavaScript instead.
    var embeddedURL: URL {
        switch self {
        case .claude:  return URL(string: "https://claude.ai/new")!
        case .chatgpt: return URL(string: "https://chatgpt.com/")!
        case .gemini:  return URL(string: "https://gemini.google.com/app")!
        }
    }

    func openerURL(prompt: String) -> URL {
        switch self {
        case .claude:
            var components = URLComponents(string: "https://claude.ai/new")!
            components.queryItems = [
                URLQueryItem(name: "q", value: prompt),
                URLQueryItem(name: "api_model", value: "claude-haiku-4-5")
            ]
            return components.url ?? URL(string: "https://claude.ai/new")!

        case .chatgpt:
            var components = URLComponents(string: "https://chatgpt.com/")!
            components.queryItems = [URLQueryItem(name: "q", value: prompt)]
            return components.url ?? URL(string: "https://chatgpt.com/")!

        case .gemini:
            return URL(string: "https://gemini.google.com/app")!
        }
    }

    /// JavaScript function body that fills the provider's composer with the
    /// `payload` argument (passed via `WebPage.callJavaScript(_:arguments:)`)
    /// and returns `true` on success / `false` if the composer wasn't found
    /// inside the retry window. The body uses `await` because
    /// `WebPage.callJavaScript` runs it as an async function.
    var autoPasteScriptBody: String {
        let selector: String
        switch self {
        case .claude:
            selector = #"div.ProseMirror[contenteditable=\"true\"]"#
        case .gemini:
            selector = #"rich-textarea div.ql-editor[contenteditable=\"true\"]"#
        case .chatgpt:
            selector = #"#prompt-textarea[contenteditable=\"true\"]"#
        }

        return """
        const selector = "\(selector)";
        const deadline = Date.now() + 5000;
        while (Date.now() < deadline) {
            const el = document.querySelector(selector);
            if (el) {
                el.focus();
                el.textContent = payload;
                el.dispatchEvent(new InputEvent('input', { bubbles: true, cancelable: true, inputType: 'insertFromPaste', data: payload }));
                el.dispatchEvent(new Event('change', { bubbles: true }));
                return true;
            }
            await new Promise(resolve => setTimeout(resolve, 100));
        }
        return false;
        """
    }
}
