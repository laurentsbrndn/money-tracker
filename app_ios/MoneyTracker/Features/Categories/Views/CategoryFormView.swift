import SwiftUI

struct CategoryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: CategoryFormViewModel

    init(container: AppContainer, categoryId: String?, type: String?) {
        _model = State(
            initialValue: CategoryFormViewModel(
                container: container, categoryId: categoryId, type: type))
    }

    var body: some View {
        Form {
            Section {
                TextField("Nama kategori", text: $model.name)
                if model.type == "expense" {
                    Picker("Alokasi default", selection: $model.allocation) {
                        Text("Needs").tag("needs")
                        Text("Wants").tag("wants")
                        Text("Savings").tag("savings")
                    }
                }
            } footer: {
                if model.type == "expense" { Text("Hanya berlaku untuk transaksi baru.") }
            }
            if model.canChangeIcon {
                Section("Ikon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 10)], spacing: 10)
                    {
                        ForEach(CategoryIcons.pickable, id: \.self) { key in
                            Image(systemName: CategoryIcons.symbol(key))
                                .frame(width: 44, height: 44)
                                .background(
                                    model.icon == key ? AppColors.seed.opacity(0.2) : Color.clear,
                                    in: Circle()
                                )
                                .overlay(
                                    Circle().stroke(model.icon == key ? AppColors.seed : .clear)
                                )
                                .onTapGesture { model.icon = key }
                        }
                    }
                }
            }
            Section("Warna") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 10)], spacing: 10) {
                    ForEach(CategoryIcons.palette, id: \.self) { hex in
                        Circle().fill(CategoryIcons.color(hex)).frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: "checkmark").foregroundStyle(.white)
                                    .opacity(model.color == hex ? 1 : 0)
                            )
                            .onTapGesture { model.color = hex }
                    }
                }
            }
            if let message = model.errorMessage {
                Section { Text(message).foregroundStyle(.red) }
            }
        }
        .navigationTitle(model.isEditing ? "Ubah kategori" : "Tambah kategori")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Simpan") { Task { await model.save() } }.disabled(model.busy)
            }
        }
        .task { await model.load() }
        .onChange(of: model.saved) { _, saved in if saved { dismiss() } }
    }
}
