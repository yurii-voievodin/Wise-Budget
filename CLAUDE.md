# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build
xcodebuild build -project WiseBudget.xcodeproj -scheme WiseBudget

# Run all tests
xcodebuild test -project WiseBudget.xcodeproj -scheme WiseBudget

# Run a single test file (filter by class name)
xcodebuild test -project WiseBudget.xcodeproj -scheme WiseBudget \
  -only-testing:WiseBudgetTests/CSVExportImportTests
```

## Project File

Do NOT modify `WiseBudget.xcodeproj/project.pbxproj` — the project uses automatic file discovery, so adding or removing source files does not require changes to the Xcode project file.

## Architecture

- **Platform:** macOS (deployment target 26.2)
- **UI:** SwiftUI with `NavigationSplitView` (3-column layout)
- **Data:** SwiftData with `@Model`, `@Query`, `@Environment(\.modelContext)`
- **Swift version:** 5.0
- **No external dependencies**

### Targets

| Target | Purpose |
|---|---|
| `WiseBudget` | Main app (`WiseBudgetApp.swift` entry point) |
| `WiseBudgetTests` | Unit tests using Swift Testing (`@Test` macro) |
| `WiseBudgetUITests` | UI tests using XCTest (currently disabled in test plan) |

### Data Models

Six SwiftData `@Model` classes in `Models/`:

- **Expense** / **Income** — both conform to `CurrencyConvertible` protocol (tracks `amount`, `currency`, `baseCurrencyAmount`, `baseCurrency`). Linked to their respective category via optional relationship.
- **ExpenseCategory** / **IncomeCategory** — name + iconName, inverse relationship to transactions (`.nullify` delete rule). Default categories seeded by `DataSeeder`.
- **BudgetPlan** — year/month/currency/monthlyBudget, owns `BudgetPlanItem` array (cascade delete).
- **BudgetPlanItem** — planned amount per expense category within a budget plan.

`ModelContainer` is configured in `WiseBudgetApp.swift` and injected into the view hierarchy.

### Bank Sync Pipeline

Dual-bank sync orchestrated by `BankSyncService` (`@Observable`, `@MainActor`):

1. **API Clients** (`Services/API/`) — `WiseAPIClient` (api.wise.com) and `MonobankAPIClient` (api.monobank.ua). Auth tokens stored in Keychain.
2. **Sync Services** (`Services/Sync/`) — `WiseSyncService` and `MonobankSyncService` run in parallel. Both convert API responses into `CSVTransaction` structs, then import via `CSVImporter`.
3. **Deduplication** — each transaction gets an `externalId` (`wise_{id}` or `mono_{id}`). Import skips existing IDs.
4. **Categorization** — Wise card transactions use `MerchantCategoryMapping` (keyword→category). Monobank uses MCC codes. Fallback: activity type → default category.
5. **Rate limiting** — 60s sync cooldown, 1s delay between Monobank API calls, 31-day sliding window for Monobank.

### Import/Export

- `CSVImporter` — parses Wise CSV exports, maps Ukrainian category names to English, filters by status (COMPLETED/REFUNDED) and direction (OUT→expense, IN→income, NEUTRAL→skip).
- `MonobankCSVImporter` / `AppDataCSVImporter` — format-specific importers.
- `CSVExporter` — exports all expenses & incomes to CSV for backup.

### Key Services

- **KeychainHelper** — secure token storage (`com.wisebudget.wise-token`, `com.wisebudget.monobank-token`).
- **DataSeeder** — prepopulates default categories on first launch; handles icon migrations via UserDefaults flags.
- **ExchangeRateService** — fetches historical rates from Wise API, caches by currency pair + date.

### Testing Patterns

Tests use Swift Testing framework (`@Test` macro), not XCTest. Test setup uses in-memory `ModelContainer` for isolation. Tests that touch SwiftData require `@MainActor`.
