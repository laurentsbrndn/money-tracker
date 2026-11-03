/// Runs `body` for every value of a database observation on the main actor, until the stream
/// ends or the surrounding task is cancelled. An observation that fails (the database was wiped
/// on logout) simply ends: the screen is on its way out.
@MainActor
func forEachValue<S: AsyncSequence>(
    _ sequence: S, _ body: @MainActor (S.Element) -> Void
) async where S.Element: Sendable {
    do {
        for try await value in sequence { body(value) }
    } catch {}
}

/// Runs several observation loops side by side until all end; cancelling the surrounding task
/// cancels every loop.
@MainActor
func concurrently(_ jobs: [@MainActor () async -> Void]) async {
    let tasks = jobs.map { job in Task { @MainActor in await job() } }
    await withTaskCancellationHandler {
        for task in tasks { await task.value }
    } onCancel: {
        for task in tasks { task.cancel() }
    }
}
