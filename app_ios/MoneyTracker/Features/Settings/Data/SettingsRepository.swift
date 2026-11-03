import Foundation

/// Online-only account calls of the settings screens (ARCHITECTURE §4).
struct SettingsRepository: Sendable {
    let client: Client

    func updateName(_ name: String) async throws -> SessionUser {
        SessionUser(
            try await client.updateMe(.init(body: .json(.init(name: name)))).ok.body.json.user)
    }

    func changePassword(current: String, new: String) async throws {
        _ = try await client.changePassword(
            .init(body: .json(.init(current_password: current, new_password: new))))
    }

    /// `DELETE /v1/me`; `confirmation` is the password (users with a password) or the word
    /// `HAPUS`.
    func deleteAccount(confirmation: String) async throws {
        _ = try await client.deleteMe(.init(body: .json(.init(confirmation: confirmation))))
    }
}
