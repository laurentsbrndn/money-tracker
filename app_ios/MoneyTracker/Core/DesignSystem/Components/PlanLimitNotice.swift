import SwiftUI

/// A refused save, as a form section: the message in red and, when the cause is the free-plan
/// limit, the way to the paywall.
struct FormErrorSection: View {
    @Environment(AppContainer.self) private var container
    let message: String?
    var planLimit = false

    var body: some View {
        if let message {
            Section {
                Text(message).foregroundStyle(.red)
                if planLimit {
                    Button("Lihat Premium") { container.router.push(.paywall(restore: false)) }
                }
            }
        }
    }
}
