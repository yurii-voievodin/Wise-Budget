# macOS 26 budget widget (v1: medium size)

## Context

Per [docs/planning/FEATURES.md](docs/planning/FEATURES.md), top-priority next feature: a macOS 26 widget that surfaces "current month spend vs. budget, top category, and a small trends spark," reusing Dashboard data. v1 ships **medium size only**; small and large can follow.

The interesting part isn't the widget UI — it's the infrastructure. Today the app stores SwiftData in the default container and reads `DefaultCurrency` from `UserDefaults.standard`. Widgets run in a separate sandbox and cannot read either. So the v1 plan is dominated by **App Group migration**, with the widget itself layered on top.

## Architecture

### App Group plumbing (new)

- **App Group ID**: `group.com.wisebudget`. Declared in entitlements for both the main app and the new widget extension.
- **SwiftData store**: relocated from `URL.applicationSupportDirectory` (default) to `containerURL(forSecurityApplicationGroupIdentifier: "group.com.wisebudget").appendingPathComponent("WiseBudget.sqlite")`. The new `ModelConfiguration(url:)` initializer pins to that URL.
- **UserDefaults**: introduce `UserDefaults(suiteName: "group.com.wisebudget")!` as the canonical store for `DefaultCurrency` and any other widget-readable preferences. `DefaultCurrency.swift:18-20` switches from `.standard` to the suite.

### One-shot migration on first launch after upgrade

In [WiseBudgetApp.swift:8-27](WiseBudget/WiseBudgetApp.swift:8) before building the container:

1. If the App Group store file does **not** exist AND a legacy default-location store exists, copy `.sqlite`, `.sqlite-shm`, `.sqlite-wal` over to the App Group directory. Use `FileManager.copyItem`.
2. After successful copy, write a `migratedToAppGroupV1 = true` flag in the App Group `UserDefaults`. Subsequent launches skip the check entirely.
3. For `UserDefaults`: on first launch after upgrade, if the suite has no `defaultCurrency` key but `.standard` does, copy it across. Same one-shot flag.

If the copy fails (disk full, permissions), fall back to opening the existing default-location store with a logged warning, and don't enable the widget — the user keeps working. We don't want a corrupted migration to brick the app.

### Widget extension target

