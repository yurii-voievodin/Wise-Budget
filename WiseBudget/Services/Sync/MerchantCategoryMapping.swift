import Foundation

/// Maps merchant names to app category names using keyword matching.
/// Used by WiseSyncService to categorize card transactions from the Activities API,
/// which doesn't provide MCC codes or categories.
///
/// To add new rules: append a `(keyword, category)` tuple to the appropriate section.
/// Keywords are matched case-insensitively via `contains`.
/// Rules are evaluated top-to-bottom — put more specific keywords before generic ones.
enum MerchantCategoryMapping {

    /// Returns a category name for the given merchant name, or nil if no rule matches.
    static func category(for merchantName: String) -> String? {
        let lowered = merchantName.lowercased()
        return rules.first(where: { lowered.contains($0.keyword) })?.category.rawValue
    }

    // MARK: - Rules

    /// Each rule is a (keyword, category) pair. Keywords are lowercase.
    /// More specific keywords should come before generic ones.
    static let rules: [(keyword: String, category: DefaultExpenseCategory)] = {
        var r = [(String, DefaultExpenseCategory)]()
        
        // ── Other ────────────────────────────────────────────
        r += [
            ("barber", .other),
        ]

        // ── Auto / Transport ────────────────────────────────────────────
        r += [
            ("omv", .auto),
            ("shell", .auto),
            ("mol", .auto),
            ("bp", .auto),
            ("eni", .auto),
            ("uno-x", .auto),
            ("orlen", .auto),
            ("uber", .auto),
            ("intercity", .auto),
            ("ecombustibil", .auto),
            ("parking", .auto),
            ("urbo city", .auto),
            ("e vignette", .auto),
            ("wipark", .auto),
            ("raxseilbahn", .auto),
            ("jakdojade", .auto),
            ("pavimental", .auto),
            ("bolt", .auto),
            ("taxi", .auto),
            ("balice", .auto),
            ("km-prona", .auto),
            ("global technology", .auto)
        ]

        // ── Groceries ───────────────────────────────────────────────────
        r += [
            ("kaufland", .groceries),
            ("lidl", .groceries),
            ("billa", .groceries),
            ("profi", .groceries),
            ("spar", .groceries),
            ("carrefour", .groceries),
            ("aldi", .groceries),
            ("żabka", .groceries),
            ("zabka", .groceries),
            ("my market", .groceries),
            ("lajkonik", .groceries),
            ("beryozka", .groceries)
        ]

        // ── Cafes / Restaurants ─────────────────────────────────────────
        r += [
            ("mcdonald", .cafes),
            ("glovo", .cafes),
            ("costa coffee", .cafes),
            ("starbucks", .cafes),
            ("san domenico", .cafes),
            ("bistro gourmet", .cafes),
            ("doraz cafe", .cafes),
            ("asia food", .cafes),
            ("rispetto", .cafes),
            ("great taste", .cafes),
            ("all inclusive", .cafes),
            ("lari 2014", .cafes),
            ("sztolnia", .cafes),
            ("karpiel bistro", .cafes),
            ("kahlon brasseri", .cafes),
            ("la flor bar", .cafes),
            ("amrest", .cafes),
            ("trdelnik", .cafes),
            ("ratatui", .cafes),
            ("kreativ hab", .cafes),
            ("creative hub", .cafes),
            ("patsi bar", .cafes),
            ("nakielny", .cafes),
            ("tivat eood", .cafes),
            ("rtf eood", .cafes),
        ]

        // ── Shopping ────────────────────────────────────────────────────
        r += [
            ("uniqlo", .shopping),
            ("zara", .shopping),
            ("stradivarius", .shopping),
            ("diverse", .shopping),
            ("pepco", .shopping),
            ("dji", .shopping),
            ("ikea", .shopping),
            ("intertop", .shopping),
            ("praktiker", .shopping),
            ("teknopolis", .shopping),
            ("технополис", .shopping),
            ("технополіс", .shopping),
            ("levi store", .shopping),
            ("apple", .shopping),
            ("carvertical", .shopping),
        ]

        // ── Personal Items ──────────────────────────────────────────────
        r += [
            ("rossmann", .personalItems),
            ("apteka", .personalItems),
            ("medicover", .personalItems),
            ("garmin", .personalItems),
        ]

        // ── Travel ──────────────────────────────────────────────────────
        r += [
            ("booking.com", .travel),
            ("hotel", .travel),
            ("airbnb", .travel),
            ("Такси", .travel)
        ]

        // ── Entertainment ───────────────────────────────────────────────
        r += [
            ("sparkys", .entertainment),
        ]

        // ── Subscription ────────────────────────────────────────────────
        r += [
            ("claude", .subscription),
            ("megogo", .subscription),
            ("youtube", .subscription),
            ("netflix", .subscription),
            ("spotify", .subscription),
        ]

        // ── Utilities ───────────────────────────────────────────────────
        r += [
            ("vivacom", .utilities),
            ("epay", .utilities),
            ("doladowania play", .utilities),
            ("vintrica", .utilities),
            ("київстар", .utilities),
            ("kyivstar", .utilities),
        ]
        
        // ── Medical ───────────────────────────────────────────────────
        r += [
            ("pulse", .medical),
        ]
        

        return r
    }()
}
