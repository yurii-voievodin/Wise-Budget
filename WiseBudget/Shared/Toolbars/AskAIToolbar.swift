import SwiftUI
import SwiftData
import OSLog
import TipKit

private let logger = Logger(subsystem: "com.wisebudget", category: "AskAIToolbar")

/// Toolbar menu that copies the selected month's transactions plus an
/// analysis prompt to the clipboard, then opens a chosen AI chat provider
/// (Claude / ChatGPT / Gemini). The last-used target floats to the top of
/// the menu via `@AppStorage`. Disabled when the selected month has no
/// expenses.
@MainActor
struct AskAIToolbar: ToolbarContent {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocalAIAppDetector.self) private var localAppDetector
    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback
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
                ForEach(orderedTargets) { target in
                    Button {
                        handoff(target: target)
                    } label: {
                        targetLabel(for: target)
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

    @ViewBuilder
    private func targetLabel(for target: AIHandoffTarget) -> some View {
        switch target.destination {
        case .nativeApp:
            if let app = localAppDetector.localApp(for: target.provider) {
                Label {
                    Text(target.provider.displayName)
                } icon: {
                    Image(nsImage: app.icon)
                }
            } else {
                Label(target.provider.displayName, systemImage: target.provider.iconName)
            }
        case .web:
            Label(target.provider.displayName, systemImage: target.provider.iconName)
        }
    }

    /// One row per provider. If a native macOS app is detected, the row
    /// hands off to that app; otherwise it falls back to the browser. The
    /// last-used provider floats to the top via `defaultProvider`.
    private var orderedTargets: [AIHandoffTarget] {
        let all = AIProvider.allCases.map { provider -> AIHandoffTarget in
            let destination: AIHandoffTarget.Destination =
                localAppDetector.localApp(for: provider) != nil ? .nativeApp : .web
            return AIHandoffTarget(provider: provider, destination: destination)
        }

        guard let preferredIndex = all.firstIndex(where: { $0.provider == defaultProvider }) else {
            return all
        }
        var ordered = all
        let item = ordered.remove(at: preferredIndex)
        ordered.insert(item, at: 0)
        return ordered
    }

    private func handoff(target: AIHandoffTarget) {
        let currentStart = filter.startOfMonth
        let currentEnd = filter.startOfNextMonth

        let expenseDescriptor = FetchDescriptor<Expense>(
            predicate: #Predicate { $0.date >= currentStart && $0.date < currentEnd && !$0.isInternalTransfer },
            sortBy: [SortDescriptor(\.date)]
        )
        let incomeDescriptor = FetchDescriptor<Income>(
            predicate: #Predicate { $0.date >= currentStart && $0.date < currentEnd && !$0.isInternalTransfer },
            sortBy: [SortDescriptor(\.date)]
        )

        // Abort the handoff on a fetch failure rather than copying an empty
        // prompt and showing a misleading "Copied" toast.
        let currentExpenses: [Expense]
        let currentIncomes: [Income]
        do {
            currentExpenses = try modelContext.fetch(expenseDescriptor)
            currentIncomes = try modelContext.fetch(incomeDescriptor)
        } catch {
            logger.error("Failed to fetch transactions for AI handoff: \(error.localizedDescription, privacy: .public)")
            return
        }

        // `topCategoryLimit: .max` so the cloud prompt sees every category,
        // not the on-device default of 8. The dashboard's `spendingSummary`
        // computed property keeps the default for the on-device pathway.
        let summary = SpendingSummary.build(
            monthFilter: filter,
            currency: defaultCurrency,
            expenses: currentExpenses,
            incomes: currentIncomes,
            topCategoryLimit: .max
        )

        let payload = CloudAIPromptBuilder.build(
            monthFilter: filter,
            summary: summary,
            baseCurrency: defaultCurrency,
            responseLanguageName: CloudAIPromptBuilder.systemResponseLanguageName()
        )

        switch target.destination {
        case .nativeApp:
            if let app = localAppDetector.localApp(for: target.provider) {
                AIHandoffService.handoffToLocalApp(
                    payload: payload,
                    provider: target.provider,
                    appURL: app.url
                )
            } else {
                AIHandoffService.handoff(payload: payload, provider: target.provider)
            }
        case .web:
            AIHandoffService.handoff(payload: payload, provider: target.provider)
        }

        defaultProvider = target.provider
        Self.tip.invalidate(reason: .actionPerformed)
        onCopied(target.provider)
    }
}
