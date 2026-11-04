import SwiftUI

/// Lainnya → Laporan (APP_FLOWS Flow 8). Everything is computed on the device; the charts are
/// Swift Charts and obey "Sembunyikan nominal".
struct ReportsView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: ReportsViewModel

    init(container: AppContainer, initialKind: ReportKind = .category) {
        let model = ReportsViewModel(container: container)
        model.kind = initialKind
        _model = State(initialValue: model)
    }

    private var hidden: Bool { container.preferences.hideAmounts }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                kindPicker
                if model.kind.usesMonth {
                    MonthSelector(
                        month: model.month, canGoNext: model.canGoNext,
                        isLocked: !model.canView(model.month), onPrevious: model.previousMonth,
                        onNext: model.nextMonth)
                } else {
                    Picker("Rentang", selection: $model.range) {
                        Text("6 bulan").tag(6)
                        Text("12 bulan").tag(12)
                    }
                    .pickerStyle(.segmented)
                }
                content
            }
            .padding(16)
        }
        .navigationTitle("Laporan")
        .task { await model.observe() }
    }

    private var kindPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(ReportKind.allCases) { item in
                    Button {
                        model.kind = item
                    } label: {
                        HStack(spacing: 4) {
                            if item.premiumOnly && !model.isPremium {
                                Image(systemName: "lock.fill").font(.caption2)
                            }
                            Text(item.title)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(
                            model.kind == item ? Color.accentColor : Color.secondary.opacity(0.15),
                            in: Capsule())
                        .foregroundStyle(model.kind == item ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.kindLocked {
            locked(
                title: "Laporan Premium",
                message: "Tren, perbandingan, dan selisih tidak tercatat tersedia untuk Premium.")
        } else if model.monthLocked {
            locked(
                title: "Bulan ini tidak tersedia",
                message: "Paket gratis melihat bulan berjalan dan 2 bulan sebelumnya.")
        } else if !model.loaded {
            ProgressView().frame(maxWidth: .infinity).padding(40)
        } else {
            switch model.kind {
            case .category: pie(model.categoryEntries(), title: model.kind.title)
            case .source: pie(model.sourceEntries(), title: model.kind.title)
            case .trend: trend
            case .comparison: comparison
            case .unrecorded: unrecorded
            }
        }
    }

    private func locked(title: LocalizedStringKey, message: LocalizedStringKey) -> some View {
        EmptyStateView(
            title: title, message: message, systemImage: "lock", actionTitle: "Lihat Premium"
        ) { container.router.push(.paywall(restore: false)) }
        .frame(minHeight: 320)
    }

    private var empty: some View {
        EmptyStateView(
            title: "Belum ada data untuk periode ini.", message: "", systemImage: "chart.bar"
        )
        .frame(minHeight: 280)
    }

    private func open(_ filter: TransactionFilter) {
        container.router.showTransactions(filter: filter)
    }

    private var hint: some View {
        Text("Ketuk bagian grafik untuk melihat transaksinya.")
            .font(.footnote).foregroundStyle(.secondary)
    }

    // MARK: - Reports

    @ViewBuilder
    private func pie(_ entries: [PieEntry], title: String) -> some View {
        if entries.isEmpty {
            empty
        } else {
            ReportPieChart(
                entries: entries, hidden: hidden, accessibilityTitle: "Grafik \(title)", onOpen: open)
            hint
        }
    }

    @ViewBuilder
    private var trend: some View {
        let data = model.trend
        if data.allSatisfy({ $0.income == 0 && $0.expense == 0 }) {
            empty
        } else {
            ReportBarChart(
                groups: data.map { month in
                    BarGroup(
                        id: month.month.description, label: shortMonth(month.month),
                        bars: [
                            BarValue(
                                id: "i", series: String(localized: "Pemasukan"),
                                value: month.income, color: ChartColors.income),
                            BarValue(
                                id: "e", series: String(localized: "Pengeluaran"),
                                value: month.expense, color: ChartColors.expense),
                        ])
                }, hidden: hidden, accessibilityTitle: "Grafik \(ReportKind.trend.title)")
            hint
            Divider()
            ForEach(data.reversed(), id: \.month) { month in
                Button {
                    open(model.monthFilter(month.month))
                } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(month.month.titleText).font(.headline)
                            Text(
                                "Pemasukan \(MoneyFormatter.rupiah(month.income, hidden: hidden)) · Pengeluaran \(MoneyFormatter.rupiah(month.expense, hidden: hidden))"
                            ).font(.caption).foregroundStyle(.secondary)
                            Text("Savings \(MoneyFormatter.rupiah(month.savings, hidden: hidden))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(MoneyFormatter.signedRupiah(month.surplus, hidden: hidden))
                            .foregroundStyle(month.surplus < 0 ? ChartColors.expense : ChartColors.income)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var comparison: some View {
        let data = model.comparison
        let measures: [(String, Int64, Int64)] = [
            (String(localized: "Pemasukan"), data.current.income, data.previous.income),
            (String(localized: "Pengeluaran"), data.current.expense, data.previous.expense),
            (String(localized: "Surplus"), data.current.surplus, data.previous.surplus),
            (String(localized: "Savings"), data.current.savings, data.previous.savings),
        ]
        if measures.allSatisfy({ $0.1 == 0 && $0.2 == 0 }) {
            empty
        } else {
            ReportBarChart(
                groups: measures.map { measure in
                    BarGroup(
                        id: measure.0, label: measure.0,
                        bars: [
                            BarValue(
                                id: "p", series: String(localized: "Bulan sebelumnya"),
                                value: measure.2, color: ChartColors.neutral),
                            BarValue(
                                id: "c", series: String(localized: "Bulan ini"),
                                value: measure.1, color: ChartColors.accent),
                        ])
                }, hidden: hidden, accessibilityTitle: "Grafik \(ReportKind.comparison.title)")
            Divider()
            ForEach(measures, id: \.0) { measure in
                ReportChangeRow(
                    label: measure.0, current: measure.1, previous: measure.2, hidden: hidden,
                    higherIsBad: measure.0 == String(localized: "Pengeluaran"))
            }
            Divider()
            Text("Pengeluaran per kategori").font(.headline)
            ForEach(data.expenseByCategory, id: \.key) { line in
                ReportChangeRow(
                    label: model.categoryName(line.key), current: line.current,
                    previous: line.previous, hidden: hidden, higherIsBad: true)
            }
        }
    }

    @ViewBuilder
    private var unrecorded: some View {
        let data = model.trend
        if data.allSatisfy({ $0.adjustments == 0 }) {
            empty
        } else {
            let total = data.reduce(Int64(0)) { $0 + $1.adjustments }
            Text(
                "Selisih yang disesuaikan lewat Cocokkan saldo, bertanda. Positif berarti saldo asli lebih besar dari catatan."
            )
            ReportBarChart(
                groups: data.map { month in
                    BarGroup(
                        id: month.month.description, label: shortMonth(month.month),
                        bars: [
                            BarValue(
                                id: "a", series: String(localized: "Selisih"),
                                value: month.adjustments,
                                color: month.adjustments < 0
                                    ? ChartColors.expense : ChartColors.income)
                        ])
                }, hidden: hidden, accessibilityTitle: "Grafik \(ReportKind.unrecorded.title)")
            hint
            Divider()
            Text("Total \(MoneyFormatter.signedRupiah(total, hidden: hidden))").font(.headline)
            ForEach(data.reversed().filter { $0.adjustments != 0 }, id: \.month) { month in
                Button {
                    open(model.monthFilter(month.month, type: "adjustment"))
                } label: {
                    HStack {
                        Text(month.month.titleText)
                        Spacer()
                        Text(MoneyFormatter.signedRupiah(month.adjustments, hidden: hidden))
                            .foregroundStyle(
                                month.adjustments < 0 ? ChartColors.expense : ChartColors.income)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func shortMonth(_ month: YearMonth) -> String {
        String(monthName(month.month).prefix(3))
    }
}
