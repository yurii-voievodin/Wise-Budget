# Features

Accepted candidate features in priority order. Items above the separator are the next wave; items below are accepted but not yet scheduled.

---

## Widgets & Lock Screen

macOS 26 widgets showing current month spend vs. budget, top category, and a small trends spark. Reuses Dashboard data.

## App Intents

Donate `App Intents` for "Log expense", "What did I spend on groceries this week?", "Show budget status". Surfaces WiseBudget in Spotlight and on-device AI queries. (Shortcuts app surfacing is out of scope for now — see DECISIONS.)

## Accessibility Audit Pass

Run the `swiftui-pro` skill's accessibility references across the whole Views layer — confirm Dynamic Type scales, icon-only buttons have labels, Reduce Motion is respected, and color is never the sole differentiator. Wanted as soon as possible.

---

## Savings Goals with AI-Suggested Contributions

A `SavingsGoal` model (name, target, deadline, currency) with Dashboard progress. The interesting twist: Foundation Models analyze recent spending and suggest concrete categories where the user could cut back, then propose moving that delta to a linked savings account. Builds directly on the existing `SpendingInsightsService` + `TrendsInsightsService` infrastructure — mostly a new prompt plus a "Move suggested amount to goal" action.

## Transfers Between Accounts

Allow a transaction to be flagged as a transfer (e.g., moving money from Wise to a savings account). Transfers are visible in history but excluded from every statistic: no expense totals, no income totals, no category charts, no budget pacing. Implementation: a new `isTransfer` flag (or `TransactionKind` enum) plus predicate adjustments on every aggregation.

## Spending Anomaly Alerts

Use Foundation Models (already integrated) to flag transactions unusually large vs. history for that category or merchant. Non-intrusive badge on the transaction row, plus an "Anomalies" surface on the Dashboard. Start as an experiment we can measure qualitatively before expanding.

## Local AI Backends — Locally AI, Ollama, LM Studio

Pluggable on-device AI providers for users who already run a local LLM. Two integration surfaces share the existing `LocalAIAppDetector` plumbing: (1) an Ask AI handoff row per detected app — copy payload, activate the desktop app — mirroring the Claude Desktop / ChatGPT Desktop flow we already ship; (2) a direct in-app analysis path where `SpendingInsightsService` and `TrendsInsightsService` call the local HTTP API instead of (or alongside) Foundation Models, so insights surface inside WiseBudget without a context switch.

Detection extends `LocalAIAppDetector` to probe HTTP endpoints in addition to bundle identifiers — `http://localhost:11434/api/tags` for Ollama, `http://localhost:1234/v1/models` for LM Studio, plus whatever Locally AI exposes (verify before committing to direct calls). LM Studio's OpenAI-compatible API lets a generic chat client serve LM Studio, Ollama (in OpenAI-compat mode), and any future runner without per-vendor code. A new Settings panel picks provider + base URL + model, with Foundation Models remaining the default for users without a local runner installed.

Headline value: the full transaction ledger stays on the user's machine — no cloud round-trip, no token costs, and the privacy story is the same as the existing on-device Foundation Models flow.

## Forecasting, Projections, and "Generate Next Month's Budget"

Two related Foundation-Models features. (1) End-of-month spending projection + "at current pace you'll overshoot budget by X" — extends the existing insights pipeline with a new prompt. (2) A button on the Budget Plan screen that generates a proposed budget for the next month based on prior-month actuals and trends; the user reviews and edits before saving. Both reuse `TrendsInsightsService` scaffolding.

## Merchant-Level Insights + Charts

Surface top merchants (via `externalId` / description clustering — `MerchantCategoryMapping` already extracts a normalized merchant string) with their own trends. Add charts showing transaction count and total spend at a merchant over the last month / last 6 months / last year. Gives users a view the category-only Dashboard can't.

## Year-over-Year Comparison

Extend `ExpenseComparisonView` with a YoY mode (this month vs. same month last year, this year-to-date vs. last year-to-date). Custom date ranges are out of scope for now — revisit later.

## Global Search (Later)

Command-palette-style search (⌘F) across transactions, categories, and budget plans with filters. Deferred — revisit after priority items land.

## Reports Export — PDF (Later, Low Priority)

Branded PDF monthly/quarterly/annual report with charts, category breakdowns, and notable insights. Reuses data powering the Dashboard. Low priority; revisit once the iOS target decision is made.

## iOS Target (Maybe, After All Mac Features)

The data and service layers are UI-agnostic; porting to iOS would unlock mobile expense entry, widgets, and Live Activities. Requires UI/navigation redesign (`NavigationSplitView` → `TabView` + stacks on compact widths). Gated behind "all planned Mac features shipped first."
