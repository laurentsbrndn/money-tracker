import SwiftUI

/// The six dots that fill while a PIN is typed.
struct PinDotsView: View {
    let filled: Int
    var total = PinHasher.pinLength

    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < filled ? Color.primary : Color.clear)
                    .overlay(Circle().stroke(Color.secondary, lineWidth: 1.5))
                    .frame(width: 16, height: 16)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(filled) dari \(total) digit")
    }
}

/// A 0-9 keypad with backspace for entering a PIN.
struct PinPadView: View {
    let onDigit: (Character) -> Void
    let onBackspace: () -> Void
    var isDisabled = false

    private let rows: [[String]] = [
        ["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"],
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { key in
                        key.isEmpty ? AnyView(spacer) : AnyView(button(key))
                    }
                }
            }
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
    }

    private var spacer: some View {
        Color.clear.frame(width: 76, height: 76)
    }

    @ViewBuilder
    private func button(_ key: String) -> some View {
        Button {
            if key == "⌫" {
                onBackspace()
            } else if let digit = key.first {
                onDigit(digit)
            }
        } label: {
            Group {
                if key == "⌫" {
                    Image(systemName: "delete.left").font(.title2)
                } else {
                    Text(key).font(.title.weight(.medium))
                }
            }
            .frame(width: 76, height: 76)
            .background(key == "⌫" ? Color.clear : Color(.secondarySystemBackground), in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .accessibilityLabel(key == "⌫" ? String(localized: "Hapus digit") : key)
    }
}
