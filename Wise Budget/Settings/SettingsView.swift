import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            BankConnectionsView()
                .tabItem {
                    Label("Connections", systemImage: "link")
                }
        }
        .frame(width: 500, height: 350)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Expense.self, Income.self], inMemory: true)
}
