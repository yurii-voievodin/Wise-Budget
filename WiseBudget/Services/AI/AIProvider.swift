import Foundation

/// AI chat providers reachable from the Dashboard "Ask AI" menu.
///
/// Each case knows how to build an opener URL that prefills the chat
/// composer with a generic, data-free prompt. The actual transaction data
/// always travels via the clipboard — see `AIHandoffService`.
enum AIProvider: String, CaseIterable, Identifiable, Sendable {
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
}
