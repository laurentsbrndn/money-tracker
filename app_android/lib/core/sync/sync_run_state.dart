/// How the last sync run ended.
enum SyncOutcome {
  /// Everything pushed and pulled.
  synced,

  /// Another run was already going; it will run again afterwards.
  skipped,

  /// No connection (or the request never got through).
  offline,

  /// Not signed in, or the session cannot be renewed (SYNC_PROTOCOL §11).
  needsLogin,

  /// The server answered with an error; retried with backoff.
  failed,
}

class SyncRunState {
  const SyncRunState({
    this.running = false,
    this.outcome,
    this.pulledRows = 0,
    this.lastError,
  });

  final bool running;
  final SyncOutcome? outcome;

  /// Rows written by pulls since the engine started; drives the progress of
  /// the initial sync screen.
  final int pulledRows;
  final String? lastError;

  SyncRunState copyWith({
    bool? running,
    SyncOutcome? outcome,
    int? pulledRows,
    String? lastError,
  }) => SyncRunState(
    running: running ?? this.running,
    outcome: outcome ?? this.outcome,
    pulledRows: pulledRows ?? this.pulledRows,
    lastError: lastError,
  );
}
