import SwiftUI

/// Text field for a rupiah amount: digits only, grouped as you type. Read the value with
/// `MoneyFormatter.value(of:allowNegative:)`.
struct MoneyField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    /// A leading minus is kept (opening balances may be negative).
    var allowNegative = false

    var body: some View {
        HStack {
            Text("Rp").foregroundStyle(.secondary)
            TextField(title, text: $text)
                .keyboardType(allowNegative ? .numbersAndPunctuation : .numberPad)
                .monospacedDigit()
                .onChange(of: text) { _, newValue in
                    let formatted = MoneyFormatter.formatInput(
                        newValue, allowNegative: allowNegative)
                    if formatted != newValue { text = formatted }
                }
        }
    }
}
