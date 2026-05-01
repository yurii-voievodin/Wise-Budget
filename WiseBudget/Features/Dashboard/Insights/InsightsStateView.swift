import SwiftUI

struct InsightsStateView: View {
    let state: SpendingInsightsService.State
    let summary: SpendingSummary
    let onRegenerate: () -> Void

    var body: some View {
        switch state {
        case .idle:
            if summary.isEmpty {
                EmptyRow()
            } else if summary.transactionCount < SpendingInsightsService.minimumTransactionsForInsights {
                EmptyRow(message: "Add a few more transactions this month to generate insights.")
            } else {
                PreparingRow(month: summary.month)
            }
        case .generating(let hints):
            GeneratingView(month: summary.month, hints: hints)
        case .ready(let hints):
            InsightHintsList(hints: hints)
        case .error(let message):
            ErrorView(message: message, onRegenerate: onRegenerate)
        }
    }
}

private struct EmptyRow: View {
    var message: String = "Add expenses or income to generate insights."

    var body: some View {
        Label(message, systemImage: "sparkles")
            .foregroundStyle(.secondary)
            .font(.callout)
    }
}

private struct PreparingRow: View {
    let month: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Preparing insights for \(month)…")
                .foregroundStyle(.secondary)
        }
    }
}

private struct GeneratingView: View {
    let month: String
    let hints: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Analyzing \(month)…")
                    .foregroundStyle(.secondary)
            }
            if !hints.isEmpty {
                InsightHintsList(hints: hints)
            }
        }
    }
}

private struct ErrorView: View {
    let message: String
    let onRegenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
            HStack {
                Spacer()
                Button("Try Again", action: onRegenerate)
                    .controlSize(.small)
            }
        }
    }
}
