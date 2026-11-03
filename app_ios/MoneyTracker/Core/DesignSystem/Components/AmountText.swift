import SwiftUI

enum AmountKind {
    case income, expense, transfer, neutral
}

/// A rupiah amount coloured by kind (FRONTEND_IOS §4.6); with `hidden` it shows `Rp •••••`.
struct AmountText: View {
    let amount: Int64
    var kind: AmountKind = .neutral
    var hidden = false
    /// Prefix `+` / `-` according to `kind`.
    var signed = false

    var body: some View {
        Text(prefix + MoneyFormatter.rupiah(amount, hidden: hidden))
            .foregroundStyle(color)
            .monospacedDigit()
    }

    private var color: Color {
        switch kind {
        case .income: AppColors.income
        case .expense: AppColors.expense
        case .transfer: AppColors.transfer
        case .neutral: amount < 0 ? AppColors.expense : .primary
        }
    }

    private var prefix: String {
        guard signed else { return "" }
        switch kind {
        case .income: return "+"
        case .expense: return "-"
        case .transfer, .neutral: return ""
        }
    }
}
