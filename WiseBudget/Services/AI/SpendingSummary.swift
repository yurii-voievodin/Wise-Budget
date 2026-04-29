import Foundation

/// Compact, LLM-friendly snapshot of one month of spending.
/// Built on the Dashboard and rendered as a compact plain-text block for the
/// Foundation Models prompt. Plain text instead of JSON saves input tokens
/// (no braces, quotes, or repeated keys), which directly cuts time-to-first-token.
struct SpendingSummary: Codable, Sendable {
    struct CategoryTotal: Codable, Sendable {
        let name: String
        let amount: Double
        let percentOfExpenses: Double
    }

    /// One transaction line in the encoded prompt. Dates are deliberately
    /// omitted — the on-device model gets the most signal per token from the
    /// amount, category, and merchant/source label.
    struct LineItem: Codable, Sendable {
        let amount: Double       // unsigned magnitude
        let category: String
        let label: String?       // merchant / source / note, truncated
    }

    /// Pre-aggregated merchant statistics. Each merchant appears once with
    /// `count × total` already computed so the on-device model never has to
    /// sum rows or count occurrences (it gets those wrong).
    struct MerchantAggregate: Codable, Sendable {
        let canonicalKey: String        // e.g. "omv" — used for grouping only
        let displayLabel: String        // first non-empty original casing seen
        let count: Int
        let total: Double
        let averagePerCharge: Double    // total / count
        let categories: [String]        // unique, sorted
    }

    /// Two charges with the same merchant + category and similar amounts
    /// within the month — surfaces likely double-charges or data-entry errors
    /// (e.g. the same MacBook posted twice as €1200 and €1000).
    struct DuplicateGroup: Codable, Sendable {
        let displayLabel: String
        let category: String
        let representativeAmount: Double  // max amount in the group
        let count: Int                    // >= 2
    }

    let month: String           // e.g. "March 2026"
    let currency: String        // e.g. "EUR"
    let totalIncome: Double
    let totalExpenses: Double
    let balance: Double
    let transactionCount: Int
    let topCategories: [CategoryTotal]
    /// Raw income lines fed to the model so it can spot paycheck timing,
    /// irregular income, etc. Defaulted for the legacy memberwise initializer
    /// still used by tests that only care about totals.
    var incomes: [LineItem] = []
    /// Raw expense lines retained on the summary for callers that still want
    /// them (e.g. previews); the prompt no longer emits per-row data — see
    /// `recurringMerchants` and friends.
    var expenses: [LineItem] = []

    /// Merchants charged at least 3 times this month. Used to surface fuel,
    /// supermarket, and delivery patterns the model would otherwise miss.
    var recurringMerchants: [MerchantAggregate] = []
    /// Low-amount, low-variance recurring charges plus anything in the
    /// `Subscription` category. Distinct from `recurringMerchants` — a
    /// merchant in subscriptions is excluded from recurring to avoid double
    /// reporting.
    var subscriptionLikeCharges: [MerchantAggregate] = []
    /// Top single-occurrence expenses (by amount). Excludes anything that
    /// repeats — those belong in recurring/subscription sections.
    var largestOneOffs: [LineItem] = []
    /// Same merchant string appearing in 2+ different categories. Surfaces
    /// inconsistent categorisation (e.g. Pulse split between Medical and
    /// Groceries).
    var crossCategoryMerchants: [MerchantAggregate] = []
    /// Possible double-charges within the same merchant+category bucket.
    var possibleDuplicates: [DuplicateGroup] = []

