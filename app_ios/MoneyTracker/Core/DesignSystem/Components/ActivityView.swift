import SwiftUI
import UIKit

/// The system share sheet for files. `onFinish` fires when it closes, whether the user shared or
/// cancelled, so a temporary file can be deleted as soon as the result is known.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in onFinish() }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
