import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        GeneralSettingsView()
            .frame(width: 500, height: 350)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Expense.self, Income.self], inMemory: true)
}
