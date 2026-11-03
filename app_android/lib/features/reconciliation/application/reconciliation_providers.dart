import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/database/mappers/row_mappers.dart';
import '../../../core/domain_rules/reconciliation.dart';
import '../../../core/sync/sync_providers.dart';
import '../../../core/time/user_clock.dart';
import '../../accounts/application/accounts_providers.dart';
import '../data/reconciliation_repository.dart';
import '../domain/reconcile_item.dart';
import '../domain/reconcile_view.dart';

part 'reconciliation_providers.g.dart';

@Riverpod(keepAlive: true)
ReconciliationRepository reconciliationRepository(Ref ref) =>
    ReconciliationRepository(
      db: ref.watch(appDatabaseProvider),
      writer: ref.watch(outboxWriterProvider),
      today: () => ref.read(userClockProvider).today(),
    );

/// Every live balance snapshot; the reconciliation needs the newest one of
/// each account.
final allSnapshotsProvider =
    StreamProvider.autoDispose<List<BalanceSnapshotRow>>(
      (ref) => ref.watch(appDatabaseProvider).balanceSnapshotsDao.watchActive(),
    );

/// The reconciliation of every account as of today (BUSINESS_RULES §4.2-§4.4),
/// computed by `core/domain_rules`. Declared by hand because it holds Drift
/// rows.
final reconcileViewProvider = FutureProvider.autoDispose<ReconcileView>((
  ref,
) async {
  final accounts = await ref.watch(allAccountsProvider.future);
  final transactions = await ref.watch(allTransactionsProvider.future);
  final snapshots = await ref.watch(allSnapshotsProvider.future);
  final today = ref.watch(userClockProvider).today();
  final result = reconcile(
    [for (final account in accounts) account.toDomain()],
    [for (final row in transactions) row.toDomain()],
    [for (final row in snapshots) row.toDomain()],
    today,
  );
  final byId = {for (final account in accounts) account.id: account};
  return ReconcileView(
    items: [
      for (final entry in result.accounts)
        ReconcileItem(account: byId[entry.accountId]!, result: entry),
    ],
    totals: result.totals,
  );
});

/// What the user did during one visit to the reconcile screen.
class ReconcileSessionState {
  const ReconcileSessionState({
    this.reconciled = const {},
    this.deferred = const {},
    this.adjusted = const {},
  });

  /// Accounts whose real balance was entered in this visit.
  final Set<String> reconciled;

  /// Accounts the user chose "Nanti saja" for.
  final Set<String> deferred;

  /// Signed adjustment made per account in this visit.
  final Map<String, int> adjusted;

  int get adjustedTotal => adjusted.values.fold(0, (sum, v) => sum + v);

  ReconcileSessionState copyWith({
    Set<String>? reconciled,
    Set<String>? deferred,
    Map<String, int>? adjusted,
  }) => ReconcileSessionState(
    reconciled: reconciled ?? this.reconciled,
    deferred: deferred ?? this.deferred,
    adjusted: adjusted ?? this.adjusted,
  );
}

@riverpod
class ReconcileSession extends _$ReconcileSession {
  @override
  ReconcileSessionState build() => const ReconcileSessionState();

  /// Saves the entered balances as today's snapshots.
  Future<void> submit(Map<String, int> balances) async {
    if (balances.isEmpty) {
      return;
    }
    final saved = await ref
        .read(reconciliationRepositoryProvider)
        .saveSnapshots(balances);
    state = state.copyWith(
      reconciled: {...state.reconciled, ...saved},
      deferred: state.deferred.difference(saved.toSet()),
    );
  }

  void defer(String accountId) =>
      state = state.copyWith(deferred: {...state.deferred, accountId});

  void undefer(String accountId) => state = state.copyWith(
    deferred: state.deferred.difference({accountId}),
  );

  /// Books an adjustment for the account's current difference. The amount is
  /// re-read from the database now, so a double tap or a transaction added
  /// meanwhile cannot book a stale amount; a difference of 0 does nothing.
  Future<int> adjust(String accountId, String note) async {
    final db = ref.read(appDatabaseProvider);
    final accounts = await db.accountsDao.allActive();
    final transactions = await db.transactionsDao.allActive();
    final snapshots = await db.balanceSnapshotsDao.allActive();
    final result = reconcile(
      [for (final row in accounts) row.toDomain()],
      [for (final row in transactions) row.toDomain()],
      [for (final row in snapshots) row.toDomain()],
      ref.read(userClockProvider).today(),
    );
    final entry = result.accounts
        .where((item) => item.accountId == accountId)
        .firstOrNull;
    final date = entry?.latestSnapshotDate;
    if (entry == null || date == null || entry.diff == 0) {
      return 0;
    }
    await ref
        .read(reconciliationRepositoryProvider)
        .createAdjustment(
          accountId: accountId,
          amount: entry.diff,
          date: date,
          note: note,
        );
    state = state.copyWith(
      adjusted: {
        ...state.adjusted,
        accountId: (state.adjusted[accountId] ?? 0) + entry.diff,
      },
    );
    return entry.diff;
  }
}
