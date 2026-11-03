import 'outbox_item.dart';
import 'wire_models.dart';

/// Which pulled changes to write (SYNC_PROTOCOL §9.4).
class PullPlan {
  const PullPlan({required this.toApply, required this.skipped});

  final List<PullChangeItem> toApply;

  /// Records with a local outbox entry: the local change wins until it has
  /// been pushed, and the server decides by last-write-wins.
  final List<PullChangeItem> skipped;
}

/// [outboxKeys] holds [recordKey]s of every record that has an outbox entry,
/// in flight or not. The deciding factor is the entry, not `sync_status`.
PullPlan planPull(List<PullChangeItem> changes, Set<String> outboxKeys) {
  final toApply = <PullChangeItem>[];
  final skipped = <PullChangeItem>[];
  for (final change in changes) {
    if (outboxKeys.contains(recordKey(change.entity, change.id))) {
      skipped.add(change);
    } else {
      toApply.add(change);
    }
  }
  return PullPlan(toApply: toApply, skipped: skipped);
}

/// The cursor never moves backwards.
int nextPullCursor(int current, int pageNextCursor) =>
    pageNextCursor > current ? pageNextCursor : current;
