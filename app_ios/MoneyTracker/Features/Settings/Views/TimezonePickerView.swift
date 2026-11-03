import SwiftUI

/// Timezone with search: Indonesia first, then the rest of the IANA list.
struct TimezonePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let selected: String
    let onSelect: (String) -> Void
    @State private var query = ""

    var body: some View {
        let indonesia = TimezoneOption.indonesia.filter { $0.matches(query) }
        let others = TimezoneOption.others.filter { $0.matches(query) }
        List {
            if !indonesia.isEmpty {
                Section("Indonesia") { ForEach(indonesia) { row($0) } }
            }
            if !others.isEmpty {
                Section("Lainnya") { ForEach(others) { row($0) } }
            }
        }
        .navigationTitle("Timezone")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Cari timezone")
    }

    private func row(_ option: TimezoneOption) -> some View {
        Button {
            onSelect(option.identifier)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(option.city).foregroundStyle(.primary)
                    Text(option.identifier).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(option.offsetText).font(.footnote).foregroundStyle(.secondary)
                if option.identifier == selected {
                    Image(systemName: "checkmark").foregroundStyle(AppColors.seed)
                }
            }
        }
    }
}
