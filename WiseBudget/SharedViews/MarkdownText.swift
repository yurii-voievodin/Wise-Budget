import SwiftUI

/// Renders a subset of Markdown without external dependencies:
/// - `- item` / `* item` → visual bullet rows
/// - inline `**bold**`, `*italic*`, `` `code` ``, and links via `AttributedString(markdown:)`
/// - blank lines become vertical spacing
struct MarkdownText: View {
    let source: String

    init(_ source: String) {
        self.source = source
    }

    var body: some View {
        let lines = source.components(separatedBy: "\n")
        VStack(alignment: .leading, spacing: 4) {
            ForEach(lines.indices, id: \.self) { index in
                MarkdownLine(rawLine: lines[index])
            }
        }
    }
}

private struct MarkdownLine: View {
    let rawLine: String

    var body: some View {
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            Spacer().frame(height: 4)
        } else if let bulletBody = Self.bulletBody(of: trimmed) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•")
                    .foregroundStyle(.secondary)
                Text(Self.attributed(bulletBody))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text(Self.attributed(trimmed))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private static func bulletBody(of line: String) -> String? {
        if line.hasPrefix("- ") { return String(line.dropFirst(2)) }
        if line.hasPrefix("* ") { return String(line.dropFirst(2)) }
        return nil
    }

    private static func attributed(_ text: String) -> AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        if let attr = try? AttributedString(markdown: text, options: options) {
            return attr
        }
        return AttributedString(text)
    }
}
