import SwiftUI

/// Atur goal budget (Flow 6 step 1).
struct BudgetGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: BudgetGoalViewModel

    init(container: AppContainer) {
        _model = State(initialValue: BudgetGoalViewModel(container: container))
    }

    var body: some View {
        Form {
            Section {
                Text("Bagi income bulanan ke needs, wants, dan savings. Total harus 100%.")
                Text("Berlaku mulai \(model.month.titleText).").foregroundStyle(.secondary)
            }
            BudgetGoalForm(model: model)
            if let message = model.errorMessage {
                Section { Text(message).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Atur goal budget")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Simpan") { Task { if await model.save() { dismiss() } } }
                    .disabled(!model.isValid || model.busy)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .task { await model.load() }
    }
}
