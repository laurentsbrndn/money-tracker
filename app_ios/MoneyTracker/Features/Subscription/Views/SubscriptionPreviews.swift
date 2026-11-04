#if DEBUG
    import SwiftUI

    private func paywall(_ variant: PreviewVariant) -> some View {
        PreviewHost(variant: variant) { container in
            PreviewStack(container: container, tab: .more) { PaywallView() }
        }
    }

    private func subscription(_ variant: PreviewVariant) -> some View {
        PreviewHost(variant: variant) { container in
            PreviewStack(container: container, tab: .more) { SubscriptionView() }
        }
    }

    #Preview("Paywall") { paywall(.populated) }
    #Preview("Paywall — mode gelap") { paywall(.dark) }
    #Preview("Langganan — gratis") { subscription(.populated) }
    #Preview("Langganan — Premium aktif") { subscription(.premium) }
#endif