    private static let labelMaxChars = 30
    /// Subscriptions are typically small recurring charges. Charges above
    /// this cap are treated as recurring purchases instead.
    private static let subscriptionAmountCap: Double = 25.0
    /// Subscription detection requires per-charge amounts to vary by at most
    /// this fraction from the mean (otherwise it's just an irregular
    /// purchase pattern).
    private static let subscriptionVarianceFraction: Double = 0.10
    private static let recurringMinCount: Int = 3
    private static let recurringMerchantCap: Int = 6
    private static let subscriptionMerchantCap: Int = 6
    /// Below this monthly total, an untagged subscription-like merchant is
    /// dropped from the prompt as noise — paying €2 in parking twice doesn't
    /// generate insight, it just eats tokens. Merchants explicitly tagged as
    /// "Subscription" are kept regardless of size.
    private static let subscriptionMinTotal: Double = 10.0
    private static let largestOneOffCap: Int = 5
    private static let crossCategoryCap: Int = 4
    private static let duplicateGroupCap: Int = 4
    /// Two charges with the same merchant+category whose amounts are within
    /// this fraction of each other are flagged as possible duplicates.
    private static let duplicateAmountTolerance: Double = 0.05
    /// For large amounts (≥ this threshold), use the wider tolerance below
    /// instead — catches the "MacBook posted twice as €1200/€1000" case.
    private static let largeAmountThreshold: Double = 500.0
    private static let largeAmountDuplicateTolerance: Double = 0.25

