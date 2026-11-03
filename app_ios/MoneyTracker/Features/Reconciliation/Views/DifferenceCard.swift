import SwiftUI

/// The "Selisih" card of the dashboard (APP_FLOWS Flow 2 step 4): green when everything
/// matches, yellow with a "Cocokkan" button when an account differs, grey "Update saldo aktual"
/// when an account is stale (more than 7 days since its last real balance).
struct DifferenceCard: View {
    let overview: ReconcileOverview
    let hidden: Bool
    let onReconcile: () -> Void

    private var style: (color: Color, icon: String, title: String, body: String, action: Bool) {
        if overview.mismatchCount > 0 {
            let diff = MoneyFormatter.signedRupiah(overview.totals.diffTotal, hidden: hidden)
            return (
                AppColors.warning, "exclamationmark.triangle.fill",
                String(localized: "Selisih \(diff)"),
                String(localized: "\(overview.mismatchCount) akun berbeda dari catatan"), true
            )
        }
        if overview.staleCount > 0 {
            return (
                .secondary, "clock.arrow.circlepath", String(localized: "Update saldo aktual"),
                String(localized: "\(overview.staleCount) akun belum dicek lebih dari 7 hari"),
                true
            )
        }
        return (
            AppColors.income, "checkmark.circle.fill", String(localized: "Saldo cocok"),
            String(localized: "Semua akun sama dengan catatanmu."), false
        )
    }

    var body: some View {
        let style = style
        HStack(spacing: 12) {
            Image(systemName: style.icon).font(.title).foregroundStyle(style.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(style.title).font(.headline)
                Text(style.body).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            if style.action {
                Button("Cocokkan", action: onReconcile).buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(style.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}
