#if DEBUG
    import SwiftUI

    /// A gallery of every screen over sample data, for the Xcode Canvas. Open this file and pick
    /// Editor → Canvas. The app itself starts at `RootView`; this file only exists in Debug.
    struct ContentView: View {
        @State private var variant = PreviewVariant.populated
        @State private var presented: Entry?

        var body: some View {
            NavigationStack {
                List {
                    Section {
                        Picker("Varian", selection: $variant) {
                            ForEach(PreviewVariant.allCases) { Text($0.title).tag($0) }
                        }
                    } footer: {
                        Text(
                            "Varian memilih data contoh dan keadaan sync. Layar masuk, daftar, dan onboarding selalu keluar dari sesi; di sana varian hanya memengaruhi mode gelap."
                        )
                    }
                    ForEach(Self.sections) { section in
                        Section(section.title) {
                            ForEach(section.entries) { entry in
                                row(entry)
                            }
                        }
                    }
                }
                .navigationTitle("Galeri layar")
            }
            .sheet(item: $presented) { entry in
                host(entry)
            }
            .environment(\.locale, Locale(identifier: "id_ID"))
        }

        @ViewBuilder
        private func row(_ entry: Entry) -> some View {
            switch entry.style {
            case .push:
                NavigationLink(entry.title) { host(entry) }
            case .sheet:
                Button(entry.title) { presented = entry }
                    .foregroundStyle(.primary)
            }
        }

        private func host(_ entry: Entry) -> some View {
            PreviewHost(variant: variant, signedOut: entry.signedOut) { container in
                if let tab = entry.tab {
                    PreviewStack(container: container, tab: tab) { entry.build(container) }
                } else {
                    entry.build(container)
                }
            }
            .id(variant)
        }
    }

    // MARK: - Catalog

    extension ContentView {
        enum Style { case push, sheet }

        struct Entry: Identifiable {
            let title: String
            var style = Style.push
            var signedOut = false
            /// Wraps the screen in a navigation stack bound to this tab's router path.
            var tab: AppTab?
            let build: @MainActor (AppContainer) -> AnyView

            var id: String { title }
        }

        struct Gallery: Identifiable {
            let title: String
            let entries: [Entry]

            var id: String { title }
        }

        static let sections: [Gallery] = [
            Gallery(
                title: "Auth",
                entries: [
                    Entry(title: "Login", signedOut: true) {
                        AnyView(
                            LoginView(container: $0, onForgotPassword: {}, onRegister: {}))
                    },
                    Entry(title: "Daftar", signedOut: true) {
                        AnyView(RegisterView(container: $0, onLogin: {}))
                    },
                    Entry(title: "Lupa kata sandi", signedOut: true) {
                        AnyView(ForgotPasswordView(container: $0, onSent: { _ in }))
                    },
                    Entry(title: "Atur ulang kata sandi", signedOut: true) {
                        AnyView(
                            ResetPasswordView(
                                container: $0, email: "brandon@example.com", onDone: {}))
                    },
                    Entry(title: "Verifikasi email", style: .sheet) {
                        AnyView(VerifyEmailView(container: $0))
                    },
                ]),
            Gallery(
                title: "Onboarding",
                entries: [
                    Entry(title: "Slide pengantar", style: .sheet, signedOut: true) { _ in
                        AnyView(OnboardingView(onStart: {}, onLogin: {}))
                    },
                    Entry(title: "Alur auth lengkap", style: .sheet, signedOut: true) { _ in
                        AnyView(AuthFlowView())
                    },
                    Entry(title: "Splash", style: .sheet) { _ in AnyView(SplashView()) },
                    Entry(title: "Wizard awal", style: .sheet) {
                        AnyView(SetupWizardView(container: $0))
                    },
                    Entry(title: "Sinkronisasi awal", style: .sheet) {
                        AnyView(InitialSyncView(container: $0))
                    },
                    Entry(title: "Login ulang", style: .sheet) { _ in AnyView(ReLoginView()) },
                ]),
            Gallery(
                title: "Dashboard",
                entries: [
                    Entry(title: "Beranda", style: .sheet, tab: .dashboard) {
                        AnyView(HomeView(container: $0))
                    },
                    Entry(title: "Aplikasi lengkap (tab)", style: .sheet) { _ in
                        AnyView(MainTabView())
                    },
                ]),
            Gallery(
                title: "Transaksi",
                entries: [
                    Entry(title: "Daftar transaksi", style: .sheet, tab: .transactions) {
                        AnyView(TransactionsView(container: $0))
                    },
                    Entry(title: "Form pengeluaran", style: .sheet) {
                        AnyView(
                            TransactionFormView(
                                container: $0,
                                request: TransactionFormRequest(
                                    mode: .new(type: "expense", fromAccountId: nil, amount: nil))))
                    },
                    Entry(title: "Form pemasukan", style: .sheet) {
                        AnyView(
                            TransactionFormView(
                                container: $0,
                                request: TransactionFormRequest(
                                    mode: .new(
                                        type: "income", fromAccountId: "acc-bca", amount: 250_000)))
                        )
                    },
                    Entry(title: "Form transfer", style: .sheet) {
                        AnyView(
                            TransactionFormView(
                                container: $0,
                                request: TransactionFormRequest(
                                    mode: .new(
                                        type: "transfer", fromAccountId: "acc-bca", amount: nil))))
                    },
                    Entry(title: "Ubah transaksi", style: .sheet) {
                        AnyView(
                            TransactionFormView(
                                container: $0,
                                request: TransactionFormRequest(mode: .edit(id: "t6"))))
                    },
                    Entry(title: "Filter", style: .sheet) {
                        AnyView(
                            TransactionFilterSheet(
                                container: $0, initial: TransactionFilter(), onApply: { _ in }))
                    },
                ]),
            Gallery(
                title: "Akun",
                entries: [
                    Entry(title: "Daftar akun", style: .sheet, tab: .accounts) {
                        AnyView(AccountsView(container: $0))
                    },
                    Entry(title: "Detail Cash (selisih)", style: .sheet, tab: .accounts) {
                        AnyView(AccountDetailView(container: $0, accountId: "acc-cash"))
                    },
                    Entry(title: "Detail BCA (cocok)", style: .sheet, tab: .accounts) {
                        AnyView(AccountDetailView(container: $0, accountId: "acc-bca"))
                    },
                    Entry(title: "Detail Jago (usang)", style: .sheet, tab: .accounts) {
                        AnyView(AccountDetailView(container: $0, accountId: "acc-jago"))
                    },
                    Entry(title: "Form akun baru", style: .sheet, tab: .accounts) {
                        AnyView(AccountFormView(container: $0, accountId: nil))
                    },
                    Entry(title: "Ubah akun", style: .sheet, tab: .accounts) {
                        AnyView(AccountFormView(container: $0, accountId: "acc-bca"))
                    },
                ]),
            Gallery(
                title: "Kategori",
                entries: [
                    Entry(title: "Daftar kategori", style: .sheet, tab: .more) {
                        AnyView(CategoriesView(container: $0))
                    },
                    Entry(title: "Form kategori baru", style: .sheet, tab: .more) {
                        AnyView(CategoryFormView(container: $0, categoryId: nil, type: "expense"))
                    },
                    Entry(title: "Ubah kategori", style: .sheet, tab: .more) {
                        AnyView(
                            CategoryFormView(container: $0, categoryId: "cat-food", type: nil))
                    },
                ]),
            Gallery(
                title: "Pengaturan",
                entries: [
                    Entry(title: "Lainnya (menu)", style: .sheet, tab: .more) {
                        AnyView(MoreView(container: $0))
                    },
                    Entry(title: "Sinkronisasi / Perlu perhatian", style: .sheet, tab: .more) {
                        AnyView(SyncSettingsView(container: $0))
                    },
                    Entry(title: "Profil", style: .sheet, tab: .more) {
                        AnyView(ProfileView(container: $0))
                    },
                    Entry(title: "Ganti kata sandi", style: .sheet, tab: .more) {
                        AnyView(ChangePasswordView(container: $0))
                    },
                    Entry(title: "Hapus akun", style: .sheet, tab: .more) {
                        AnyView(DeleteAccountView(container: $0))
                    },
                    Entry(title: "Perbarui aplikasi", style: .sheet) { _ in
                        AnyView(UpgradeRequiredView())
                    },
                ]),
            Gallery(
                title: "Komponen",
                entries: [
                    Entry(title: "SyncBadge (state mengikuti varian)", style: .sheet) { _ in
                        AnyView(SyncBadge().padding())
                    },
                    Entry(title: "EmptyStateView", style: .sheet) { _ in
                        AnyView(
                            EmptyStateView(
                                title: "Belum ada transaksi",
                                message: "Transaksi yang kamu catat muncul di sini.",
                                systemImage: "list.bullet", actionTitle: "Catat transaksi",
                                action: {}))
                    },
                    Entry(title: "AmountText", style: .sheet) { _ in
                        AnyView(
                            VStack(alignment: .leading, spacing: 8) {
                                AmountText(amount: 8_000_000, kind: .income)
                                AmountText(amount: 1_852_500, kind: .expense)
                                AmountText(amount: 6_147_500, hidden: true)
                            }
                            .padding())
                    },
                    Entry(title: "NumpadView", style: .sheet) { _ in
                        AnyView(NumpadView(onDigits: { _ in }, onBackspace: {}).padding())
                    },
                ]),
        ]
    }

    #Preview("Galeri layar") {
        ContentView()
    }

    #Preview("Galeri layar — mode gelap") {
        ContentView().preferredColorScheme(.dark)
    }
#endif
