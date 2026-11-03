import SwiftUI

/// The "Transaksi dihapus · Urungkan" bar that stays for five seconds after a delete.
struct UndoBanner: View {
    let message: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        HStack {
            Text(message)
            Spacer()
            Button("Urungkan", action: action).fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
