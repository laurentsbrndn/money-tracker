import SwiftUI

/// "Menyiapkan data…" until the first pull finishes (APP_FLOWS Flow 1, step 5).
struct InitialSyncView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: InitialSyncViewModel

    init(container: AppContainer) {
        _model = State(initialValue: InitialSyncViewModel(container: container))
    }

    var body: some View {
        VStack(spacing: 16) {
            switch model.state {
            case .syncing:
                ProgressView().controlSize(.large)
                Text("Menyiapkan data…").font(.headline)
                Text("\(model.pulledRows) data diterima")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            case .offline:
                failure(
                    "Belum bisa terhubung ke server. Periksa internetmu lalu coba lagi.",
                    symbol: "icloud.slash")
            case .failed:
                failure("Gagal menyiapkan data. Coba lagi.", symbol: "exclamationmark.triangle")
            case .needsLogin:
                Image(systemName: "lock").font(.system(size: 44)).foregroundStyle(.secondary)
                Text("Sesimu berakhir. Masuk lagi untuk melanjutkan.")
                    .multilineTextAlignment(.center)
                Button("Masuk") { container.router.showReLogin = true }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await model.run() }
        .onChange(of: container.session.status) { _, status in
            if status == .authenticated { Task { await model.run() } }
        }
    }

    @ViewBuilder
    private func failure(_ message: LocalizedStringKey, symbol: String) -> some View {
        Image(systemName: symbol).font(.system(size: 44)).foregroundStyle(.secondary)
        Text(message).multilineTextAlignment(.center)
        Button("Coba lagi") { Task { await model.run() } }
            .buttonStyle(.borderedProminent)
    }
}
