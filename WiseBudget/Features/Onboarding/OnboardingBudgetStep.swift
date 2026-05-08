import SwiftUI
import SwiftData

struct OnboardingBudgetStep: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]
    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback

    @State private var didCreatePlan = false

    private var currentMonth: MonthFilter { .currentMonth() }

    private var hasCurrentPlan: Bool {
        let year = currentMonth.year
        let month = currentMonth.month
        let descriptor = FetchDescriptor<BudgetPlan>(predicate: #Predicate {
            $0.year == year && $0.month == month
        })
        return ((try? modelContext.fetchCount(descriptor)) ?? 0) > 0
    }

    var body: some View {
        OnboardingStepLayout(
            icon: "chart.pie.fill",
            iconColor: .orange,
            title: "Set up your first budget",
            subtitle: "Plan how much you want to spend per category this month. WiseBudget tracks pacing on the Dashboard so you spot drift early."
        ) {
            VStack(spacing: 12) {
                if hasCurrentPlan || didCreatePlan {
                    Label("Budget plan ready for \(currentMonth.startOfMonth.formatted(.dateTime.month(.wide).year()))", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Button {
                        createEmptyBudget()
                    } label: {
                        Label("Create budget for this month", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)

                    Text("You can also skip this — open Budget Plan from the sidebar any time to set one up.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: 380)
        }
    }

    private func createEmptyBudget() {
        let plan = BudgetPlan(year: currentMonth.year, month: currentMonth.month, currency: defaultCurrency)
        modelContext.insert(plan)
        for category in categories {
            let item = BudgetPlanItem(plannedAmount: 0, plan: plan, category: category)
            modelContext.insert(item)
        }
        didCreatePlan = true
    }
}

#Preview {
    OnboardingBudgetStep()
        .modelContainer(PreviewSampleData.container)
        .frame(width: 580, height: 460)
}