    func encodedAsPrompt() -> String {
        var lines: [String] = []
        lines.append("Month: \(month) (\(currency))")
        lines.append("Income: \(Self.formatAmount(totalIncome))")
        lines.append("Expenses: \(Self.formatAmount(totalExpenses))")
        lines.append("Balance: \(Self.formatAmount(balance))")
        let savingsPct = totalIncome > 0
            ? Int(((totalIncome - totalExpenses) / totalIncome * 100).rounded())
            : 0
        lines.append("Savings: \(savingsPct)%")
        lines.append("Transactions: \(transactionCount)")

        if !incomes.isEmpty {
            lines.append("")
            lines.append("Income sources:")
            for item in incomes.sorted(by: { $0.amount > $1.amount }) {
                lines.append(Self.renderLine(item, sign: "+"))
            }
        }

        if !topCategories.isEmpty {
            lines.append("")
            lines.append("Top spending categories:")
            for (idx, category) in topCategories.enumerated() {
                lines.append("\(idx + 1). \(category.name)  \(Self.formatAmount(category.amount)) (\(Self.formatPercent(category.percentOfExpenses))%)")
            }
        }

        if !recurringMerchants.isEmpty {
            lines.append("")
            lines.append("Recurring merchants (>=3 charges this month):")
            for merchant in recurringMerchants {
                lines.append(Self.renderMerchantLine(merchant))
            }
        }

        if !subscriptionLikeCharges.isEmpty {
            lines.append("")
            lines.append("Subscription-like charges:")
            for merchant in subscriptionLikeCharges {
                lines.append(Self.renderMerchantLine(merchant))
            }
        }

        if !largestOneOffs.isEmpty {
            lines.append("")
            lines.append("Largest one-off expenses:")
            for item in largestOneOffs {
                lines.append(Self.renderOneOffLine(item))
            }
        }

        if !crossCategoryMerchants.isEmpty {
            lines.append("")
            lines.append("Merchants split across categories:")
            for merchant in crossCategoryMerchants {
                let cats = merchant.categories.joined(separator: ", ")
                lines.append("- \(merchant.displayLabel): \(cats) (\(Self.formatAmount(merchant.total)) total over \(merchant.count) charges)")
            }
        }

        if !possibleDuplicates.isEmpty {
            lines.append("")
            lines.append("Possible duplicate or near-duplicate charges:")
            for group in possibleDuplicates {
                lines.append("- \(group.displayLabel) x \(group.count) ~ \(Self.formatAmount(group.representativeAmount))  (\(group.category))")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func renderLine(_ item: LineItem, sign: String) -> String {
        let label = item.label.map { "  \($0)" } ?? ""
        return "\(sign)\(formatAmount(item.amount))  \(item.category)\(label)"
    }

    private static func renderMerchantLine(_ merchant: MerchantAggregate) -> String {
        let category = merchant.categories.joined(separator: ", ")
        return "- \(merchant.displayLabel) x \(merchant.count) = \(formatAmount(merchant.total)) (avg \(formatAmount(merchant.averagePerCharge)))  (\(category))"
    }

    private static func renderOneOffLine(_ item: LineItem) -> String {
        let label = item.label.map { "  \($0)" } ?? ""
        return "- \(formatAmount(item.amount))  \(item.category)\(label)"
    }

    private static func formatAmount(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func formatPercent(_ value: Double) -> String {
        String(format: "%.0f", value)
    }

    var isEmpty: Bool {
        transactionCount == 0
    }
}

extension SpendingSummary {
    /// Builds a summary from raw expenses and incomes (grouping happens here).
    /// Used by the Dashboard, unit tests, and any caller that has the raw
    /// transactions on hand.
    static func build(
        monthFilter: MonthFilter,
        currency: String,
        expenses: [Expense],
        incomes: [Income],
        topCategoryLimit: Int = 8
    ) -> SpendingSummary {
        let totalIncome = incomes.reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: currency) ?? .zero) }
        let totalExpenses = expenses.reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: currency) ?? .zero) }

        let grouped = Dictionary(grouping: expenses) { $0.category?.name ?? "Uncategorized" }
        let slices: [CategoryChartSlice] = grouped.compactMap { name, items in
            let sum = items.reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: currency) ?? .zero) }
            guard sum > .zero else { return nil }
            return CategoryChartSlice(name: name, iconName: "", total: NSDecimalNumber(decimal: sum).doubleValue)
        }

        let incomeItems: [LineItem] = incomes.compactMap { income in
            let amount = NSDecimalNumber(decimal: income.convertedAmount(to: currency) ?? .zero).doubleValue
            guard amount > 0 else { return nil }
            return LineItem(
                amount: amount,
                category: income.category?.name ?? "Uncategorized",
                label: trimmedLabel(income.source, fallback: income.descriptionText)
            )
        }

        let expenseItems: [LineItem] = expenses.compactMap { expense in
            let amount = NSDecimalNumber(decimal: expense.convertedAmount(to: currency) ?? .zero).doubleValue
            guard amount > 0 else { return nil }
            return LineItem(
                amount: amount,
                category: expense.category?.name ?? "Uncategorized",
                label: trimmedLabel(expense.destination, fallback: expense.descriptionText)
            )
        }

        return build(
            monthFilter: monthFilter,
            currency: currency,
            totalIncome: NSDecimalNumber(decimal: totalIncome).doubleValue,
            totalExpenses: NSDecimalNumber(decimal: totalExpenses).doubleValue,
            transactionCount: expenses.count + incomes.count,
            expenseSlices: slices,
            incomes: incomeItems,
            expenses: expenseItems,
            topCategoryLimit: topCategoryLimit
        )
    }

    /// Builds a summary from already-computed totals and category slices, plus
    /// optional raw transaction lines. Preferred when the caller (e.g. the
    /// Dashboard) has already grouped the data for charts.
    static func build(
        monthFilter: MonthFilter,
        currency: String,
        totalIncome: Double,
        totalExpenses: Double,
        transactionCount: Int,
        expenseSlices: [CategoryChartSlice],
        incomes: [LineItem] = [],
        expenses: [LineItem] = [],
        topCategoryLimit: Int = 8
    ) -> SpendingSummary {
        let categoryTotals: [CategoryTotal] = expenseSlices
            .sorted { $0.total > $1.total }
            .prefix(topCategoryLimit)
            .map { slice in
                let pct = totalExpenses > 0 ? slice.total / totalExpenses * 100 : 0
                return CategoryTotal(name: slice.name, amount: slice.total, percentOfExpenses: pct)
            }

        let bundle = computeAggregates(from: expenses)

        var summary = SpendingSummary(
            month: monthLabel(for: monthFilter),
            currency: currency,
            totalIncome: totalIncome,
            totalExpenses: totalExpenses,
            balance: totalIncome - totalExpenses,
            transactionCount: transactionCount,
            topCategories: categoryTotals,
            incomes: incomes,
            expenses: expenses
        )
        summary.recurringMerchants = bundle.recurring
        summary.subscriptionLikeCharges = bundle.subscriptions
        summary.largestOneOffs = bundle.oneOffs
        summary.crossCategoryMerchants = bundle.crossCategory
        summary.possibleDuplicates = bundle.duplicates
        return summary
    }

    private static func monthLabel(for filter: MonthFilter) -> String {
        filter.startOfMonth.formatted(.dateTime.month(.wide).year())
    }

    private static func trimmedLabel(_ primary: String?, fallback: String?) -> String? {
        let raw = (primary ?? fallback)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return nil }
        return String(raw.prefix(Self.labelMaxChars))
    }

    /// Canonicalises a merchant label so variants like "OMV", "OMV TANK 482",
    /// and "omv-bratislava" group together. Returns `nil` for empty labels.
    /// Falls back to lowercased+trimmed if no `MerchantCategoryMapping` rule
    /// matches.
    static func canonicalMerchantKey(_ raw: String?) -> (key: String, display: String)? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        let lowered = trimmed.lowercased()
        if let matched = MerchantCategoryMapping.rules.first(where: { lowered.contains($0.keyword) }) {
            return (matched.keyword, trimmed)
        }
        return (lowered, trimmed)
    }
}

