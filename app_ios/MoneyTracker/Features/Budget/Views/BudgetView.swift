import SwiftUI

/// Budget tab (APP_FLOWS Flow 6).
struct BudgetView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: BudgetViewModel
    @State private var breakdownOf: Allocation?

    init(container: AppContainer) {
        _model = State(initialValue: BudgetViewModel(container: container))
    }

    private var hidden: Bool { container.preferences.hideAmounts }

    var body: some View {
        let data = model.monthBudget
        List {
            Section {
                MonthSelector(
                    month: model.month, canGoNext: model.canGoNext, isLocked: false,
                    onPrevious: model.previousMonth, onNext: model.nextMonth
                )
                .listRowBackground(Color.clear)
            }
            if data.goal == nil {
                if model.loaded {
                    EmptyStateView(
                        title: "Goal budget belum diatur",
                        message:
                            "Atur pembagian needs, wants, dan savings untuk melihat budget bulan ini.",
                        systemImage: "chart.pie", actionTitle: "Atur goal"
                    ) { container.router.budgetPath.append(AppRoute.budgetGoal) }
                    .listRowBackground(Color.clear)
                }
            } else {
                if data.showsEvaluation {
                    Section {
                        BudgetEvaluationCard(month: data)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            "Dasar perhitungan: \(MoneyFormatter.rupiah(data.budget.basis, hidden: hidden))"
                        )
                        .font(.headline)
                        Text("Rencana income atau income bulan ini, mana yang lebih besar.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(Allocation.all, id: \.self) { allocation in
                        Button {
                            breakdownOf = allocation
                        } label: {
                            BudgetAllocationRow(
                                allocation: allocation, goalPct: data.pct(of: allocation),
                                result: data.result(of: allocation), hidden: hidden)
                        }
                        .buttonStyle(.plain)
                    }
                    HStack {
                        Text("Belum teralokasi")
                        Spacer()
                        AmountText(amount: data.budget.unallocated, hidden: hidden)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .navigationTitle("Budget")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Atur goal", systemImage: "slider.horizontal.3") {
                    container.router.budgetPath.append(AppRoute.budgetGoal)
                }
            }
        }
        .refreshable { await container.scheduler.syncNow() }
        .sheet(item: $breakdownOf) { allocation in
            BudgetBreakdownSheet(
                allocation: allocation, month: model.month,
                breakdown: model.breakdown(for: allocation))
        }
        .task { await model.start() }
        // A notification asked for a specific month.
        .onChange(of: container.router.budgetMonth, initial: true) { _, month in
            if let month {
                model.month = month
                container.router.budgetMonth = nil
            }
        }
    }
}
