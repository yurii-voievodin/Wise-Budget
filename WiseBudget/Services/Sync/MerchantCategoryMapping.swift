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
        for rule in rules {
            if lowered.contains(rule.keyword) {
                return rule.category
            }
        }
        return nil
    }

    // MARK: - Rules

    /// Each rule is a (keyword, category) pair. Keywords are lowercase.
    /// More specific keywords should come before generic ones.
    static let rules: [(keyword: String, category: String)] = {
        var r = [(String, String)]()
        
        // ── Other ────────────────────────────────────────────
        r += [
            ("barber", "Other"),
            ("claude", "Other"),
        ]

        // ── Auto / Transport ────────────────────────────────────────────
        r += [
            ("omv", "Auto"),
            ("shell", "Auto"),
            ("mol", "Auto"),
            ("bp", "Auto"),
            ("eni", "Auto"),
            ("uno-x", "Auto"),
            ("orlen", "Auto"),
            ("uber", "Auto"),
            ("intercity", "Auto"),
            ("ecombustibil", "Auto"),
            ("parking", "Auto"),
            ("urbo city", "Auto"),
            ("e vignette", "Auto"),
            ("wipark", "Auto"),
            ("raxseilbahn", "Auto"),
            ("jakdojade", "Auto"),
            ("pavimental", "Auto"),
            ("bolt", "Auto"),
            ("taxi", "Auto"),
            ("balice", "Auto"),
            ("km-prona", "Auto"),
            ("global technology", "Auto")
        ]

        // ── Groceries ───────────────────────────────────────────────────
        r += [
            ("kaufland", "Groceries"),
            ("lidl", "Groceries"),
            ("billa", "Groceries"),
            ("profi", "Groceries"),
            ("spar", "Groceries"),
            ("carrefour", "Groceries"),
            ("aldi", "Groceries"),
            ("żabka", "Groceries"),
            ("zabka", "Groceries"),
            ("my market", "Groceries"),
            ("lajkonik", "Groceries"),
            ("beryozka", "Groceries")
        ]

        // ── Cafes / Restaurants ─────────────────────────────────────────
        r += [
            ("mcdonald", "Cafes"),
            ("glovo", "Cafes"),
            ("costa coffee", "Cafes"),
            ("starbucks", "Cafes"),
            ("san domenico", "Cafes"),
            ("bistro gourmet", "Cafes"),
            ("doraz cafe", "Cafes"),
            ("asia food", "Cafes"),
            ("rispetto", "Cafes"),
            ("great taste", "Cafes"),
            ("all inclusive", "Cafes"),
            ("lari 2014", "Cafes"),
            ("sztolnia", "Cafes"),
            ("karpiel bistro", "Cafes"),
            ("kahlon brasseri", "Cafes"),
            ("la flor bar", "Cafes"),
            ("amrest", "Cafes"),
            ("trdelnik", "Cafes"),
            ("ratatui", "Cafes"),
            ("kreativ hab", "Cafes"),
            ("creative hub", "Cafes"),
            ("patsi bar", "Cafes"),
            ("nakielny", "Cafes"),
            ("tivat eood", "Cafes"),
            ("rtf eood", "Cafes"),
        ]

        // ── Shopping ────────────────────────────────────────────────────
        r += [
            ("uniqlo", "Shopping"),
            ("zara", "Shopping"),
            ("stradivarius", "Shopping"),
            ("diverse", "Shopping"),
            ("pepco", "Shopping"),
            ("dji", "Shopping"),
            ("ikea", "Shopping"),
            ("intertop", "Shopping"),
            ("praktiker", "Shopping"),
            ("teknopolis", "Shopping"),
            ("технополис", "Shopping"),
            ("технополіс", "Shopping"),
            ("levi store", "Shopping"),
            ("apple", "Shopping"),
            
            ("carvertical", "Shopping"),
        ]

        // ── Personal Items ──────────────────────────────────────────────
        r += [
            ("rossmann", "Personal Items"),
            ("apteka", "Personal Items"),
            ("medicover", "Personal Items"),
            ("garmin", "Personal Items"),
        ]

        // ── Travel ──────────────────────────────────────────────────────
        r += [
            ("booking.com", "Travel"),
            ("hotel", "Travel"),
            ("airbnb", "Travel"),
            ("Такси", "Travel")
        ]

        // ── Entertainment ───────────────────────────────────────────────
        r += [
            ("megogo", "Entertainment"),
            ("youtube", "Entertainment"),
            ("netflix", "Entertainment"),
            ("spotify", "Entertainment"),
            ("sparkys", "Entertainment"),
        ]

        // ── Utilities ───────────────────────────────────────────────────
        r += [
            ("vivacom", "Utilities"),
            ("epay", "Utilities"),
            ("doladowania play", "Utilities"),
            ("vintrica", "Utilities"),
            ("київстар", "Utilities"),
            ("kyivstar", "Utilities"),
        ]
        
        // ── Medical ───────────────────────────────────────────────────
        r += [
            ("pulse", "Medical"),
        ]
        

        return r
    }()
}
