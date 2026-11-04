import SwiftUI

/// "Lainnya" menu (APP_FLOWS Flow 12).
struct MoreView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: MoreViewModel

    init(container: AppContainer) {
        _model = State(initialValue: MoreViewModel(container: container))
    }

    var body: some View {
        List {
            if let user = container.session.user {
                Section {
                    NavigationLink(value: AppRoute.profile) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.largeTitle).foregroundStyle(.secondary)
                            VStack(alignment: .leading) {
                                Text(user.name).font(.headline)
                                Text(user.email ?? String(localized: "Tidak ada email"))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            Section {
                NavigationLink(value: AppRoute.subscription) {
                    HStack {
                        Label("Langganan", systemImage: "star.circle")
                        Spacer()
                        if container.premium.isPremium {
                            Text("Premium aktif").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                NavigationLink(value: AppRoute.recurring) {
                    Label("Transaksi berulang", systemImage: "repeat")
                }
                NavigationLink(value: AppRoute.reports) {
                    Label("Laporan", systemImage: "chart.bar.xaxis")
                }
                NavigationLink(value: AppRoute.export) {
                    HStack {
                        Label("Export data", systemImage: "square.and.arrow.up")
                        Spacer()
                        if !container.premium.isPremium {
                            Image(systemName: "lock").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section {
                NavigationLink(value: AppRoute.categories) {
                    Label("Kategori", systemImage: "square.grid.2x2")
                }
                NavigationLink(value: AppRoute.preferences) {
                    Label("Preferensi", systemImage: "slider.horizontal.3")
                }
                NavigationLink(value: AppRoute.security) {
                    Label("Keamanan", systemImage: "lock")
                }
                NavigationLink(value: AppRoute.notifications) {
                    Label("Notifikasi", systemImage: "bell")
                }
                NavigationLink(value: AppRoute.syncSettings) {
                    HStack {
                        Label("Sinkronisasi", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        let attention = container.syncStatus.failedChanges.count
                        if attention > 0 {
                            Text("\(attention)")
                                .font(.caption.bold()).foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(.red, in: Capsule())
                        }
                    }
                }
            }
            Section {
                Button {
                    Task { await model.askLogout() }
                } label: {
                    Label("Keluar", systemImage: "rectangle.portrait.and.arrow.right")
                }
                NavigationLink(value: AppRoute.deleteAccount) {
                    Label("Hapus akun", systemImage: "trash").foregroundStyle(.red)
                }
            }
            Section {
                Text("Versi \(model.version)")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Lainnya")
        .alert("Keluar dari akun?", isPresented: $model.showLogoutConfirm) {
            Button("Batal", role: .cancel) {}
            Button("Keluar", role: .destructive) { Task { await model.logout() } }
        } message: {
            if model.pendingChanges > 0 {
                Text(
                    "Ada \(model.pendingChanges) perubahan yang belum tersinkron. Jika keluar sekarang, perubahan itu hilang dari perangkat dan tidak pernah sampai ke server.\n\nSemua data di perangkat ini akan dihapus. Datamu tetap aman di server dan kembali setelah kamu masuk lagi."
                )
            } else {
                Text(
                    "Semua data di perangkat ini akan dihapus. Datamu tetap aman di server dan kembali setelah kamu masuk lagi."
                )
            }
        }
    }
}
