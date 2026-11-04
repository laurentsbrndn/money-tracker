#if DEBUG
    import SwiftUI

    private func export(_ variant: PreviewVariant) -> some View {
        PreviewHost(variant: variant) { container in
            PreviewStack(container: container, tab: .more) { ExportView(container: container) }
        }
    }

    #Preview("Export — Premium") { export(.premium) }
    #Preview("Export — gratis (terkunci)") { export(.populated) }
    #Preview("Export — mode gelap") { export(.dark) }
#endif
