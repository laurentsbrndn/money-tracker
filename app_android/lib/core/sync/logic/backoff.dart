/// Entries that failed retryably this many times become non-retryable
/// (SYNC_PROTOCOL §8.4).
const int maxEntryAttempts = 10;

/// Delay after the [attempts]-th consecutive retryable failure (1-based):
/// 5 s, 15 s, 1 m, 5 m, then 15 m (SYNC_PROTOCOL §7).
Duration backoffFor(int attempts) {
  const steps = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(minutes: 1),
    Duration(minutes: 5),
  ];
  if (attempts < 1) {
    return Duration.zero;
  }
  return attempts <= steps.length
      ? steps[attempts - 1]
      : const Duration(minutes: 15);
}
