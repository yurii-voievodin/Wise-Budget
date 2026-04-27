import SwiftUI
import SwiftData
import TipKit

/// Toolbar menu that copies the selected month's transactions plus an
/// analysis prompt to the clipboard, then opens a chosen AI chat provider
/// (Claude / ChatGPT / Gemini). The last-used provider floats to the top
/// of the menu via `@AppStorage`. Disabled when the selected month has no
/// expenses.
@MainActor
struct AskAIToolbar: ToolbarContent {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"
    @AppStorage("defaultAIProvider") private var defaultProvider: AIProvider = .claude

    let filter: MonthFilter
    let expenseCount: Int
    let onCopied: (AIProvider) -> Void

    private static let tip = AskAITip()

    private var isEnabled: Bool {
        expenseCount >= SpendingInsightsService.minimumTransactionsForInsights
    }

    private var helpText: String {
        if isEnabled {
            return "Copy this month's transactions to the clipboard and open an AI chat"
        }
        let minimum = SpendingInsightsService.minimumTransactionsForInsights
        return "Add at least \(minimum) expenses this month to enable Ask AI"
    }

    var body: some ToolbarContent {
        ToolbarItem {
            Menu {
                ForEach(orderedProviders) { provider in
                    Button(provider.displayName, systemImage: provider.iconName) {
                        handoff(provider: provider)
                    }
                }
            } label: {
                Label("Ask AI", systemImage: "sparkles")
            }
            .disabled(!isEnabled)
            .help(helpText)
            .popoverTip(Self.tip)
        }
    }

    private var orderedProviders: [AIProvider] {
        let rest = AIProvider.allCases.filter { $0 != defaultProvider }
        return [defaultProvider] + rest
    }

    private func handoff(provider: AIProvider) {
        let currentStart = filter.startOfMonth
        let currentEnd = filter.startOfNextMonth

        let descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate { $0.date >= currentStart && $0.date < currentEnd },
            sortBy: [SortDescriptor(\.date)]
        )
        let currentExpenses = (try? modelContext.fetch(descriptor)) ?? []

        let payload = AskClaudePromptBuilder.build(
            monthFilter: filter,
            currentMonthExpenses: currentExpenses,
            baseCurrency: defaultCurrency,
            responseLanguageName: AskClaudePromptBuilder.systemResponseLanguageName()
        )
        AIHandoffService.handoff(payload: payload, provider: provider)
        defaultProvider = provider
        Self.tip.invalidate(reason: .actionPerformed)
        onCopied(provider)
    }
}
