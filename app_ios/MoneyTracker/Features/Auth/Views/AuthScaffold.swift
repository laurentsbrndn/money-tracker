import SwiftUI

/// Title, subtitle, and content of an auth screen, scrolling so the keyboard never hides the
/// button.
struct AuthScaffold<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: Text?
    @ViewBuilder var content: Content

    init(title: LocalizedStringKey, subtitle: Text? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.largeTitle.bold())
                    subtitle?.foregroundStyle(.secondary)
                }
                content
            }
            .padding(20)
            .frame(maxWidth: 480, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A field with its validation message underneath.
struct AuthField<Field: View>: View {
    let error: String?
    @ViewBuilder var field: Field

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            field
                .padding(12)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            if let error {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 28)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .background(
                AppColors.seed.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4),
                in: RoundedRectangle(cornerRadius: 12))
    }
}