A new target `WiseBudgetWidgets` (WidgetKit + SwiftUI), added via Xcode UI (CLAUDE.md prohibits manual `project.pbxproj` edits, but Xcode auto-edits it for new targets — that's fine). One file in the extension:

- `WiseBudgetWidgets/BudgetWidget.swift` — `Widget`, `TimelineProvider`, `EntryView`. Single `WidgetFamily.systemMedium`.

The extension shares the App Group + entitlements + SwiftData schema by linking the existing `Models/` and `Shared/` Swift files. Per CLAUDE.md "automatic file discovery," the only project edit is creating the target itself; new shared files don't need pbxproj entries.

### Data layer for the widget

A new pure helper in the main app (so it's reusable + testable):

- `WiseBudget/Services/Insights/WidgetSnapshot.swift`:
  ```swift
  struct WidgetSnapshot: Sendable {
      let monthSpend: Decimal
      let monthlyBudget: Decimal?
      let topCategory: (name: String, iconName: String, total: Decimal)?
      let dailySpark: [Decimal]   // one entry per day-of-month so far, in display currency
      let currency: String
  }

  enum WidgetSnapshotBuilder {
      @MainActor
      static func build(context: ModelContext, on date: Date = .now) throws -> WidgetSnapshot
  }
  ```

This helper:
- Fetches expenses for `[startOfMonth, date]` via `FetchDescriptor<Expense>` with the standard month predicate already used by `MonthFilter`.
- Sums `convertedAmount(to: currency)` for `monthSpend`. (Same loop as [DashboardView.swift:65-71](WiseBudget/Features/Dashboard/DashboardView.swift:65) — extract into this helper and have the Dashboard call it too, eliminating duplication.)
- Groups by category for `topCategory` (logic from [DashboardView.swift:73-82](WiseBudget/Features/Dashboard/DashboardView.swift:73), again moved here).
- Buckets per day-of-month into a `[Decimal]` of length `Calendar.dayOfMonth(date)` for the spark — this *is* new logic, no existing helper.
- Looks up `BudgetPlan` via `FetchDescriptor<BudgetPlan>` with `#Predicate { $0.year == y && $0.month == m }`, `.first?.monthlyBudget`.

`@MainActor` because SwiftData fetches require it; the timeline provider hops to main with `await MainActor.run`.

### Timeline provider

`BudgetWidget.swift` provider:
- `placeholder` returns a `WidgetSnapshot` with sample data (mocked Decimals).
- `getSnapshot` calls `WidgetSnapshotBuilder.build(context:)` against the App Group ModelContainer.
- `getTimeline` returns one entry now and one at next-hour boundary (`Calendar.nextDate(.hour)`). Reload policy: `.atEnd`. Hourly is fine — spend doesn't tick by the second.
- `WidgetConfiguration` is `StaticConfiguration` (no user options in v1).

### Widget UI (medium)

```
┌────────────────────────────────────────────────┐
│  €1 234,56 / €2 000           Groceries  €423  │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░    🛒            │
│  Spark: ▁▂▃▂▅▃▆▄▇▆▅▄▃▂▂▃▄▃▂▁▂▃▄                │
└────────────────────────────────────────────────┘
```

Three rows in a `VStack`:
1. Spend / budget amounts (formatted via existing `Currency.format(_:in:)`).
2. `ProgressView(value:total:)` for the budget pace, with `.tint(.red)` when over.
3. A trailing-aligned mini bar chart (`Chart` from Swift Charts, `BarMark`-only, ~24pt tall, no axes) for the daily spark.

Top category renders as a small `Label(name, systemImage: iconName)` row above the bar — fits within `systemMedium`.

When `monthlyBudget == nil` (no budget set yet), hide the progress bar and show "No budget set" inline.

## Files to create / modify

- **Create**: `WiseBudget/Services/Insights/WidgetSnapshot.swift` — snapshot type + builder.
- **Create**: `WiseBudgetWidgets/` target via Xcode UI: `BudgetWidget.swift`, `WiseBudgetWidgets.entitlements`.
- **Modify**: [WiseBudget/WiseBudgetApp.swift:8](WiseBudget/WiseBudgetApp.swift:8) — App Group container URL, one-shot migration step.
- **Modify**: [WiseBudget/Models/DefaultCurrency.swift](WiseBudget/Models/DefaultCurrency.swift) — switch to App Group `UserDefaults(suiteName:)`.
- **Modify**: `WiseBudget/Resources/WiseBudget.entitlements` — add `com.apple.security.application-groups = ["group.com.wisebudget"]`.
- **Modify**: [WiseBudget/Features/Dashboard/DashboardView.swift:65-82](WiseBudget/Features/Dashboard/DashboardView.swift:65) — call `WidgetSnapshotBuilder` for spend total + top category instead of inlining (kills duplication).

## Tests

- **`WidgetSnapshotTests`** in `WiseBudgetTests/`: in-memory ModelContainer seeded with expenses + a BudgetPlan, build a snapshot, assert `monthSpend`, `topCategory`, `dailySpark.count`, `monthlyBudget`. Use Swift Testing.
- **Migration test**: in a temp directory simulate "old store at default location, no App Group store"; run the migration step; assert files copied and the flag set.
- **No widget UI tests** — WidgetKit doesn't have a great unit testing story; rely on manual verification.

## Out of scope (v1)

- Small / large widget sizes — explicitly deferred per user choice.
- Lock-screen widgets (`.accessoryRectangular` etc.) — defer until medium ships.
- User configuration (`AppIntentConfiguration`) for picking which budget/currency to show — single default for now.
- Background refresh tuning — hourly `.atEnd` reload is fine for v1.
- Migrating Keychain to a shared access group — bank tokens stay in `com.wisebudget.*` services and remain main-app-only. Widget never needs them.

## Verification

1. `mcp__xcode__BuildProject` after each major step (App Group plumbing, snapshot helper, widget target) — green.
2. `mcp__xcode__RunAllTests` — full suite green, including the new snapshot + migration tests.
3. Manual on a clean install: launch app, add expenses + budget, drag widget to desktop / notification center → numbers match Dashboard within an hour.
4. Manual upgrade scenario: install pre-migration build, populate data, upgrade to migration build, verify all data still present and the widget reads it.
