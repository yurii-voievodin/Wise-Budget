# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build
xcodebuild build -project "Wise Budget.xcodeproj" -scheme "Wise Budget"

# Run all tests (unit + UI)
xcodebuild test -project "Wise Budget.xcodeproj" -scheme "Wise Budget"
```

## Architecture

- **Platform:** macOS (deployment target 26.2)
- **UI:** SwiftUI with `NavigationSplitView` layout
- **Data:** SwiftData with `@Model`, `@Query`, `@Environment(\.modelContext)`
- **Swift version:** 5.0
- **No external dependencies**

### Targets

| Target | Purpose |
|---|---|
| `Wise Budget` | Main app (`Wise_BudgetApp.swift` entry point) |
| `Wise BudgetTests` | Unit tests using Swift Testing (`@Test` macro) |
| `Wise BudgetUITests` | UI tests using XCTest |

### Data Layer

SwiftData `ModelContainer` is configured at the app level in `Wise_BudgetApp.swift` and injected into the view hierarchy. Models live alongside views in the main target (e.g., `Item.swift`).
