import '../../../core/database/app_database.dart';
import '../../../core/domain_rules/reconciliation.dart';

/// An account with its reconciliation result as of today
/// (BUSINESS_RULES §4.4), both produced by `core/domain_rules`.
class ReconcileItem {
  const ReconcileItem({required this.account, required this.result});

  final AccountRow account;
  final AccountReconciliation result;
}
