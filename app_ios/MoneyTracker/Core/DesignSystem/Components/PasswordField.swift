import SwiftUI

/// A secure text field with a show/hide toggle.
struct PasswordField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    var contentType: UITextContentType = .password

    @State private var revealed = false

    var body: some View {
        HStack {
            Group {
                if revealed {
                    TextField(title, text: $text)
                } else {
                    SecureField(title, text: $text)
                }
            }
            .textContentType(contentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            Button {
                revealed.toggle()
            } label: {
                Image(systemName: revealed ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(revealed ? "Sembunyikan password" : "Tampilkan password")
        }
    }
}
