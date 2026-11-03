import SwiftUI

/// Set, change, or remove the PIN.
struct PinSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: PinSetupViewModel
    var onFinished: (() -> Void)?

    init(container: AppContainer, mode: PinSetupMode, onFinished: (() -> Void)? = nil) {
        _model = State(initialValue: PinSetupViewModel(container: container, mode: mode))
        self.onFinished = onFinished
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                Text(model.prompt).font(.title3.bold())
                Text(model.message ?? " ")
                    .font(.subheadline).foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            PinDotsView(filled: model.pin.count)
            PinPadView(onDigit: model.append, onBackspace: model.backspace, isDisabled: model.busy)
            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle(model.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: model.finished) { _, done in
            guard done else { return }
            onFinished?()
            dismiss()
        }
    }
}
