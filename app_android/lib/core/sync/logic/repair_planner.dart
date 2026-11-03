import 'outbox_item.dart';
import 'push_result_planner.dart';
import 'wire_models.dart';

/// Records whose local row must be re-fetched from the server because a normal
/// pull can no longer deliver them (SYNC_PROTOCOL §8.4, "stale yang tersangkut").
///
/// A pull skips a record while it has an outbox entry, yet the cursor still
/// moves past it. If that entry is then answered `stale`, the server row's
/// `server_version` is at or below the cursor and no later pull returns it.
/// [cursor] is the local `pull_cursor` before this cycle's pull. A stale answer
/// without a `server_version` is repaired too, to be safe.
Set<String> staleRepairKeys(
  List<(OutboxItem, PushAction)> answered,
  int cursor,
) {
  final keys = <String>{};
  for (final (item, action) in answered) {
    if (action is! RemoveStale) {
      continue;
    }
    final version = action.serverVersion;
    if (version == null || version <= cursor) {
      keys.add(recordKey(item.entity, item.recordId));
    }
  }
  return keys;
}

/// The part of a from-the-start pull page to write: rows listed in
/// [repairKeys] that have no outbox entry now (same rule as a normal pull).
List<PullChangeItem> planRepairPull(
  List<PullChangeItem> changes,
  Set<String> repairKeys,
  Set<String> outboxKeys,
) => [
  for (final change in changes)
    if (repairKeys.contains(recordKey(change.entity, change.id)) &&
        !outboxKeys.contains(recordKey(change.entity, change.id)))
      change,
];
