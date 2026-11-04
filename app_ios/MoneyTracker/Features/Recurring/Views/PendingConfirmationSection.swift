import SwiftUI

/// "Menunggu konfirmasi" at the top of the transactions list (APP_FLOWS Flow 4 step 4).
struct PendingConfirmationSection: View {
    @Environment(AppContainer.self) private var container
    /// Owned by the transactions screen, which runs its observation: this view is empty while
    /// nothing waits, so it cannot start the observation itself.
    let model: PendingConfirmationViewModel

    var body: some View {
        Group {
            if !model.pending.isEmpty {
                Section("Menunggu konfirmasi (\(model.pending.count))") {
                    ForEach(model.pending) { row in
                        VStack(alignment: .trailing, spacing: 8) {
                            Button {
                                container.router.openTransaction(id: row.id)
                            } label: {
                                TransactionRow(transaction: row)
                            }
                            .buttonStyle(.plain)
                            HStack {
                                Button("Lewati") { Task { await model.skip(row) } }
                                    .buttonStyle(.bordered)
                                Button("Catat") { Task { await model.record(row) } }
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
            }
        }
    }
}
