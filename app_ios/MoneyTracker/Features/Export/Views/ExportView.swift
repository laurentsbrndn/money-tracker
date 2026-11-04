import SwiftUI

/// Lainnya → Data → Export (APP_FLOWS Flow 12): CSV or PDF of the posted transactions in a
/// period, read from the local database. Premium only (BUSINESS_RULES §7).
struct ExportView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: ExportViewModel

    init(container: AppContainer) {
        _model = State(initialValue: ExportViewModel(container: container))
    }

    var body: some View {
        Group {
            if container.premium.isPremium {
                form
            } else {
                EmptyStateView(
                    title: "Export untuk Premium",
                    message: "Export CSV dan PDF tersedia untuk Premium.", systemImage: "lock",
                    actionTitle: "Lihat Premium"
                ) { container.router.push(.paywall(restore: false)) }
            }
        }
        .navigationTitle("Export data")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.reset() }
        .sheet(
            isPresented: Binding(
                get: { model.shareURL != nil }, set: { if !$0 { model.shareFinished() } })
        ) {
            if let url = model.shareURL {
                ActivityView(items: [url]) { model.shareFinished() }
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var form: some View {
        Form {
            Section("Format") {
                Picker("Format", selection: $model.format) {
                    Text("CSV").tag(ExportFormat.csv)
                    Text("PDF").tag(ExportFormat.pdf)
                }
                .pickerStyle(.segmented)
            }
            .disabled(model.busy)
            Section("Periode") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(ExportPreset.allCases, id: \.self) { preset in
                            Button(Self.label(preset)) { model.pick(preset) }
                                .buttonStyle(.bordered)
                                .tint(model.preset == preset ? .accentColor : .secondary)
                        }
                    }
                }
                if model.preset != .allData {
                    DatePicker(
                        "Dari tanggal",
                        selection: Binding(
                            get: { model.from.date() },
                            set: {
                                model.from = CivilDate($0, in: .current)
                                model.edited()
                            }), displayedComponents: .date)
                    DatePicker(
                        "Sampai tanggal",
                        selection: Binding(
                            get: { model.to.date() },
                            set: {
                                model.to = CivilDate($0, in: .current)
                                model.edited()
                            }), displayedComponents: .date)
                }
                if !model.rangeOK {
                    Text("Tanggal awal tidak boleh setelah tanggal akhir.")
                        .foregroundStyle(.red)
                }
            }
            .disabled(model.busy)
            if model.format == .csv {
                Section {
                    Picker("Pemisah kolom CSV", selection: $model.delimiter) {
                        Text("Otomatis").tag(CsvDelimiterChoice.auto)
                        Text("Koma").tag(CsvDelimiterChoice.comma)
                        Text("Titik koma").tag(CsvDelimiterChoice.semicolon)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Pemisah kolom CSV")
                } footer: {
                    Text(
                        "Otomatis mengikuti bahasa perangkat: titik koma bila pemisah desimalnya koma."
                    )
                }
                .disabled(model.busy)
            }
            Section {
                Text(
                    "File memuat nominal asli walau Sembunyikan nominal aktif, dan hanya dibuat saat app tidak terkunci."
                ).font(.footnote).foregroundStyle(.secondary)
                if model.busy {
                    ProgressView(value: model.progress)
                    Text("Menyiapkan file…")
                } else {
                    Button {
                        Task { await model.run(texts: texts) }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).disabled(!model.rangeOK)
                }
                if let message {
                    Text(message).accessibilityIdentifier("export_message")
                }
            }
        }
    }

    private var message: String? {
        switch model.phase {
        case .empty: String(localized: "Tidak ada transaksi pada periode ini.")
        case .failed: String(localized: "File gagal dibuat atau dibagikan. Coba lagi.")
        case .locked: String(localized: "App terkunci, export dibatalkan.")
        case .done: String(localized: "Pilih tujuan untuk menyimpan atau mengirim file.")
        default: nil
        }
    }

    private static func label(_ preset: ExportPreset) -> String {
        switch preset {
        case .thisMonth: String(localized: "Bulan ini")
        case .lastMonth: String(localized: "Bulan lalu")
        case .last3Months: String(localized: "3 bulan terakhir")
        case .thisYear: String(localized: "Tahun ini")
        case .allData: String(localized: "Semua data")
        }
    }

    private var texts: ExportTexts {
        ExportTexts(
            headers: [
                String(localized: "Tanggal"), String(localized: "Tipe"),
                String(localized: "Jumlah (Rp)"), String(localized: "Akun"),
                String(localized: "Akun tujuan"), String(localized: "Kategori"),
                String(localized: "Catatan"),
            ],
            typeLabels: [
                .income: String(localized: "Pemasukan"),
                .expense: String(localized: "Pengeluaran"),
                .transfer: String(localized: "Transfer"),
                .adjustment: String(localized: "Penyesuaian"),
            ],
            pdfTitle: String(localized: "Laporan Transaksi Money Tracker"),
            pdfPeriod: String(localized: "Periode"), pdfIncome: String(localized: "Pemasukan"),
            pdfExpense: String(localized: "Pengeluaran"), pdfDifference: String(localized: "Selisih"),
            pdfCount: String(localized: "Jumlah transaksi"),
            pdfPage: { page, total in String(localized: "Halaman \(page) dari \(total)") },
            pdfAllData: String(localized: "Semua data"),
            pdfRange: { from, to in String(localized: "\(from) s/d \(to)") })
    }
}
