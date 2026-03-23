import Foundation

enum DefaultExpenseCategory: String, CaseIterable {
    case auto = "Auto"
    case cafes = "Cafes"
    case entertainment = "Entertainment"
    case groceries = "Groceries"
    case home = "Home"
    case medical = "Medical"
    case other = "Other"
    case personalItems = "Personal Items"
    case shopping = "Shopping"
    case subscription = "Subscription"
    case taxes = "Taxes"
    case travel = "Travel"
    case utilities = "Utilities"

    var iconName: String {
        switch self {
        case .auto: "car"
        case .cafes: "cup.and.saucer"
        case .entertainment: "film"
        case .groceries: "cart"
        case .home: "house"
        case .medical: "cross.case"
        case .other: "ellipsis.circle"
        case .personalItems: "bag"
        case .shopping: "bag"
        case .subscription: "repeat"
        case .taxes: "doc.text"
        case .travel: "airplane"
        case .utilities: "bolt"
        }
    }
}

enum DefaultIncomeCategory: String, CaseIterable {
    case freelance = "Freelance"
    case gifts = "Gifts"
    case investments = "Investments"
    case other = "Other"
    case rental = "Rental"
    case salary = "Salary"

    var iconName: String {
        switch self {
        case .freelance: "laptopcomputer"
        case .gifts: "gift"
        case .investments: "chart.line.uptrend.xyaxis"
        case .other: "ellipsis.circle"
        case .rental: "key"
        case .salary: "banknote"
        }
    }
}
