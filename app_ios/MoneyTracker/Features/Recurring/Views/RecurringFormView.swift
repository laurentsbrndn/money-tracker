import SwiftUI

/// Create or edit a recurring rule (APP_FLOWS Flow 10). Creating one is a Premium feature;
/// editing an existing rule is not.
struct RecurringFormView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var model: RecurringFormViewModel
    @State private var confirmDelete = false

    init(container: AppContainer, ruleId: String?, prefill: RecurringPrefill?) {
        _model = State(
            initialValue: RecurringFormViewModel(
                container: container, ruleId: ruleId, prefill: prefill))
    }

    var body: some View {
        Group {
            if !model.isEdit && !container.premium.isPremium {
                EmptyStateView(
                    title: "Transaksi berulang untuk Premium",
                    message: "Dengan Premium, transaksi rutin dicatat otomatis atau menunggu konfirmasimu.",
                    systemImage: "repeat", actionTitle: "Lihat Premium"
                ) { container.router.push(.paywall(restore: false)) }
            } else if model.loaded {
                form
            } else {
                ProgressView()
            }
        }
        .navigationTitle(model.isEdit ? "Ubah aturan" : "Aturan baru")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .onChange(of: model.saved) { _, saved in if saved { dismiss() } }
        .onChange(of: model.deleted) { _, deleted in if deleted { dismiss() } }
        .confirmationDialog(
            "Hapus aturan ini? Transaksi yang sudah dibuat tidak ikut terhapus.",
            isPresented: $confirmDelete, titleVisibility: .visible
        ) {
            Button("Hapus aturan", role: .destructive) { Task { await model.delete() } }
        }
    }

    private var form: some View {
        Form {
            templateSection
            scheduleSection
            Section("Cara mencatat") {
                Picker("Cara mencatat", selection: $model.mode) {
                    Text("Otomatis").tag("auto")
                    Text("Minta konfirmasi").tag("confirm")
                }
                .pickerStyle(.segmented)
                Text(
                    model.mode == "auto"
                        ? "Transaksi langsung dicatat pada tanggalnya."
                        : "Transaksi menunggu kamu catat atau lewati di tab Transaksi."
                ).font(.footnote).foregroundStyle(.secondary)
            }
            FormErrorSection(message: model.errorMessage, planLimit: model.planLimit)
            if model.isEdit {
                Section {
                    Button("Hapus aturan", role: .destructive) { confirmDelete = true }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Simpan") { Task { await model.save() } }
                    .disabled(model.busy || model.selectableAccounts.isEmpty)
            }
        }
    }

    private var templateSection: some View {
        Section {
            Picker("Tipe", selection: $model.type) {
                Text("Expense").tag("expense")
                Text("Income").tag("income")
                Text("Transfer").tag("transfer")
            }
            .pickerStyle(.segmented)
            .disabled(model.isEdit)
            .onChange(of: model.type) { model.typeChanged() }
            MoneyField(title: "Nominal", text: $model.amountText)
            if model.type == "expense" || model.type == "income" {
                CategoryPicker(
                    categories: model.visibleCategories, selectedId: model.categoryId,
                    onSelect: model.selectCategory)
            }
            if model.type == "expense" {
                Picker("Alokasi", selection: $model.allocation) {
                    Text("Needs").tag(String?.some("needs"))
                    Text("Wants").tag(String?.some("wants"))
                    Text("Savings").tag(String?.some("savings"))
                }
                .pickerStyle(.segmented)
            }
            if model.type == "income" {
                TextField("Dari mana?", text: $model.source)
            }
            accountPicker(
                model.type == "transfer" ? "Dari akun" : "Akun", selection: $model.accountId,
                accounts: model.selectableAccounts)
            if model.type == "transfer" {
                accountPicker(
                    "Ke akun", selection: $model.toAccountId,
                    accounts: model.selectableAccounts.filter { $0.id != model.accountId })
            }
            TextField(
                model.type == "expense" ? "Buat apa?" : "Catatan", text: $model.note,
                axis: .vertical
            ).lineLimit(1...3)
        }
    }

    private var scheduleSection: some View {
        Section("Jadwal") {
            Picker("Frekuensi", selection: $model.frequency) {
                Text("Harian").tag(RecurringFrequency.daily)
                Text("Mingguan").tag(RecurringFrequency.weekly)
                Text("Bulanan").tag(RecurringFrequency.monthly)
                Text("Tahunan").tag(RecurringFrequency.yearly)
            }
            HStack {
                Text("Setiap")
                TextField("1", text: $model.intervalText)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(maxWidth: 60)
                Text(unit)
            }
            switch model.frequency {
            case .daily:
                EmptyView()
            case .weekly:
                Picker("Hari", selection: $model.dayOfWeek) {
                    ForEach(1...7, id: \.self) { Text(weekdayName($0)).tag($0) }
                }
            case .monthly:
                Picker("Tanggal", selection: $model.dayOfMonth) {
                    ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
                }
                Text("Di bulan yang lebih pendek, transaksi dicatat pada hari terakhir bulan itu.")
                    .font(.footnote).foregroundStyle(.secondary)
            case .yearly:
                Picker("Bulan", selection: $model.monthOfYear) {
                    ForEach(1...12, id: \.self) { Text(monthName($0)).tag($0) }
                }
                Picker("Tanggal", selection: $model.dayOfMonth) {
                    ForEach(1...CivilDate.daysInMonth(year: 2024, month: model.monthOfYear), id: \.self) {
                        Text("\($0)").tag($0)
                    }
                }
            }
            DatePicker(
                "Mulai",
                selection: Binding(
                    get: { model.startDate.date() },
                    set: { model.startDate = CivilDate($0, in: .current) }),
                displayedComponents: .date)
            Toggle("Ada tanggal selesai", isOn: $model.hasEnd)
            if model.hasEnd {
                DatePicker(
                    "Selesai",
                    selection: Binding(
                        get: { model.endDate.date() },
                        set: { model.endDate = CivilDate($0, in: .current) }),
                    displayedComponents: .date)
            }
        }
    }

    private var unit: String {
        switch model.frequency {
        case .daily: String(localized: "hari")
        case .weekly: String(localized: "minggu")
        case .monthly: String(localized: "bulan")
        case .yearly: String(localized: "tahun")
        }
    }

    private func accountPicker(
        _ title: LocalizedStringKey, selection: Binding<String?>, accounts: [AccountRecord]
    ) -> some View {
        Picker(title, selection: selection) {
            if selection.wrappedValue == nil { Text("Pilih akun").tag(String?.none) }
            ForEach(accounts) { account in Text(account.name).tag(String?.some(account.id)) }
        }
    }
}
