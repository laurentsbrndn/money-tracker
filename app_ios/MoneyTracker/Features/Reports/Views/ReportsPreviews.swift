#if DEBUG
    import SwiftUI

    private func reports(_ variant: PreviewVariant, _ kind: ReportKind = .category) -> some View {
        PreviewHost(variant: variant) { container in
            PreviewStack(container: container, tab: .more) {
                ReportsPreviewHost(container: container, kind: kind)
            }
        }
    }

    /// Opens `ReportsView` on a given report (the real screen starts on "Per kategori").
    private struct ReportsPreviewHost: View {
        let container: AppContainer
        let kind: ReportKind

        var body: some View {
            ReportsView(container: container, initialKind: kind)
        }
    }

    #Preview("Laporan — per kategori") { reports(.premium) }
    #Preview("Laporan — sumber income") { reports(.premium, .source) }
    #Preview("Laporan — tren") { reports(.premium, .trend) }
    #Preview("Laporan — perbandingan") { reports(.premium, .comparison) }
    #Preview("Laporan — selisih tidak tercatat") { reports(.premium, .unrecorded) }
    #Preview("Laporan — tren terkunci (gratis)") { reports(.populated, .trend) }
    #Preview("Laporan — nominal disembunyikan") { reports(.hiddenAmounts) }
    #Preview("Laporan — mode gelap") { reports(.dark, .trend) }
    #Preview("Laporan — kosong") { reports(.empty) }
#endif
