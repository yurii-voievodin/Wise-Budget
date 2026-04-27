import SwiftUI
import WebKit
import AppKit

/// Content of an in-app AI chat window. Loads the provider's URL in a
/// SwiftUI `WebView`, then auto-pastes the prepared payload into the
/// composer via JS. Falls back to the existing clipboard + notification
/// flow if the composer can't be located.
@MainActor
struct AIChatWindowContent: View {
    let request: AIChatRequest

    @State private var page: WebPage
    @State private var didAutoPaste = false

    init(request: AIChatRequest) {
        self.request = request
        _page = State(initialValue: WebPage())
    }

    var body: some View {
        WebView(page)
            .navigationTitle(request.provider.displayName)
            .overlay(alignment: .top) {
                if page.isLoading {
                    ProgressView(value: page.estimatedProgress)
                        .progressViewStyle(.linear)
                        .padding(.horizontal)
                }
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        page.reload()
                    } label: {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                }
                ToolbarItem {
                    Button {
                        NSWorkspace.shared.open(request.provider.embeddedURL)
                    } label: {
                        Label("Open in Safari", systemImage: "safari")
                    }
                }
            }
            .task(id: request.id) {
                await loadAndAutoPaste()
            }
    }

    private func loadAndAutoPaste() async {
        didAutoPaste = false

        do {
            for try await event in page.load(URLRequest(url: request.provider.embeddedURL)) {
                if case .finished = event {
                    await runAutoPaste()
                    return
                }
            }
        } catch {
            fallbackToClipboard()
        }
    }

    private func runAutoPaste() async {
        guard !didAutoPaste else { return }
        didAutoPaste = true

        do {
            let result = try await page.callJavaScript(
                request.provider.autoPasteScriptBody,
                arguments: ["payload": request.payload]
            )
            if (result as? Bool) != true {
                fallbackToClipboard()
            }
        } catch {
            fallbackToClipboard()
        }
    }

    private func fallbackToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(request.payload, forType: .string)
        AIHandoffNotification.notifyReadyToPaste(provider: request.provider)
    }
}
