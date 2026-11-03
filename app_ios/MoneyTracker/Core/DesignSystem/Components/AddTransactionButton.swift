import SwiftUI

/// The floating "+" that opens the transaction form.
struct AddTransactionButton: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        Button {
            container.router.openTransactionForm()
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(AppColors.seed, in: Circle())
                .shadow(radius: 3, y: 2)
        }
        .padding(20)
        .accessibilityLabel("Catat transaksi")
    }
}
