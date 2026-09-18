# Decisions

Log of ideas that were explicitly **Rejected** or **Deferred**, with rationale. The purpose is to avoid re-proposing the same things. If circumstances change, add a new entry overturning an old one rather than editing history.

## Entry Template

```
## YYYY-MM-DD — <Title>

**Decision:** Accepted / Rejected / Deferred
**Rationale:** one or two sentences
**Revisit when:** optional trigger
```

---

## 2026-04-17 — Seed Entries

### Recurring Transactions — Deferred
**Rationale:** Main data flow is bank sync, which already produces these automatically.
**Revisit when:** Users start creating many recurring entries manually.

### Multi-Account / Wallet Support — Deferred
**Rationale:** Not needed right now.
**Revisit when:** Several banks are integrated and per-account balances become useful.

### Transaction Tags — Rejected
**Rationale:** Categories are sufficient; tags would add UI complexity without clear user value.

### Split Transactions — Rejected
**Rationale:** Not needed right now.

### Receipt Attachments — Deferred
**Rationale:** Not a priority.
**Revisit when:** Users request it for expense-reporting use cases.

### iCloud Sync via CloudKit — Deferred
**Rationale:** Only matters with multi-device usage.
**Revisit when:** An iOS app exists.

### Budget Rollover / Envelope Budgeting — Rejected
**Rationale:** Unused budget should be directed to savings (via the Savings Goals feature), not rolled forward.

### Notifications — Deferred
**Rationale:** Not a current priority.
**Revisit when:** Core priority features ship.

### Shortcuts App Surfacing — Deferred
**Rationale:** App Intents (Spotlight / on-device AI) are the accepted path.
**Revisit when:** App Intents ship and we want broader automation surface area.

### Custom Date Ranges for Comparison — Deferred
**Rationale:** YoY first.
**Revisit when:** Users ask for arbitrary ranges.

### Background Sync via `BGTaskScheduler` — Rejected for now
**Rationale:** Manual sync is preferred.
**Revisit when:** Cooldown / rate-limit friction becomes a pain point.

### Offline-First Queue for Writes — Deferred
**Rationale:** Only relevant once CloudKit / multi-device lands.
**Revisit when:** After iCloud sync ships.

### Exchange-Rate Cache Persistence — Rejected
**Rationale:** Current in-memory cache is sufficient.

### Keychain Token Refresh Orchestrator — Deferred
**Rationale:** Implement only if token expiry causes real user problems.

### Feature Flags — Rejected for now
**Rationale:** Not needed at current team size.

### Re-enable UI Tests + Snapshot Tests — Deferred
**Rationale:** After the priority features ship.

### Migration Test Coverage — Deferred
**Rationale:** Schema will evolve with upcoming features.
**Revisit when:** After the feature wave lands.

### Analytics / Privacy-Preserving Usage Insight — Rejected
**Rationale:** Not wanted.

### Performance Sweep of Large Transaction Lists — Deferred
**Rationale:** The narrow tap-to-edit delay fix is the priority instead.
**Revisit when:** Users report slowdown with large datasets.

---

## 2026-04-21 — Additional Bank Integrations (Investigation)

### PrivatBank Integration — Deferred
**Rationale:** No public personal-account statement API. P24 (merchant_id + password) and AutoClient are restricted to merchants / ФОП / corporate clients. Token-auth personal access comparable to Monobank/Wise does not exist.
**Revisit when:** PrivatBank publishes a personal API with user-obtainable auth (token or similar).

### PKO Bank Polski Integration — Deferred
**Rationale:** Only exposes a PSD2 API. Production access is restricted to certified TPPs (KNF authorisation + eIDAS QWAC/QSealC + insurance), unachievable for a personal app. A sandbox-only PoC would produce a feature no real user could use.
**Revisit when:** PKO publishes a non-PSD2 personal API, or we integrate via a TPP aggregator (Enable Banking / GoCardless / Nordigen) as an accepted architectural shift.

---

## 2026-09-17 — Bank Sync off the MainActor

### Move Bank Sync to a Background `ModelActor` — Deferred
**Rationale:** The only real main-thread work in the sync pipeline is `CSVImporter.importTransactions` + `context.save()` — at most a few hundred rows per monthly sync, i.e. milliseconds. Network calls and rate-limit sleeps are async suspension points that never block the UI. A background `ModelContext` (SwiftData `ModelActor`) would add change-propagation and dedup-snapshot complexity for no perceptible responsiveness win.
**Revisit when:** A full-history import feature lands (thousands of rows per import) or profiling shows main-thread stalls during sync.

---

## 2026-09-17 — Parallel Wise/Monobank Sync (Investigation)

### Run Wise + Monobank Sync Concurrently via `TaskGroup` — Deferred
**Rationale:** Attempted to overlap the two banks' network waits in `BankSyncService.performSync` using `withTaskGroup` with `@MainActor`-pinned child tasks (safe in principle: both child tasks are pinned to the same actor, so the actual SwiftData writes never overlap even though the network awaits do). Hit two blockers in sequence on this toolchain (Xcode 27.0.0 RC, Swift 6, `-default-isolation=MainActor`):
1. Capturing `ModelContext` (non-Sendable) as a `performSync` parameter into two `addTask` closures fails with `SendingClosureRisksDataRace`, even when both closures are explicitly `@MainActor`. Swapping the parameter for `ModelContainer` (which *is* `Sendable`) and deriving `container.mainContext` fresh inside each closure fixed this specific diagnostic.
2. That fix uncovered a genuine compiler bug: **any** `async throws` function taking a `ModelContext` parameter, called from inside an `@MainActor`-annotated `group.addTask` closure, fails with `error: pattern that the region-based isolation checker does not understand how to check. Please file a bug` — reproduced even with a trivial locally-defined dummy function, unrelated to `WiseSyncService`/`MonobankSyncService` specifically. Not a code-architecture issue; nothing in our control fixes it.
**Revisit when:** A newer Xcode/Swift toolchain ships and the region-based isolation checker handles this pattern. Minimal repro: a `@MainActor final class` with an `async` method that opens a `withTaskGroup`, and inside `group.addTask { @MainActor in ... }` calls *any* `async throws` function taking a `ModelContext` (or any non-Sendable type) argument.

---

## 2026-04-21 — Ukrainian Insight Prompts

### Ukrainian Foundation Models Prompts — Deferred
**Rationale:** Apple Intelligence does not support Ukrainian, so the locale resolver always fell back to English and the Ukrainian prompts were permanently dead code. Removed the Ukrainian branch, the `InsightLocale` abstraction, and its tests; both insight services now inline the English instructions directly.
**Revisit when:** Apple Intelligence adds Ukrainian language support — hopefully in macOS 27.
