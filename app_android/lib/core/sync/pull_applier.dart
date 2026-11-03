import 'dart:convert';

import '../database/app_database.dart';
import 'entity_stores.dart';
import 'logic/pull_planner.dart';
import 'logic/repair_planner.dart';
import 'logic/wire_models.dart';

const String pullCursorKey = 'pull_cursor';
const String entitlementKey = 'entitlement';

/// Applies one pulled page to the local database (SYNC_PROTOCOL §9.4), in one
/// transaction together with the new cursor.
class PullApplier {
  const PullApplier(this._db, this._stores);

  final AppDatabase _db;
  final EntityStores _stores;

  Future<int> currentCursor() async =>
      int.tryParse(await _db.syncStateDao.read(pullCursorKey) ?? '') ?? 0;

  /// Returns how many rows were written.
  Future<int> apply(PullPage page) => _db.transaction(() async {
    final plan = planPull(page.changes, await _db.outboxDao.recordKeys());
    var written = 0;
    for (final change in plan.toApply) {
      // An entity this client version does not know is skipped, not fatal.
      final store = _stores.maybeOf(change.entity);
      if (store == null) {
        continue;
      }
      await store.saveFromServer(change.data, change.serverVersion);
      written++;
    }
    final cursor = nextPullCursor(await currentCursor(), page.nextCursor);
    await _db.syncStateDao.write(pullCursorKey, cursor.toString());
    final entitlement = page.entitlementJson;
    if (entitlement != null) {
      await _db.syncStateDao.write(entitlementKey, jsonEncode(entitlement));
    }
    return written;
  });

  /// Applies the rows of a from-the-start page that are in [repairKeys] and
  /// have no outbox entry. Returns the keys written. The cursor is untouched.
  Future<Set<String>> applyRepair(PullPage page, Set<String> repairKeys) =>
      _db.transaction(() async {
        final todo = planRepairPull(
          page.changes,
          repairKeys,
          await _db.outboxDao.recordKeys(),
        );
        final done = <String>{};
        for (final change in todo) {
          final store = _stores.maybeOf(change.entity);
          if (store == null) {
            continue;
          }
          await store.saveFromServer(change.data, change.serverVersion);
          done.add('${change.entity}:${change.id}');
        }
        return done;
      });
}
