import SwiftUI
import SwiftData

struct IncomeCategorySettingsView: View {
    @Query(sort: \IncomeCategory.name) private var categories: [IncomeCategory]

    var body: some View {
        CategorySettingsContent(categories: categories)
    }
}