// MARK: - Aggregations

extension SpendingSummary {
    fileprivate struct AggregateBundle {
        var recurring: [MerchantAggregate]
        var subscriptions: [MerchantAggregate]
        var oneOffs: [LineItem]
        var crossCategory: [MerchantAggregate]
        var duplicates: [DuplicateGroup]
    }

    fileprivate struct MerchantBucket {
        let canonicalKey: String
        var displayLabel: String
        var amounts: [Double] = []
        var categories: [String] = []
    }

    fileprivate static func computeAggregates(from expenses: [LineItem]) -> AggregateBundle {
        let buckets = bucketsByMerchant(expenses)

        let recurring = buildRecurringMerchants(buckets: buckets)
        let recurringKeys = Set(recurring.map(\.canonicalKey))
        let subscriptions = buildSubscriptionLikeCharges(buckets: buckets, excluding: recurringKeys)

        let repeatingKeys = Set(
            buckets.values.filter { $0.amounts.count >= 2 }.map(\.canonicalKey)
        )
        let oneOffs = buildLargestOneOffs(expenses: expenses, repeatingKeys: repeatingKeys)
        let crossCategory = buildCrossCategoryMerchants(buckets: buckets)
        // Recurring merchants are already a known pattern — flagging two
        // close-priced fill-ups at OMV as "possible duplicate" is noise.
        let duplicates = buildPossibleDuplicates(expenses: expenses, excluding: recurringKeys)

        return AggregateBundle(
            recurring: recurring,
            subscriptions: subscriptions,
            oneOffs: oneOffs,
            crossCategory: crossCategory,
            duplicates: duplicates
        )
    }

    private static func bucketsByMerchant(_ expenses: [LineItem]) -> [String: MerchantBucket] {
        var buckets: [String: MerchantBucket] = [:]
        for item in expenses {
            guard let canonical = canonicalMerchantKey(item.label) else { continue }
            var bucket = buckets[canonical.key] ?? MerchantBucket(
                canonicalKey: canonical.key,
                displayLabel: canonical.display
            )
            bucket.amounts.append(item.amount)
            if !bucket.categories.contains(item.category) {
                bucket.categories.append(item.category)
            }
            buckets[canonical.key] = bucket
        }
        return buckets
    }

    private static func buildRecurringMerchants(buckets: [String: MerchantBucket]) -> [MerchantAggregate] {
        buckets.values
            .filter { $0.amounts.count >= recurringMinCount }
            .map { aggregateFrom($0) }
            .sorted { $0.total > $1.total }
            .prefix(recurringMerchantCap)
            .map { $0 }
    }

    private static func buildSubscriptionLikeCharges(
        buckets: [String: MerchantBucket],
        excluding excludedKeys: Set<String>
    ) -> [MerchantAggregate] {
        buckets.values
            .filter { !excludedKeys.contains($0.canonicalKey) }
            .filter { isSubscriptionLike($0) }
            .map { aggregateFrom($0) }
            // Drop tiny untagged charges (e.g. two €1 parkings); keep anything
            // tagged "Subscription" no matter how small — the user wants to
            // see those.
            .filter { $0.total >= subscriptionMinTotal || $0.categories.contains("Subscription") }
            .sorted { $0.total > $1.total }
            .prefix(subscriptionMerchantCap)
            .map { $0 }
    }

