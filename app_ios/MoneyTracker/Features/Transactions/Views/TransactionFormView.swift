import SwiftUI

/// The entry form as a sheet with a large numpad (FRONTEND_IOS §4.6).
struct TransactionFormView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var model: TransactionFormViewModel
    @State private var keyboardVisible = false

    init(container: AppContainer, request: TransactionFormRequest) {
        _model = State(
            initialValue: TransactionFormViewModel(container: container, mode: request.mode))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !model.isEdit {
                    Picker("Tipe", selection: $model.type) {
                        Text("Expense").tag("expense")
                        Text("Income").tag("income")
                        Text("Transfer").tag("transfer")
                    }
                    .pickerStyle(.segmented)
                    .padding([.horizontal, .top])
                    .onChange(of: model.type) { model.typeChanged() }
                }
                if model.loaded {
                    amountHeader
                    if model.selectableAccounts.isEmpty {
                        Spacer()
                        Text("Belum ada akun. Tambahkan akun dulu.").foregroundStyle(.secondary)
                        Spacer()
                    } else {
                        ScrollView { fields.padding(.horizontal) }
                            .scrollDismissesKeyboard(.interactively)
                    }
                    if !keyboardVisible {
                        NumpadView(
                            onDigits: model.addDigits, onBackspace: model.backspace,
                            onClear: model.clearAmount
                        )
                        .padding(.horizontal)
                    }
                    if let message = model.errorMessage {
                        Text(message).font(.footnote).foregroundStyle(.red).padding(.horizontal)
                    }
                    Button("Simpan") { Task { await model.save() } }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(model.busy || model.selectableAccounts.isEmpty)
                        .padding()
                } else {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
            .navigationTitle(model.isEdit ? "Ubah transaksi" : "Catat transaksi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Batal") { dismiss() } }
                if !model.isEdit {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            makeRecurring()
                        } label: {
                            Label("Jadikan berulang", systemImage: "repeat")
                        }
                    }
                }
            }
            .task { await model.prepare() }
            .onChange(of: model.saved) { _, saved in if saved { dismiss() } }
            .onChange(of: model.shouldClose) { _, close in if close { dismiss() } }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            ) {
                _ in keyboardVisible = true
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            ) {
                _ in keyboardVisible = false
            }
        }
    }

    /// Recurring rules are a Premium feature, so a free user is taken to the paywall instead.
    private func makeRecurring() {
        let router = container.router
        let premium = container.premium.isPremium
        let prefill = model.recurringPrefill()
        dismiss()
        if premium {
            router.openRecurringForm(prefill: prefill)
        } else {
            router.push(.paywall(restore: false))
        }
    }

    private var amountHeader: some View {
        Text(MoneyFormatter.rupiah(model.amount ?? 0))
            .font(.system(size: 40, weight: .bold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundStyle(model.digits.isEmpty ? Color.secondary : Color.primary)
            .padding(.vertical, 12)
            .padding(.horizontal)
    }

    @ViewBuilder
    private var fields: some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.type == "expense" {
                label("Kategori")
                if model.visibleCategories.isEmpty {
                    Text("Belum ada kategori yang tampil.").foregroundStyle(.secondary)
                } else {
                    CategoryPicker(
                        categories: model.visibleCategories, selectedId: model.categoryId,
                        onSelect: model.selectCategory)
                }
                label("Alokasi")
                Picker("Alokasi", selection: $model.allocation) {
                    Text("Needs").tag(String?.some("needs"))
                    Text("Wants").tag(String?.some("wants"))
                    Text("Savings").tag(String?.some("savings"))
                }
                .pickerStyle(.segmented)
            }
            if model.type == "income" {
                TextField("Dari mana?", text: $model.source)
                    .textFieldStyle(.roundedBorder)
                if !model.sourceSuggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(model.sourceSuggestions, id: \.self) { suggestion in
                                Button(suggestion) { model.source = suggestion }.buttonStyle(
                                    .bordered)
                            }
                        }
                    }
                }
                label("Kategori")
                CategoryPicker(
                    categories: model.visibleCategories, selectedId: model.categoryId,
                    onSelect: model.selectCategory)
            }
            accountPicker(
                model.type == "transfer" ? "Dari akun" : "Akun", selection: $model.accountId,
                accounts: model.selectableAccounts)
            if model.type == "transfer" {
                accountPicker(
                    "Ke akun", selection: $model.toAccountId,
                    accounts: model.selectableAccounts.filter { $0.id != model.accountId })
                if model.transfersToSavings {
                    Label("Tercatat sebagai savings bulan ini", systemImage: "banknote")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                MoneyField(title: "Biaya admin (opsional)", text: $model.feeText)
                    .padding(10)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            }
            DatePicker(
                "Tanggal",
                selection: Binding(
                    get: { model.date.date() },
                    set: { model.date = CivilDate($0, in: .current) }),
                displayedComponents: .date)
            TextField(
                model.type == "expense" ? "Buat apa?" : "Catatan", text: $model.note,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .lineLimit(1...3)
        }
        .padding(.bottom, 12)
    }

    private func label(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.subheadline.weight(.semibold))
    }

    private func accountPicker(
        _ title: LocalizedStringKey, selection: Binding<String?>, accounts: [AccountRecord]
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Picker(title, selection: selection) {
                if selection.wrappedValue == nil { Text("Pilih akun").tag(String?.none) }
                ForEach(accounts) { account in
                    Text(account.name).tag(String?.some(account.id))
                }
            }
            .labelsHidden()
        }
    }
}
