import Charts
import SwiftUI

/// A donut of `entries` with a legend. With `hidden` ("Sembunyikan nominal") nothing shows an
/// amount: the legend and the tooltip show percentages only (basis points, integer math).
struct ReportPieChart: View {
    let entries: [PieEntry]
    let hidden: Bool
    let accessibilityTitle: String
    let onOpen: (TransactionFilter) -> Void

    @State private var selectedAngle: Int64?

    private var total: Int64 { entries.reduce(0) { $0 + $1.amount } }

    private func basisPoints(_ amount: Int64) -> Int64 {
        total == 0 ? 0 : (amount * 10_000 + total / 2) / total
    }

    /// The slice under the selected angle (the angle is a position on the running total).
    private var selected: PieEntry? {
        guard let selectedAngle else { return nil }
        var running: Int64 = 0
        for entry in entries {
            running += entry.amount
            if selectedAngle <= running { return entry }
        }
        return entries.last
    }

    var body: some View {
        VStack(spacing: 12) {
            Chart(entries) { entry in
                SectorMark(
                    angle: .value("Jumlah", entry.amount), innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .cornerRadius(3)
                .foregroundStyle(entry.color)
                .opacity(selected == nil || selected?.id == entry.id ? 1 : 0.45)
            }
            .chartAngleSelection(value: $selectedAngle)
            .chartLegend(.hidden)
            .chartBackground { _ in
                // The centre shows the selected slice: its share, and its amount unless hidden.
                if let selected {
                    VStack(spacing: 2) {
                        Text(selected.label).font(.caption).lineLimit(1)
                        Text(MoneyFormatter.percent(basisPoints: basisPoints(selected.amount)))
                            .font(.headline)
                        if !hidden {
                            Text(MoneyFormatter.rupiah(selected.amount))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(40)
                } else if !hidden {
                    VStack(spacing: 2) {
                        Text("Total").font(.caption).foregroundStyle(.secondary)
                        Text(MoneyFormatter.rupiah(total)).font(.headline)
                    }
                }
            }
            .frame(height: 220)
            .accessibilityLabel(accessibilityTitle)
            .accessibilityValue(
                entries.map { "\($0.label) \(MoneyFormatter.percent(basisPoints: basisPoints($0.amount)))" }
                    .joined(separator: ", "))
            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    Button {
                        if let filter = entry.filter { onOpen(filter) }
                    } label: {
                        HStack(spacing: 8) {
                            Circle().fill(entry.color).frame(width: 12, height: 12)
                            Text(entry.label).foregroundStyle(.primary)
                            Spacer()
                            if !hidden {
                                Text(MoneyFormatter.rupiah(entry.amount)).monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Text(MoneyFormatter.percent(basisPoints: basisPoints(entry.amount)))
                                .monospacedDigit().frame(minWidth: 52, alignment: .trailing)
                        }
                        .padding(.vertical, 8).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(entry.filter == nil)
                }
            }
        }
    }
}
