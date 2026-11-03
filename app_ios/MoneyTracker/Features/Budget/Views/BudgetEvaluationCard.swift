import SwiftUI

/// The month-end evaluation card (APP_FLOWS Flow 6 step 3).
struct BudgetEvaluationCard: View {
    let month: MonthBudget

    var body: some View {
        let lines = month.evaluation
        let allUnknown = lines.allSatisfy { $0.outcome == .unknown }
        VStack(alignment: .leading, spacing: 8) {
            Text("Evaluasi \(month.month.titleText)").font(.headline)
            if allUnknown {
                Text("Tidak ada goal atau income untuk dibandingkan.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(lines.filter { $0.outcome != .unknown }, id: \.allocation) { line in
                    Label {
                        Text(text(for: line))
                    } icon: {
                        Image(
                            systemName: line.outcome == .good
                                ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                        )
                        .foregroundStyle(
                            line.outcome == .good ? AppColors.income : AppColors.expense)
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.seed.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    private func text(for line: AllocationEvaluation) -> String {
        let name = line.allocation.label
        let good = line.outcome == .good
        if line.allocation == .savings {
            return good
                ? String(localized: "\(name) mencapai goal.")
                : String(localized: "\(name) belum mencapai goal.")
        }
        return good
            ? String(localized: "\(name) tidak melewati goal.")
            : String(localized: "\(name) melewati goal.")
    }
}
