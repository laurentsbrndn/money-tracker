import SwiftUI

/// Large numeric keypad of the entry form (FRONTEND_IOS §4.6). Emits digits (including `000`)
/// and backspace; the form owns the value.
struct NumpadView: View {
    let onDigits: (String) -> Void
    let onBackspace: () -> Void
    var onClear: (() -> Void)?

    private let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["000", "0", "⌫"]]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        if key == "⌫" {
            Button(action: onBackspace) {
                Image(systemName: "delete.left").font(.title3).frame(
                    maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.bordered)
            .simultaneousGesture(LongPressGesture().onEnded { _ in onClear?() })
            .accessibilityLabel("Hapus digit")
        } else {
            Button {
                onDigits(key)
            } label: {
                Text(key).font(.title2).frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.bordered)
        }
    }
}
