import SwiftUI
import SwiftData

enum SettingsTab: Int {
    case general
    case connections
}

struct SettingsView: View {
    @AppStorage("selectedSettingsTab") private var selectedTab: Int = SettingsTab.general.rawValue

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsTab.general.rawValue)

            BankConnectionsView()
                .tabItem {
                    Label("Connections", systemImage: "link")
                }
                .tag(SettingsTab.connections.rawValue)
        }
        .frame(width: 500, height: 350)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Expense.self, Income.self], inMemory: true)
}
