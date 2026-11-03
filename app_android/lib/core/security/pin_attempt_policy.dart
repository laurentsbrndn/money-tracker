/// How long a wrong-PIN streak locks the PIN pad (growing delays). The
/// [freeAttempts]-th consecutive wrong PIN is the first to lock the pad; every
/// further wrong try waits longer. The counter only resets on a correct PIN,
/// so waiting out a delay does not give a fresh set of attempts.
const int freeAttempts = 5;

const List<Duration> _delays = [
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 5),
  Duration(minutes: 15),
  Duration(minutes: 30),
];

/// The delay to impose after the [failures]-th consecutive wrong PIN; null
/// for the first [freeAttempts] - 1 wrong tries.
Duration? lockoutAfterFailures(int failures) {
  if (failures < freeAttempts) {
    return null;
  }
  final index = failures - freeAttempts;
  return _delays[index >= _delays.length ? _delays.length - 1 : index];
}

/// Seconds left until [lockedUntil], 0 when it has passed or is unset.
int lockoutSecondsLeft(DateTime? lockedUntil, DateTime now) {
  if (lockedUntil == null || !lockedUntil.isAfter(now)) {
    return 0;
  }
  return (lockedUntil.difference(now).inMilliseconds / 1000).ceil();
}
