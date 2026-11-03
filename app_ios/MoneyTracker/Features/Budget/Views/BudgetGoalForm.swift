import SwiftUI

/// Percentages, presets, and planned income; shared by the goal screen and the setup wizard.
struct BudgetGoalForm: View {
    @Bindable var model: BudgetGoalViewModel

    var body: some View {
        Section("Preset") {
            Picker("Preset", selection: presetBinding) {
                ForEach(Array(BudgetGoalInput.presets.enumerated()), id: \.offset) { _, preset in
                    Text("\(preset.needs)/\(preset.wants)/\(preset.savings)")
                        .tag(Optional(preset.needs * 10_000 + preset.wants * 100 + preset.savings))
                }
            }
            .pickerStyle(.segmented)
        }
        Section {
            percentRow("Needs (%)", text: $model.needsText)
            percentRow("Wants (%)", text: $model.wantsText)
            percentRow("Savings (%)", text: $model.savingsText)
            HStack {
                Text("Total \(model.total)%")
                Spacer()
                if model.isValid {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(AppColors.income)
                }
            }
            .foregroundStyle(model.isValid ? Color.primary : AppColors.expense)
            .font(.subheadline.weight(.semibold))
        }
        Section {
            MoneyField(title: "Rencana income bulanan (opsional)", text: $model.plannedIncomeText)
        } footer: {
            Text("Dipakai sebagai dasar bila lebih besar dari income yang tercatat.")
        }
    }

    private var presetBinding: Binding<Int?> {
        Binding(
            get: {
                let input = model.input
                return BudgetGoalInput.presets.first {
                    $0.needs == input.needs && $0.wants == input.wants
                        && $0.savings == input.savings
                }.map { $0.needs * 10_000 + $0.wants * 100 + $0.savings }
            },
            set: { code in
                guard let code else { return }
                model.apply((code / 10_000, (code / 100) % 100, code % 100))
            })
    }

    private func percentRow(_ title: LocalizedStringKey, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                .frame(width: 70).monospacedDigit()
                .onChange(of: text.wrappedValue) { _, value in
                    let digits = String(value.filter(\.isNumber).prefix(3))
                    if digits != value { text.wrappedValue = digits }
                }
        }
    }
}
