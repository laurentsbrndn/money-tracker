import SwiftUI

extension View {
    /// Asks before replacing another account's data on this device (SYNC_PROTOCOL §11).
    func userMismatchAlert(_ submission: AuthSubmission) -> some View {
        @Bindable var submission = submission
        return alert(
            "Ganti akun?",
            isPresented: Binding(
                get: { submission.mismatch != nil },
                set: { if !$0 { submission.cancelDiscard() } }),
            presenting: submission.mismatch
        ) { _ in
            Button("Batal", role: .cancel) { submission.cancelDiscard() }
            Button("Hapus data & masuk", role: .destructive) {
                Task { await submission.confirmDiscard() }
            }
        } message: { mismatch in
            if mismatch.pendingChanges > 0 {
                Text(
                    "Perangkat ini masih berisi data akun lain. Masuk dengan akun ini akan menghapus data itu dari perangkat. Ada \(mismatch.pendingChanges) perubahan yang belum tersinkron dan akan hilang."
                )
            } else {
                Text(
                    "Perangkat ini masih berisi data akun lain. Masuk dengan akun ini akan menghapus data itu dari perangkat."
                )
            }
        }
    }
}
