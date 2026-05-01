import SwiftUI

struct TrendsStateView: View {
    let state: TrendsInsightsService.State
    let summary: TrendsSummary
    let onGenerate: () -> Void

    var body: some View {
        switch state {
        case .idle:
            IdleRow(isEmpty: summary.isEmpty, onGenerate: onGenerate)
        case .generating(let partial):
            GeneratingView(rangeLabel: summary.rangeLabel, partial: partial)
        case .ready(let text):
            ReadyView(text: text, onRegenerate: onGenerate)
        case .error(let message):
            ErrorView(message: message, onRetry: onGenerate)
        }
    }
}

private struct IdleRow: View {
    let isEmpty: Bool
    let onGenerate: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Label("On-device AI analysis of month-over-month dynamics.", systemImage: "chart.line.uptrend.xyaxis")
                .foregroundStyle(.secondary)
                .font(.callout)
            Spacer()
            Button("Analyze", action: onGenerate)
                .disabled(isEmpty)
        }
    }
}

private struct GeneratingView: View {
    let rangeLabel: String
    let partial: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Analyzing \(rangeLabel)…")
                    .foregroundStyle(.secondary)
            }
            if !partial.isEmpty {
                MarkdownText(partial)
                    .textSelection(.enabled)
            }
        }
    }
}

private struct ReadyView: View {
    let text: String
    let onRegenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MarkdownText(text)
                .textSelection(.enabled)
            HStack {
                Spacer()
                Button("Regenerate", action: onRegenerate)
                    .controlSize(.small)
            }
        }
    }
}

private struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
            HStack {
                Spacer()
                Button("Try Again", action: onRetry)
                    .controlSize(.small)
            }
        }
    }
}
