import '../../../core/database/app_database.dart';
import '../../../core/domain_rules/period.dart';
import '../../../core/ids/id_generator.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/sync_entities.dart';
import '../../../core/validation/validation_exception.dart';

/// Budget goals. Reads are live streams; the one write goes through the
/// [OutboxWriter]. The row id is deterministic (SYNC_PROTOCOL §3), so two
/// devices setting a goal for the same month write the same row.
class BudgetRepository {
  BudgetRepository({
    required this._db,
    required this._writer,
    required this._userId,
  });

  final AppDatabase _db;
  final OutboxWriter _writer;

  /// The signed-in user id, null while there is no session.
  final String? Function() _userId;

  static const IdGenerator _ids = IdGenerator();

  Stream<List<BudgetGoalRow>> watchAll() => _db.budgetGoalsDao.watchActive();

  /// Saves the goal that applies from [month] on (BUSINESS_RULES §6). Returns
  /// false, writing nothing, when the month already has exactly this goal.
  Future<bool> saveGoal({
    required YearMonth month,
    required int needsPct,
    required int wantsPct,
    required int savingsPct,
    int? plannedIncome,
  }) async {
    for (final pct in [needsPct, wantsPct, savingsPct]) {
      if (pct < 0 || pct > 100) {
        throw const ValidationException(ValidationError.goalPercentRange);
      }
    }
    if (needsPct + wantsPct + savingsPct != 100) {
      throw const ValidationException(ValidationError.goalTotal);
    }
    if (plannedIncome != null &&
        (plannedIncome < 0 || plannedIncome > maxAmount)) {
      throw const ValidationException(ValidationError.plannedIncomeRange);
    }
    final userId = _userId();
    if (userId == null) {
      throw const ValidationException(ValidationError.settingsMissing);
    }

    final id = _ids.budgetGoalId(userId, month.toString());
    final existing = await _db.budgetGoalsDao.findById(id);
    final unchanged =
        existing != null &&
        existing.deletedAt == null &&
        existing.needsPct == needsPct &&
        existing.wantsPct == wantsPct &&
        existing.savingsPct == savingsPct &&
        existing.plannedIncome == plannedIncome;
    if (unchanged) {
      return false;
    }
    await _writer.write(
      (tx) => tx.upsert(
        SyncEntities.budgetGoals,
        id,
        BudgetGoalRow(
          id: id,
          createdAt: existing?.createdAt ?? tx.now,
          updatedAt: tx.now,
          serverVersion: existing?.serverVersion,
          syncStatus: 'pending',
          effectiveMonth: month.first,
          needsPct: needsPct,
          wantsPct: wantsPct,
          savingsPct: savingsPct,
          plannedIncome: plannedIncome,
        ),
      ),
    );
    return true;
  }
}
