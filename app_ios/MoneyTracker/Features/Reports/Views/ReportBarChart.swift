import Charts
import SwiftUI

/// Grouped bars. With `hidden` ("Sembunyikan nominal") the value axis has no labels and the
/// tooltip shows no amount: only the shape of the data stays.
struct ReportBarChart: View {
    let groups: [BarGroup]
    let hidden: Bool
    let accessibilityTitle: String

    @State private var selectedLabel: String?

    private var seriesNames: [String] {
        var names: [String] = []
        for bar in groups.flatMap(\.bars) where !names.contains(bar.series) { names.append(bar.series) }
        return names
    }

    private var seriesColors: [Color] {
        seriesNames.map { name in
            groups.flatMap(\.bars).first { $0.series == name }?.color ?? .secondary
        }
    }

    private var selectedGroup: BarGroup? { groups.first { $0.label == selectedLabel } }

    var body: some View {
        Chart {
            ForEach(groups) { group in
                ForEach(group.bars) { bar in
                    BarMark(
                        x: .value("Periode", group.label), y: .value("Jumlah", bar.value))
                    .position(by: .value("Seri", bar.series))
                    .foregroundStyle(by: .value("Seri", bar.series))
                    .opacity(selectedLabel == nil || selectedLabel == group.label ? 1 : 0.5)
                }
            }
            RuleMark(y: .value("Nol", 0)).foregroundStyle(.secondary.opacity(0.4))
            if let group = selectedGroup, !hidden {
                RuleMark(x: .value("Periode", group.label))
                    .foregroundStyle(.secondary.opacity(0.25))
                    .annotation(
                        position: .top, spacing: 4,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.label).font(.caption.bold())
                            ForEach(group.bars) { bar in
                                Text("\(bar.series): \(MoneyFormatter.rupiah(bar.value))")
                                    .font(.caption2)
                            }
                        }
                        .padding(6)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
            }
        }
        .chartForegroundStyleScale(domain: seriesNames, range: seriesColors)
        .chartXSelection(value: $selectedLabel)
        .chartYAxis {
            if hidden {
                AxisMarks(values: .automatic) { AxisGridLine() }
            } else {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Int64.self) { Text(MoneyFormatter.compact(amount)) }
                    }
                }
            }
        }
        .chartLegend(position: .top, alignment: .leading)
        .frame(height: 240)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(
            hidden
                ? ""
                : groups.map { group in
                    group.label + ": "
                        + group.bars.map { "\($0.series) \(MoneyFormatter.rupiah($0.value))" }
                        .joined(separator: ", ")
                }.joined(separator: "; "))
    }
}
