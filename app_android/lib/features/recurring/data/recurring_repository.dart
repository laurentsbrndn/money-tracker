import 'package:drift/drift.dart' show Value;

import '../../../core/billing/plan_limits.dart';
import '../../../core/database/app_database.dart';
import '../../../core/domain_rules/recurrence.dart';
import '../../../core/ids/id_generator.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/sync_entities.dart';
import '../../../core/time/civil_date.dart';
import '../../../core/validation/validation_exception.dart';
import '../domain/recurring_rule_input.dart';

/// Recurring rules. Reads are live streams from the local database; every
/// write goes through the [OutboxWriter] (SYNC_PROTOCOL §6). The checks of
/// BUSINESS_RULES §5-§7 run first; the server repeats them on push.
class RecurringRepository {
  RecurringRepository({
    required this._db,
    required this._writer,
    required this._isPremium,
  });

  final AppDatabase _db;
  final OutboxWriter _writer;
  final Future<bool> Function() _isPremium;

  static const IdGenerator _ids = IdGenerator();

  Stream<List<RecurringRuleRow>> watchAll() =>
      _db.recurringRulesDao.watchActive();

  Future<RecurringRuleRow?> find(String id) =>
      _db.recurringRulesDao.findById(id);

  Future<void> _requirePremium() async {
    if (!await _isPremium()) {
      throw const PlanLimitException(PlanLimitKind.recurring);
    }
  }

  Future<void> _validate(RecurringRuleInput input) async {
    final amount = input.amount;
    if (amount == null) {
      throw const ValidationException(ValidationError.amountRequired);
    }
    if (amount <= 0) {
      throw const ValidationException(ValidationError.amountZero);
    }
    if (amount > maxAmount) {
      throw const ValidationException(ValidationError.amountRange);
    }
    if ((input.note?.trim().length ?? 0) > 255) {
      throw const ValidationException(ValidationError.noteTooLong);
    }
    if ((input.source?.trim().length ?? 0) > 100) {
      throw const ValidationException(ValidationError.sourceTooLong);
    }
    if (input.intervalCount < 1 || input.intervalCount > 366) {
      throw const ValidationException(ValidationError.recurringIntervalRange);
    }
    final end = input.endDate;
    if (end != null && end.isBefore(input.startDate)) {
      throw const ValidationException(ValidationError.recurringEndBeforeStart);
    }
    _validateSchedule(input);

    final account = await _requireAccount(
      input.accountId,
      ValidationError.accountRequired,
    );
    if (input.startDate.isBefore(account.openingDate)) {
      throw const ValidationException(ValidationError.dateBeforeOpening);
    }
    switch (input.type) {
      case 'transfer':
        if (input.toAccountId == null) {
          throw const ValidationException(ValidationError.toAccountRequired);
        }
        if (input.toAccountId == input.accountId) {
          throw const ValidationException(ValidationError.sameAccount);
        }
        final target = await _requireAccount(
          input.toAccountId,
          ValidationError.toAccountRequired,
        );
        if (input.startDate.isBefore(target.openingDate)) {
          throw const ValidationException(ValidationError.dateBeforeOpening);
        }
      case 'expense':
        if (input.categoryId == null) {
          throw const ValidationException(ValidationError.categoryRequired);
        }
        if (input.allocation == null) {
          throw const ValidationException(ValidationError.allocationRequired);
        }
    }
  }

  /// The schedule fields of the frequency, and only those (DATA_MODEL §5).
  void _validateSchedule(RecurringRuleInput input) {
    final dow = input.dayOfWeek;
    final dom = input.dayOfMonth;
    final moy = input.monthOfYear;
    const invalid = ValidationException(
      ValidationError.recurringScheduleInvalid,
    );
    switch (input.frequency) {
      case RecurringFrequency.daily:
        break;
      case RecurringFrequency.weekly:
        if (dow == null || dow < 1 || dow > 7) {
          throw invalid;
        }
      case RecurringFrequency.monthly:
        if (dom == null || dom < 1 || dom > 31) {
          throw invalid;
        }
      case RecurringFrequency.yearly:
        // 29 Feb is allowed (28 Feb in other years); 30 Feb and 31 Apr never occur.
        if (moy == null ||
            moy < 1 ||
            moy > 12 ||
            dom == null ||
            dom < 1 ||
            dom > CivilDate.daysInMonth(2024, moy)) {
          throw invalid;
        }
    }
  }

  Future<AccountRow> _requireAccount(
    String? id,
    ValidationError missing,
  ) async {
    final account = id == null ? null : await _db.accountsDao.findById(id);
    if (account == null || account.deletedAt != null) {
      throw ValidationException(missing);
    }
    return account;
  }

  /// Creates a rule, or saves the edit of [existing]. Creating needs premium;
  /// editing a rule that is running does not (BUSINESS_RULES §7). Returns the
  /// rule id.
  Future<String> save(
    RecurringRuleInput input, {
    RecurringRuleRow? existing,
  }) async {
    await _validate(input);
    if (existing == null || existing.deletedAt != null) {
      await _requirePremium();
    }
    final id = existing?.id ?? _ids.newId();
    final dayOfWeek = input.frequency == RecurringFrequency.weekly
        ? input.dayOfWeek
        : null;
    final usesDayOfMonth =
        input.frequency == RecurringFrequency.monthly ||
        input.frequency == RecurringFrequency.yearly;
    final transfer = input.type == 'transfer';
    final expense = input.type == 'expense';
    final note = input.note?.trim();
    final source = input.source?.trim();
    await _writer.write(
      (tx) => tx.upsert(
        SyncEntities.recurringRules,
        id,
        RecurringRuleRow(
          id: id,
          createdAt: existing?.createdAt ?? tx.now,
          updatedAt: tx.now,
          serverVersion: existing?.serverVersion,
          syncStatus: 'pending',
          type: input.type,
          amount: input.amount!,
          accountId: input.accountId!,
          toAccountId: transfer ? input.toAccountId : null,
          categoryId: transfer ? null : input.categoryId,
          allocation: expense ? input.allocation : null,
          source: input.type == 'income' && (source ?? '').isNotEmpty
              ? source
              : null,
          note: (note ?? '').isEmpty ? null : note,
          frequency: input.frequency.value,
          intervalCount: input.intervalCount,
          dayOfWeek: dayOfWeek,
          dayOfMonth: usesDayOfMonth ? input.dayOfMonth : null,
          monthOfYear: input.frequency == RecurringFrequency.yearly
              ? input.monthOfYear
              : null,
          startDate: input.startDate,
          endDate: input.endDate,
          mode: input.mode,
          isPaused: existing?.isPaused ?? false,
          // An edit only affects dates after the ones already created.
          lastGeneratedDate: existing?.lastGeneratedDate,
        ),
      ),
    );
    return id;
  }

  /// Pauses or resumes a rule. Resuming needs premium: a rule the server
  /// paused when premium ended stays paused until the plan is back.
  Future<void> setPaused(RecurringRuleRow rule, {required bool paused}) async {
    if (!paused) {
      await _requirePremium();
    }
    await _writer.write(
      (tx) => tx.upsert(
        SyncEntities.recurringRules,
        rule.id,
        rule.copyWith(
          isPaused: paused,
          updatedAt: tx.now,
          syncStatus: 'pending',
          syncError: const Value(null),
        ),
      ),
    );
  }

  /// Deletes the rule; transactions it already created stay.
  Future<void> delete(String id) =>
      _writer.write((tx) => tx.delete(SyncEntities.recurringRules, id));
}
