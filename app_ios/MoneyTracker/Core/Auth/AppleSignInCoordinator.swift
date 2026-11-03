import AuthenticationServices
import CryptoKit
import Foundation

/// What the server needs from a Sign in with Apple result (API.md §2).
struct AppleCredential: Sendable {
    let identityToken: String
    /// The value put into the Apple request; the server compares it with the token's `nonce`.
    let nonce: String
    /// Only present on the first login of this Apple ID; send it to the server right then.
    let fullName: String?
}

/// Helpers around `SignInWithAppleButton` (FRONTEND_IOS §4.2).
enum AppleSignInCoordinator {
    /// Fills the request (scopes and a fresh nonce) and returns the nonce that was set.
    static func prepare(_ request: ASAuthorizationAppleIDRequest) -> String {
        request.requestedScopes = [.fullName, .email]
        let hashed = SHA256.hash(data: Data(randomNonce().utf8)).map { String(format: "%02x", $0) }
            .joined()
        request.nonce = hashed
        return hashed
    }

    /// Nil when `authorization` carries no usable Apple ID credential.
    static func credential(from authorization: ASAuthorization, nonce: String) -> AppleCredential? {
        guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = apple.identityToken,
            let token = String(data: tokenData, encoding: .utf8)
        else { return nil }
        let name = apple.fullName.flatMap { components -> String? in
            let text = PersonNameComponentsFormatter().string(from: components)
                .trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? nil : String(text.prefix(100))
        }
        return AppleCredential(identityToken: token, nonce: nonce, fullName: name)
    }

    /// True when the user dismissed the Apple sheet.
    static func isCancellation(_ error: any Error) -> Bool {
        (error as? ASAuthorizationError)?.code == .canceled
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in charset.randomElement(using: &generator)! })
    }
}
