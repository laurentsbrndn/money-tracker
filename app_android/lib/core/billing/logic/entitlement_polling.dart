/// How the polling after a purchase or a restore ended.
enum PollOutcome {
  /// The server reports premium.
  confirmed,

  /// The deadline passed without the server reporting premium. The purchase
  /// may still arrive (the webhook can be late): the next sync picks it up.
  timedOut,

  /// A failure that polling again cannot fix (for example an expired login).
  aborted,
}

class PollResult {
  const PollResult(this.outcome, this.attempts, [this.error]);

  final PollOutcome outcome;
  final int attempts;

  /// The failure behind [PollOutcome.aborted], or the last transient failure
  /// behind [PollOutcome.timedOut].
  final Object? error;
}

/// Thrown by the check passed to [pollUntilPremium] when polling must stop.
class PollAbort implements Exception {
  const PollAbort(this.reason);

  final Object reason;
}

/// Overall limit of the polling after a purchase.
const Duration entitlementPollTimeout = Duration(seconds: 30);

/// Pauses between attempts: 1, 2, 3, 4 s, then 5 s until the deadline.
const List<Duration> entitlementPollDelays = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 3),
  Duration(seconds: 4),
  Duration(seconds: 5),
];

/// Asks the server, again and again, until it reports premium or [timeout]
/// has passed. RevenueCat tells the server about a purchase through a
/// webhook that can be late, so premium is never taken from the store SDK
/// (FRONTEND_FLUTTER §4.4); this waits for the server instead.
///
/// [isPremium] returns the server's answer. A thrown [PollAbort] ends the
/// polling at once; any other error (offline, 5xx) counts as "not yet" and is
/// retried. [now] and [wait] are injected so the schedule can be run without
/// real time.
Future<PollResult> pollUntilPremium({
  required Future<bool> Function() isPremium,
  Duration timeout = entitlementPollTimeout,
  List<Duration> delays = entitlementPollDelays,
  DateTime Function()? now,
  Future<void> Function(Duration)? wait,
}) async {
  final clock = now ?? DateTime.now;
  final pause = wait ?? (d) => Future<void>.delayed(d);
  final deadline = clock().add(timeout);
  var attempts = 0;
  Object? lastError;
  while (true) {
    attempts++;
    try {
      if (await isPremium()) {
        return PollResult(PollOutcome.confirmed, attempts);
      }
      lastError = null;
    } on PollAbort catch (abort) {
      return PollResult(PollOutcome.aborted, attempts, abort.reason);
    } on Object catch (error) {
      lastError = error;
    }
    final delay = delays[(attempts - 1).clamp(0, delays.length - 1)];
    if (clock().add(delay).isAfter(deadline)) {
      return PollResult(PollOutcome.timedOut, attempts, lastError);
    }
    await pause(delay);
  }
}
