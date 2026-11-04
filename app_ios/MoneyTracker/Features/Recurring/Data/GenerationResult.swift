/// What one run of the recurring generator created.
struct GenerationResult: Sendable, Equatable {
    var created = 0
    /// How many of them wait for the user to record or skip them.
    var pendingConfirmation = 0
}
