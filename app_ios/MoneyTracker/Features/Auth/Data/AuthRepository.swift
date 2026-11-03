import Foundation

/// Online-only auth calls (ARCHITECTURE §4). Starting the session from the response is left to
/// the caller. Failures arrive as `ClientError`; see `APIFailure` and `ErrorMessages`.
struct AuthRepository: Sendable {
    let client: Client

    /// The device's IANA timezone, sent at registration; `Asia/Jakarta` (the server default) when
    /// the device reports none the app can use.
    private var timezone: String {
        let identifier = TimeZone.current.identifier
        return UserClock.isValid(timezone: identifier) ? identifier : UserClock.defaultTimezone
    }

    func register(name: String, email: String, password: String) async throws
        -> Components.Schemas.AuthResponse
    {
        let output = try await client.register(
            .init(
                body: .json(
                    .init(name: name, email: email, password: password, timezone: timezone))))
        return try output.created.body.json
    }

    func login(email: String, password: String) async throws -> Components.Schemas.AuthResponse {
        try await client.login(.init(body: .json(.init(email: email, password: password)))).ok.body
            .json
    }

    func loginWithApple(_ credential: AppleCredential) async throws
        -> Components.Schemas.AuthResponse
    {
        try await client.loginWithApple(
            .init(
                body: .json(
                    .init(
                        identity_token: credential.identityToken, nonce: credential.nonce,
                        name: credential.fullName, timezone: timezone)))
        ).ok.body.json
    }

    func loginWithGoogle(_ credential: GoogleCredential) async throws
        -> Components.Schemas.AuthResponse
    {
        try await client.loginWithGoogle(
            .init(body: .json(.init(id_token: credential.idToken, timezone: timezone)))
        ).ok.body.json
    }

    func forgotPassword(email: String) async throws {
        _ = try await client.forgotPassword(.init(body: .json(.init(email: email))))
    }

    func resetPassword(email: String, code: String, newPassword: String) async throws {
        _ = try await client.resetPassword(
            .init(body: .json(.init(email: email, code: code, new_password: newPassword))))
    }

    func verifyEmail(code: String) async throws -> SessionUser {
        SessionUser(
            try await client.verifyEmail(.init(body: .json(.init(code: code)))).ok.body.json.user)
    }

    func resendEmailVerification() async throws {
        _ = try await client.resendEmailVerification()
    }
}
