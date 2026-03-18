import SwiftUI
import SwiftData

struct EditBudgetPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    let plan: BudgetPlan
    let categories: [ExpenseCategory]

    @State private var amounts: [PersistentIdentifier: Decimal] = [:]
    @State private var showResetConfirmation = false

    private var currencyLabel: String {
        plan.currency ?? defaultCurrency
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text(plan.displayTitle)
                    .fontWeight(.semibold)
                Spacer()
                Button("Save") { save() }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(categories) { category in
                        HStack {
                            Text(category.name)
                                .frame(width: 140, alignment: .leading)
                            TextField(
                                "0",
                                value: binding(for: category),
                                format: .number
                            )
                            .textFieldStyle(.roundedBorder)
                            Text(currencyLabel)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        Divider()
                    }

                    Button("Reset Plan", role: .destructive) {
                        showResetConfirmation = true
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 400)
        .confirmationDialog(
            "Reset Plan",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Plan", role: .destructive) {
                resetPlan()
            }
        } message: {
            Text("This will reset all planned amounts to zero and update the currency to \(defaultCurrency).")
        }
        .onAppear {
            for item in plan.items {
                if let cat = item.category {
                    amounts[cat.persistentModelID] = item.plannedAmount
                }
            }
        }
    }

    private func binding(for category: ExpenseCategory) -> Binding<Decimal> {
        Binding(
            get: { amounts[category.persistentModelID] ?? Decimal.zero },
            set: { amounts[category.persistentModelID] = $0 }
        )
    }

    private func resetPlan() {
        plan.currency = defaultCurrency
        for key in amounts.keys {
            amounts[key] = Decimal.zero
        }
        for item in plan.items {
            item.plannedAmount = Decimal.zero
        }
    }

    private func save() {
        for category in categories {
            let amount = amounts[category.persistentModelID] ?? Decimal.zero
            if let existing = plan.items.first(where: {
                $0.category?.persistentModelID == category.persistentModelID
            }) {
                existing.plannedAmount = amount
            } else {
                let item = BudgetPlanItem(plannedAmount: amount, plan: plan, category: category)
                modelContext.insert(item)
            }
        }
        dismiss()
    }
}
#Preview {
    let container = PreviewSampleData.container
    let context = container.mainContext
    let plan = try! context.fetch(FetchDescriptor<BudgetPlan>()).first!
    let categories = try! context.fetch(FetchDescriptor<ExpenseCategory>(sortBy: [SortDescriptor(\.name)])) 
    return EditBudgetPlanSheet(plan: plan, categories: categories)
        .modelContainer(container)
}

