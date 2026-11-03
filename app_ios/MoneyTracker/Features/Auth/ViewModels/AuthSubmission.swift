import Observation

/// Runs a login/register action and keeps its busy/error state. If the device holds another
/// user's data (SYNC_PROTOCOL §11) it asks first (`mismatch`), and the same action runs again
/// with `discardLocalData` true once the user agrees.
@Observable
@MainActor
final class AuthSubmission {
    private(set) var busy = false
    var errorMessage: String?
    var mismatch: UserMismatchError?

    private var pending: (@MainActor (Bool) async throws -> Void)?

    func run(_ action: @escaping @MainActor (_ discardLocalData: Bool) async throws -> Void) async {
        pending = action
        await perform(discardLocalData: false)
    }

    /// The user agreed to replace the other account's data on this device.
    func confirmDiscard() async {
        mismatch = nil
        await perform(discardLocalData: true)
    }

    func cancelDiscard() {
        mismatch = nil
        pending = nil
    }

    private func perform(discardLocalData: Bool) async {
        guard let pending else { return }
        busy = true
        errorMessage = nil
        defer { busy = false }
        do {
            try await pending(discardLocalData)
            self.pending = nil
        } catch let error as UserMismatchError {
            mismatch = error
        } catch is GoogleSignInUnavailable {
            errorMessage = String(localized: "Login Google belum dikonfigurasi di build ini.")
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }
}
