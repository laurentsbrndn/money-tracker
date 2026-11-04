import SwiftUI

/// One rule in the list: what it records, how often, what comes next, and whether it is running.
struct RecurringRuleRow: View {
    let rule: RecurringRuleRecord
    let title: String
    let today: CivilDate
    let premium: Bool
    let hideAmounts: Bool
    let onTogglePause: () -> Void

    var body: some View {
        let status = rule.status(today: today, premium: premium)
        let next = rule.nextDate(today: today)
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(describeSchedule(rule)).font(.subheadline)
                Text(
                    next.map { String(localized: "Berikutnya \($0.shortText)") }
                        ?? String(localized: "Tidak ada jadwal berikutnya")
                ).font(.caption).foregroundStyle(.secondary)
                Text(statusLabel(status)).font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor(status))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                AmountText(amount: rule.amount, kind: kind, hidden: hideAmounts)
                if status != .ended {
                    Button(action: onTogglePause) {
                        Image(systemName: rule.isPaused ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(rule.isPaused ? "Lanjutkan" : "Jeda")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var kind: AmountKind {
        switch rule.type {
        case "income": .income
        case "expense": .expense
        default: .transfer
        }
    }

    private func statusLabel(_ status: RecurringRuleStatus) -> String {
        switch status {
        case .active: String(localized: "Aktif")
        case .paused: String(localized: "Dijeda")
        case .pausedNoPremium: String(localized: "Dijeda: Premium berakhir")
        case .ended: String(localized: "Selesai")
        }
    }

    private func statusColor(_ status: RecurringRuleStatus) -> Color {
        switch status {
        case .active: AppColors.income
        case .paused, .ended: .secondary
        case .pausedNoPremium: AppColors.expense
        }
    }
}