    private static func isSubscriptionLike(_ bucket: MerchantBucket) -> Bool {
        // Anything tagged in the user's `Subscription` category counts.
        if bucket.categories.contains("Subscription") {
            return true
        }
        guard bucket.amounts.count >= 2,
              let maxAmount = bucket.amounts.max(),
              let minAmount = bucket.amounts.min(),
              maxAmount <= subscriptionAmountCap else {
            return false
        }
        let mean = bucket.amounts.reduce(0, +) / Double(bucket.amounts.count)
        guard mean > 0 else { return false }
        let variance = (maxAmount - minAmount) / mean
        return variance <= subscriptionVarianceFraction
    }

    private static func buildLargestOneOffs(
        expenses: [LineItem],
        repeatingKeys: Set<String>
    ) -> [LineItem] {
        expenses
            .filter { item in
                guard let canonical = canonicalMerchantKey(item.label) else {
                    // No merchant string — keep as one-off (it's a single row by definition).
                    return true
                }
                return !repeatingKeys.contains(canonical.key)
            }
            .sorted { $0.amount > $1.amount }
            .prefix(largestOneOffCap)
            .map { $0 }
    }

    private static func buildCrossCategoryMerchants(buckets: [String: MerchantBucket]) -> [MerchantAggregate] {
        buckets.values
            .filter { $0.categories.count >= 2 && $0.amounts.count >= 2 }
            .map { aggregateFrom($0) }
            .sorted { $0.total > $1.total }
            .prefix(crossCategoryCap)
            .map { $0 }
    }

    private static func buildPossibleDuplicates(
        expenses: [LineItem],
        excluding excludedKeys: Set<String>
    ) -> [DuplicateGroup] {
        struct GroupKey: Hashable {
            let canonicalKey: String
            let category: String
        }
        var byMerchantCategory: [GroupKey: [LineItem]] = [:]
        var displayByKey: [String: String] = [:]
        for item in expenses {
            guard let canonical = canonicalMerchantKey(item.label) else { continue }
            if excludedKeys.contains(canonical.key) { continue }
            let key = GroupKey(canonicalKey: canonical.key, category: item.category)
            byMerchantCategory[key, default: []].append(item)
            displayByKey[canonical.key] = displayByKey[canonical.key] ?? canonical.display
        }

        var groups: [DuplicateGroup] = []
        for (key, items) in byMerchantCategory {
            guard items.count >= 2 else { continue }
            let sorted = items.sorted { $0.amount > $1.amount }
            var bucket: [LineItem] = []
            for item in sorted {
                if let last = bucket.last, isWithinDuplicateTolerance(item.amount, last.amount) {
                    bucket.append(item)
                } else {
                    appendIfDuplicate(
                        bucket: bucket,
                        displayLabel: displayByKey[key.canonicalKey] ?? "(unknown)",
                        category: key.category,
                        into: &groups
                    )
                    bucket = [item]
                }
            }
            appendIfDuplicate(
                bucket: bucket,
                displayLabel: displayByKey[key.canonicalKey] ?? "(unknown)",
                category: key.category,
                into: &groups
            )
        }
        return groups
            .sorted { $0.representativeAmount > $1.representativeAmount }
            .prefix(duplicateGroupCap)
            .map { $0 }
    }

    private static func appendIfDuplicate(
        bucket: [LineItem],
        displayLabel: String,
        category: String,
        into groups: inout [DuplicateGroup]
    ) {
        guard bucket.count >= 2 else { return }
        let representative = bucket.map(\.amount).max() ?? 0
        groups.append(
            DuplicateGroup(
                displayLabel: displayLabel,
                category: category,
                representativeAmount: representative,
                count: bucket.count
            )
        )
    }

    private static func isWithinDuplicateTolerance(_ a: Double, _ b: Double) -> Bool {
        let larger = max(a, b)
        guard larger > 0 else { return false }
        let delta = abs(a - b) / larger
        let tolerance = larger >= largeAmountThreshold ? largeAmountDuplicateTolerance : duplicateAmountTolerance
        return delta <= tolerance
    }

    private static func aggregateFrom(_ bucket: MerchantBucket) -> MerchantAggregate {
        let total = bucket.amounts.reduce(0, +)
        let count = bucket.amounts.count
        return MerchantAggregate(
            canonicalKey: bucket.canonicalKey,
            displayLabel: bucket.displayLabel,
            count: count,
            total: total,
            averagePerCharge: count > 0 ? total / Double(count) : 0,
            categories: bucket.categories.sorted()
        )
    }
}
