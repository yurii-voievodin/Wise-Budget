import SwiftUI
import SwiftData

struct BudgetEmptyStateView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]
    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    let filter: MonthFilter

    private var previousMonthFilter: MonthFilter {
        var year = filter.year
        var month = filter.month - 1
        if month < 1 { month = 12; year -= 1 }
        return MonthFilter(year: year, month: month)
    }

    private var hasPreviousMonthPlan: Bool {
        let prevYear = previousMonthFilter.year
        let prevMonth = previousMonthFilter.month
        let descriptor = FetchDescriptor<BudgetPlan>(predicate: #Predicate {
            $0.year == prevYear && $0.month == prevMonth
        })
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Budget Plan")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Create a budget plan for \(filter.startOfMonth.formatted(.dateTime.month(.wide).year())) to track your spending goals.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button {
                    copyFromPreviousMonth()
                } label: {
                    Label("Copy from Previous Month", systemImage: "doc.on.doc")
                }
                .disabled(!hasPreviousMonthPlan)

                Button {
                    createEmptyBudget()
                } label: {
                    Label("Create Empty Budget", systemImage: "plus")
                }
            }
            .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func createEmptyBudget() {
        let plan = BudgetPlan(year: filter.year, month: filter.month, currency: defaultCurrency)
        modelContext.insert(plan)
        for category in categories {
            let item = BudgetPlanItem(plannedAmount: 0, plan: plan, category: category)
            modelContext.insert(item)
        }
    }

    private func copyFromPreviousMonth() {
        let prevYear = previousMonthFilter.year
        let prevMonth = previousMonthFilter.month
        let descriptor = FetchDescriptor<BudgetPlan>(predicate: #Predicate {
            $0.year == prevYear && $0.month == prevMonth
        })
        guard let previousPlan = try? modelContext.fetch(descriptor).first else { return }

        let newPlan = BudgetPlan(year: filter.year, month: filter.month, currency: previousPlan.currency, monthlyBudget: previousPlan.monthlyBudget ?? Decimal.zero)
        modelContext.insert(newPlan)

        let validIds = Set(categories.map(\.persistentModelID))
        for prevItem in previousPlan.items {
            guard let category = prevItem.category,
                  validIds.contains(category.persistentModelID) else { continue }
            let item = BudgetPlanItem(plannedAmount: prevItem.plannedAmount, plan: newPlan, category: category)
            modelContext.insert(item)
        }
    }
}
