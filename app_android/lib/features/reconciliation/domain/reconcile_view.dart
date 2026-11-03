import '../../../core/domain_rules/reconciliation.dart';
import '../../../core/time/civil_date.dart';
import 'reconcile_item.dart';

/// Everything the reconcile screen and the dashboard cards show.
class ReconcileView {
  const ReconcileView({required this.items, required this.totals});

  /// Accounts that count towards the total (archived ones included), in list
  /// order.
  final List<ReconcileItem> items;
  final Totals totals;

  /// The accounts the user is asked about: not archived.
  List<ReconcileItem> get active => [
    for (final item in items)
      if (item.account.archivedAt == null) item,
  ];

  int get matchedCount => _count(ReconciliationStatus.matched);
  int get mismatchCount => _count(ReconciliationStatus.mismatch);
  int get staleCount => _count(ReconciliationStatus.stale);

  /// The newest snapshot date over all accounts, when the real balances were
  /// last updated; null if there is no snapshot.
  CivilDate? get lastUpdated {
    CivilDate? latest;
    for (final item in items) {
      final date = item.result.latestSnapshotDate;
      if (date != null && (latest == null || date.isAfter(latest))) {
        latest = date;
      }
    }
    return latest;
  }

  int _count(ReconciliationStatus status) =>
      items.where((item) => item.result.status == status).length;
}
