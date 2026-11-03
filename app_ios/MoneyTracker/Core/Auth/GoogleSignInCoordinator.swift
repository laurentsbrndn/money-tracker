import GoogleSignIn
import UIKit

/// Thrown when Google sign-in cannot be used (misconfigured build).
struct GoogleSignInUnavailable: Error {}

struct GoogleCredential: Sendable {
    let idToken: String
}

/// Google sign-in through the GoogleSignIn SDK (FRONTEND_IOS §1). Only the ID token is needed;
/// the server verifies it against `GOOGLE_CLIENT_IDS`, which includes the iOS client ID.
@MainActor
struct GoogleSignInCoordinator {
    let clientID: String

    /// The Google ID token, or nil if the user dismissed the sheet.
    func signIn() async throws -> GoogleCredential? {
        guard !clientID.isEmpty, let presenter = Self.topViewController() else {
            throw GoogleSignInUnavailable()
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let token = result.user.idToken?.tokenString else { return nil }
            return GoogleCredential(idToken: token)
        } catch let error as NSError
            where error.domain == kGIDSignInErrorDomain
            && error.code == GIDSignInError.canceled.rawValue
        {
            return nil
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
