import TipKit

/// First-run tip introducing the "Ask AI" toolbar menu.
struct AskAITip: Tip {
    var title: Text {
        Text("Ask AI about this month")
    }

    var message: Text? {
        Text("Pick Claude, ChatGPT, or Gemini — your transactions get copied to the clipboard and the chat opens with a starter prompt. Paste with ⌘V to send.")
    }

    var image: Image? {
        Image(systemName: "sparkles")
    }
}
