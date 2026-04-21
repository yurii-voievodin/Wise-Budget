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
