#if DEBUG
    import SwiftUI

    private func budget(_ variant: PreviewVariant) -> some View {
        PreviewHost(variant: variant) { container in
            PreviewStack(container: container, tab: .budget) { BudgetView(container: container) }
        }
    }

    #Preview("Budget — kosong") { budget(.empty) }
    #Preview("Budget — berisi") { budget(.populated) }
    #Preview("Budget — nominal disembunyikan") { budget(.hiddenAmounts) }
    #Preview("Budget — mode gelap") { budget(.dark) }

    #Preview("Atur goal") {
        PreviewHost(variant: .populated) { container in
            PreviewStack(container: container, tab: .budget) {
                BudgetGoalView(container: container)
            }
        }
    }
#endif
