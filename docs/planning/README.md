# Planning

This folder is the single home for forward-looking work on WiseBudget. Edit freely — every paragraph is intentionally self-contained so you can add, remove, or reshape ideas without touching neighbors.

## Files

- [`FEATURES.md`](FEATURES.md) — accepted candidate features, in rough priority order. Add new ideas at the bottom (or in the appropriate priority slot); delete anything that ships.
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — accepted architecture / code-health proposals, priority-first.
- [`DECISIONS.md`](DECISIONS.md) — rejected or deferred ideas with a one-line rationale. **Do not silently drop an idea** — move it here so future-you remembers why.

## Conventions

- **One paragraph per idea.** Keep each item readable in isolation.
- **Priority** lives at the top of each file. Unordered items sit below.
- **When rejecting or deferring an accepted item**, move the paragraph into `DECISIONS.md` rather than deleting it.
- **Dates** use absolute form (`YYYY-MM-DD`), not relative ("next month").

## For Claude / agents

Before suggesting a new feature or architectural change, read all three files. Re-proposing something in `DECISIONS.md` is noise — extend it with a new entry or push back on the decision explicitly instead.
