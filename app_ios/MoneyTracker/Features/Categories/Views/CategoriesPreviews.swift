#if DEBUG
    import SwiftUI

    private func categories(_ variant: PreviewVariant) -> some View {
        PreviewHost(variant: variant) { container in
            PreviewStack(container: container, tab: .more) { CategoriesView(container: container) }
        }
    }

    #Preview("Kategori — berisi") { categories(.populated) }
    #Preview("Kategori — mode gelap") { categories(.dark) }

    #Preview("Form kategori — baru") {
        PreviewHost(variant: .populated) { container in
            NavigationStack {
                CategoryFormView(container: container, categoryId: nil, type: "expense")
            }
        }
    }

    #Preview("Form kategori — ubah") {
        PreviewHost(variant: .populated) { container in
            NavigationStack {
                CategoryFormView(container: container, categoryId: "cat-food", type: nil)
            }
        }
    }
#endif
