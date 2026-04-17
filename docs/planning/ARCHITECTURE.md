# Architecture

Accepted architecture and code-health proposals. Priority items sit at the top; the rest are accepted but not yet scheduled.

---

## Priority — Fix the Tap-to-Edit Delay

When tapping a transaction row to open the edit form there's a noticeable delay. Investigate the root cause: is it `@Query` invalidating, sheet presentation cost, form content initialization, or expensive view body work? Profile with Instruments (Time Profiler + SwiftUI), identify the hotspot, and fix. Do this before a wider performance audit — a narrow, user-visible regression beats a general sweep.

## Priority — Full Swift 6 Strict Concurrency

Recent commits already hardened concurrency; turn on complete strict concurrency checking project-wide and resolve remaining warnings. Catches data races at compile time and keeps the codebase future-proof.

## Priority — Accessibility Audit

Cross-listed from `FEATURES.md` because it's both user-facing and a code-health task. Run the `swiftui-pro` skill's accessibility references across the whole Views layer.

---

## Introduce Local Swift Packages

Extract `Models`, `Services/API`, `Services/Sync`, `Services/AI`, and the future shared error package into local SPM packages within the repo. Primary motivation: speed up incremental builds. Secondary benefit: enforce module boundaries so views cannot reach into an API client's internals. Do this early — every subsequent architecture item benefits from having packages to land in.

## Typed, User-Facing Error Model (as a Package)

Unify errors from `WiseAPIClient`, `MonobankAPIClient`, `CSVImporter`, etc. under a `WiseBudgetError` type with `LocalizedError` conformance, shipped as its own SPM package so every other module can depend on it without dragging the app target. UI shows actionable messages ("Monobank rate-limited, retry in 60s") instead of generic strings.

## Unified Logging via `os.Logger`

Standardize on `Logger(subsystem:category:)` across services (sync, rates, insights, keychain). Categories map to folders; Console.app filtering becomes trivial during debugging. Pairs well with the local-packages step — each package declares its own logger.

## Dependency Injection via `@Environment`

Move services out of ad-hoc instantiation / singletons and into `EnvironmentValues` using the `@Entry` macro. Tests and previews can then swap in fakes without changing call sites. Natural follow-up once the repository abstraction exists.

## Repository / Store Abstraction for SwiftData

Wrap `@Query` / `modelContext` reads and writes behind small per-entity stores (`ExpenseStore`, `BudgetStore`, etc.) — a common pattern for SwiftData apps that want testable services. Centralizes business rules like `baseCurrencyAmount` recalculation, and makes services mockable in tests without spinning up an in-memory `ModelContainer` every time.

## Reorganize the Dashboard Feature Folder

`Dashboard/` is becoming a catch-all (budget pacing, insights, averages, top categories, recent transactions). Give each section its own subfolder, matching the `Insights/` nesting already used. Cheap refactor, big readability win.
