import SwiftUI

/// One bucket of the budget: goal against actual (APP_FLOWS Flow 2 step 5 and Flow 6 step 2).
/// With `compact` only the bar and the two amounts show.
struct BudgetAllocationRow: View {
    let allocation: Allocation
    let goalPct: Int64
    let result: AllocationResult
    let hidden: Bool
    var compact = false

    private var over: Bool { result.goalAmount > 0 && result.actual > result.goalAmount }
    private var spendBucket: Bool { allocation != .savings }

    private var barColor: Color {
        if over && spendBucket {
            // Wants over its goal is red (APP_FLOWS Flow 2); needs is a softer warning.
            return allocation == .wants ? AppColors.expense : AppColors.warning
        }
        if allocation == .savings && result.goalAmount > 0 && result.actual >= result.goalAmount {
            return AppColors.income
        }
        return AppColors.seed
    }

    /// Bar fill in 0...1, computed with integers until the last step.
    private var ratio: Double {
        if result.goalAmount > 0 {
            return min(1, max(0, Double(result.actual) / Double(result.goalAmount)))
        }
        return result.actual > 0 ? 1 : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(allocation.label).font(.subheadline.weight(.semibold))
                Spacer()
                AmountText(amount: result.actual, hidden: hidden)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(over && spendBucket ? barColor : .primary)
                if compact {
                    Text("/").font(.caption).foregroundStyle(.secondary)
                    AmountText(amount: result.goalAmount, hidden: hidden)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            ProgressView(value: ratio).tint(barColor)
            if !compact {
                Text(
                    "Goal \(goalPct)% · \(MoneyFormatter.rupiah(result.goalAmount, hidden: hidden))"
                )
                .font(.caption).foregroundStyle(.secondary)
                Text(
                    "Aktual \(result.actualBP.map { MoneyFormatter.percent(basisPoints: $0) } ?? "–") · \(MoneyFormatter.rupiah(result.actual, hidden: hidden))"
                )
                .font(.caption).foregroundStyle(.secondary)
                Text(remainingText)
                    .font(.caption).foregroundStyle(over && spendBucket ? barColor : .secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var remainingText: String {
        let amount = MoneyFormatter.rupiah(abs(result.remaining), hidden: hidden)
        if allocation == .savings {
            // Remaining savings is what is still missing from the goal.
            if result.remaining > 0 { return String(localized: "Kurang \(amount)") }
            return result.remaining < 0
                ? String(localized: "Lebih \(amount)") : String(localized: "Sisa \(amount)")
        }
        return result.remaining >= 0
            ? String(localized: "Sisa \(amount)") : String(localized: "Lebih \(amount)")
    }
}
