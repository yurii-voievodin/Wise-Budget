import SwiftUI
import SwiftData

struct EditBudgetPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let plan: BudgetPlan
    let categories: [ExpenseCategory]

    @State private var amounts: [PersistentIdentifier: Decimal] = [:]

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

            List {
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
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 400)
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
