//
//  Item.swift
//  Wise Budget
//
//  Created by Yurii Voievodin on 17/03/2026.
//

import Foundation
import SwiftData

enum ItemCategory: String, Codable {
    case expense
    case income
}

@Model
final class Item {
    var timestamp: Date
    var category: ItemCategory
    
    init(timestamp: Date, category: ItemCategory) {
        self.timestamp = timestamp
        self.category = category
    }
}
