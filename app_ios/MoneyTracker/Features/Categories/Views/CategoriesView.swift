import SwiftUI

struct CategoriesView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: CategoriesViewModel
    @State private var toDelete: CategoryRecord?

    init(container: AppContainer) {
        _model = State(initialValue: CategoriesViewModel(container: container))
    }

    var body: some View {
        List {
            Section {
                Picker("Tipe", selection: $model.type) {
                    Text("Pengeluaran").tag("expense")
                    Text("Pemasukan").tag("income")
                }
                .pickerStyle(.segmented)
            }
            if model.loaded && model.shown.isEmpty {
                Text("Belum ada kategori").foregroundStyle(.secondary)
            }
            Section {
                ForEach(model.shown) { category in
                    NavigationLink(value: AppRoute.categoryForm(id: category.id, type: nil)) {
                        CategoryRow(category: category)
                    }
                    .swipeActions(edge: .trailing) {
                        if !category.isDefault {
                            Button("Hapus", role: .destructive) { toDelete = category }
                        }
                        Button(category.archivedAt == nil ? "Arsipkan" : "Aktifkan lagi") {
                            Task {
                                await model.setArchived(
                                    category, archived: category.archivedAt == nil)
                            }
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .leading) {
                        Button(category.isHidden ? "Tampilkan" : "Sembunyikan") {
                            Task { await model.setHidden(category, hidden: !category.isHidden) }
                        }
                        .tint(.indigo)
                    }
                }
                .onMove { source, destination in
                    Task { await model.move(from: source, to: destination) }
                }
            } footer: {
                Text(
                    "Geser untuk menyembunyikan atau mengarsipkan. Tahan dan geser untuk mengurutkan."
                )
            }
        }
        .environment(\.editMode, .constant(.inactive))
        .navigationTitle("Kategori")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Tambah kategori", systemImage: "plus") {
                    container.router.morePath.append(
                        AppRoute.categoryForm(id: nil, type: model.type))
                }
            }
            ToolbarItem(placement: .secondaryAction) { EditButton() }
        }
        .task { await model.start() }
        .alert("Hapus kategori ini permanen?", isPresented: .constant(toDelete != nil)) {
            Button("Batal", role: .cancel) { toDelete = nil }
            Button("Hapus", role: .destructive) {
                if let category = toDelete { Task { await model.delete(category) } }
                toDelete = nil
            }
        }
        .alert("Terjadi kesalahan", isPresented: .constant(model.errorMessage != nil)) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}
