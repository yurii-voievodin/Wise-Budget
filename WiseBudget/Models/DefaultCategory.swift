import Foundation
import SwiftUI

nonisolated enum DefaultExpenseCategory: String, CaseIterable {
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

    var chartColor: Color {
        switch self {
        case .auto:          Color(red: 74/255, green: 144/255, blue: 217/255)  // #4A90D9 steel blue
        case .cafes:         Color(red: 232/255, green: 131/255, blue: 58/255)  // #E8833A warm orange
        case .entertainment: Color(red: 155/255, green: 89/255, blue: 182/255)  // #9B59B6 rich purple
        case .groceries:     Color(red: 46/255, green: 204/255, blue: 113/255)  // #2ECC71 fresh green
        case .home:          Color(red: 244/255, green: 197/255, blue: 66/255)  // #F4C542 golden yellow
        case .medical:       Color(red: 231/255, green: 76/255, blue: 60/255)   // #E74C3C red
        case .other:         Color(red: 121/255, green: 134/255, blue: 203/255) // #7986CB soft indigo
        case .personalItems: Color(red: 232/255, green: 67/255, blue: 147/255)  // #E84393 magenta pink
        case .shopping:      Color(red: 243/255, green: 156/255, blue: 18/255)  // #F39C12 amber
        case .subscription:  Color(red: 108/255, green: 92/255, blue: 231/255)  // #6C5CE7 indigo
        case .taxes:         Color(red: 99/255, green: 110/255, blue: 114/255)  // #636E72 dark slate
        case .travel:        Color(red: 0/255, green: 184/255, blue: 148/255)   // #00B894 teal
        case .utilities:     Color(red: 9/255, green: 132/255, blue: 227/255)   // #0984E3 strong blue
        }
    }

    static var chartColorMap: [String: Color] {
        var map: [String: Color] = [:]
        for category in Self.allCases {
            map[category.rawValue] = category.chartColor
        }
        map["Uncategorized"] = Color(red: 149/255, green: 165/255, blue: 166/255)
        return map
    }

    static var chartColorDomain: [String] {
        Self.allCases.map(\.rawValue) + ["Uncategorized"]
    }

    static var chartColorRange: [Color] {
        Self.allCases.map(\.chartColor) + [Color(red: 149/255, green: 165/255, blue: 166/255)]
    }

    static func sortIndex(for name: String) -> Int {
        Self.allCases.firstIndex { $0.rawValue == name }.map { Int($0) } ?? Self.allCases.count
    }
}

nonisolated enum DefaultIncomeCategory: String, CaseIterable {
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

    var chartColor: Color {
        switch self {
        case .freelance:    Color(red: 162/255, green: 155/255, blue: 254/255) // #A29BFE soft lavender
        case .gifts:        Color(red: 253/255, green: 121/255, blue: 168/255) // #FD79A8 soft rose
        case .investments:  Color(red: 0/255, green: 206/255, blue: 201/255)   // #00CEC9 cyan
        case .other:        Color(red: 178/255, green: 190/255, blue: 195/255) // #B2BEC3 light gray
        case .rental:       Color(red: 253/255, green: 203/255, blue: 110/255) // #FDCB6E soft gold
        case .salary:       Color(red: 85/255, green: 239/255, blue: 196/255)  // #55EFC4 mint green
        }
    }

    static var chartColorMap: [String: Color] {
        var map: [String: Color] = [:]
        for category in Self.allCases {
            map[category.rawValue] = category.chartColor
        }
        map["Uncategorized"] = Color(red: 178/255, green: 190/255, blue: 195/255)
        return map
    }

    static func sortIndex(for name: String) -> Int {
        Self.allCases.firstIndex { $0.rawValue == name }.map { Int($0) } ?? Self.allCases.count
    }
}
