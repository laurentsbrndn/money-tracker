import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../../core/domain_rules/recurrence.dart';
import '../../../core/ids/id_generator.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/sync_entities.dart';
import '../../../core/time/civil_date.dart';
import '../domain/recurrence_mapping.dart';

/// What one run created.
class GenerationResult {
  const GenerationResult({this.created = 0, this.pendingConfirmation = 0});

  final int created;

  /// How many of them wait for the user to record or skip them.
  final int pendingConfirmation;
}

/// Creates the transactions recurring rules have come due for, on the device
/// (BUSINESS_RULES §5.2). The server's daily job does the same with the same
/// ids, so a date is never recorded twice: the id of an occurrence is
/// UUIDv5(`rule id|date`), and a row that already exists, even a deleted one,
/// is left alone (SYNC_PROTOCOL S12).
class RecurringGenerator {
  RecurringGenerator({
    required this._db,
    required this._writer,
    required this._today,
    required this._isPremium,
  });

  final AppDatabase _db;
  final OutboxWriter _writer;

  /// "Today" in the user's timezone.
  final CivilDate Function() _today;

  /// Only premium users have occurrences created.
  final Future<bool> Function() _isPremium;

  static const IdGenerator _ids = IdGenerator();

  Future<GenerationResult> run() async {
    if (!await _isPremium()) {
      return const GenerationResult();
    }
    final today = _today();
    var created = 0;
    var pending = 0;
    for (final rule in await _db.recurringRulesDao.allRunning()) {
      final due = occurrences(
        rule.toRecurrenceRule(),
        rule.lastGeneratedDate,
        today,
      );
      if (due.isEmpty) {
        continue;
      }
      final result = await _generate(rule, due);
      created += result.created;
      pending += result.pendingConfirmation;
    }
    return GenerationResult(created: created, pendingConfirmation: pending);
  }

  /// One transaction per rule: its occurrences and its new
  /// `last_generated_date` are saved together.
  Future<GenerationResult> _generate(
    RecurringRuleRow rule,
    List<CivilDate> due,
  ) async {
    final opening = await _openingDate(rule);
    final status = rule.mode == 'confirm' ? 'pending_confirmation' : 'posted';
    final lastDue = due.last;
    return _writer.write((tx) async {
      var created = 0;
      // A rule whose account or category is gone records nothing, but still
      // moves on, so it is not "due" for ever (the server does the same).
      if (opening != null) {
        for (final date in due) {
          if (date.isBefore(opening)) {
            continue;
          }
          final id = _ids.recurringOccurrenceId(rule.id, date);
          if (await _db.transactionsDao.findById(id) != null) {
            continue;
          }
          await tx.upsert(
            SyncEntities.transactions,
            id,
            TransactionRow(
              id: id,
              createdAt: tx.now,
              updatedAt: tx.now,
              syncStatus: 'pending',
              type: rule.type,
              status: status,
              transactionDate: date,
              amount: rule.amount,
              currency: 'IDR',
              accountId: rule.accountId,
              toAccountId: rule.toAccountId,
              categoryId: rule.categoryId,
              allocation: rule.allocation,
              source: rule.source,
              note: rule.note,
              recurringRuleId: rule.id,
            ),
          );
          created++;
        }
      }
      await tx.upsert(
        SyncEntities.recurringRules,
        rule.id,
        rule.copyWith(
          lastGeneratedDate: Value(lastDue),
          updatedAt: tx.now,
          syncStatus: 'pending',
        ),
      );
      return GenerationResult(
        created: created,
        pendingConfirmation: status == 'posted' ? 0 : created,
      );
    });
  }

  /// The latest opening date among the template's accounts, or null when an
  /// account or the category is missing or deleted.
  Future<CivilDate?> _openingDate(RecurringRuleRow rule) async {
    CivilDate? opening;
    for (final id in [rule.accountId, ?rule.toAccountId]) {
      final account = await _db.accountsDao.findById(id);
      if (account == null || account.deletedAt != null) {
        return null;
      }
      if (opening == null || account.openingDate.isAfter(opening)) {
        opening = account.openingDate;
      }
    }
    final categoryId = rule.categoryId;
    if (categoryId != null) {
      final category = await _db.categoriesDao.findById(categoryId);
      if (category == null || category.deletedAt != null) {
        return null;
      }
    }
    return opening;
  }
}
