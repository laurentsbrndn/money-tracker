import 'backoff.dart';
import 'outbox_item.dart';
import 'wire_models.dart';

/// What to do with one outbox entry after the server answered
/// (SYNC_PROTOCOL §8.4).
sealed class PushAction {
  const PushAction();
}

/// `applied`: remove the entry. The row is marked synced only if it has not
/// changed since it was sent (see [rowUnchangedSinceSend]).
class RemoveApplied extends PushAction {
  const RemoveApplied(this.serverVersion);

  final int? serverVersion;
}

/// `stale`: remove the entry; the row stays pending until a pull replaces it.
class RemoveStale extends PushAction {
  const RemoveStale(this.serverVersion);

  /// `server_version` of the row the server kept; null if it did not say.
  final int? serverVersion;
}

/// Retryable failure: keep the entry (no longer in flight), back off.
class RetryLater extends PushAction {
  const RetryLater({
    required this.attempts,
    required this.nextAttemptAt,
    required this.message,
  });

  final int attempts;
  final DateTime nextAttemptAt;
  final String message;
}

/// Non-retryable failure: remove the entry and mark the row `failed`.
class FailTerminal extends PushAction {
  const FailTerminal({required this.code, required this.message});

  final String code;
  final String message;
}

PushAction planPushResult(
  OutboxItem item,
  PushResultInfo? result,
  DateTime now,
) {
  if (result == null) {
    // The server did not answer for this entry; send it again later.
    return _retry(item, now, 'no_result', 'Server tidak mengembalikan hasil');
  }
  switch (result.status) {
    case 'applied':
      return RemoveApplied(result.serverVersion);
    case 'stale':
      return RemoveStale(result.serverVersion);
    case 'rejected':
      final code = result.errorCode ?? 'unknown';
      final message = result.errorMessage ?? code;
      if (result.retryable) {
        return _retry(item, now, code, message);
      }
      return FailTerminal(code: code, message: message);
    default:
      return _retry(item, now, 'unknown_status', result.status);
  }
}

/// A whole-request failure that is not worth an immediate retry (4xx other
/// than 401): count it against the entry like a retryable rejection.
PushAction planBatchFailure(OutboxItem item, DateTime now, String message) =>
    _retry(item, now, 'request_failed', message);

PushAction _retry(OutboxItem item, DateTime now, String code, String message) {
  final attempts = item.attempts + 1;
  if (attempts >= maxEntryAttempts) {
    return FailTerminal(code: code, message: message);
  }
  return RetryLater(
    attempts: attempts,
    nextAttemptAt: now.add(backoffFor(attempts)),
    message: '$code: $message',
  );
}

/// Whether the local row still holds what was sent: `applied` may then mark
/// it synced. A newer local edit has a different `updated_at`.
bool rowUnchangedSinceSend(DateTime? rowUpdatedAt, DateTime sentUpdatedAt) =>
    rowUpdatedAt != null &&
    rowUpdatedAt.millisecondsSinceEpoch == sentUpdatedAt.millisecondsSinceEpoch;
