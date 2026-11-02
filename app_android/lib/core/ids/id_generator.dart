import 'package:uuid/uuid.dart';

import '../time/civil_date.dart';

/// Entity IDs (SYNC_PROTOCOL §3): UUIDv7 from the client, UUIDv5 for deterministic IDs.
class IdGenerator {
  const IdGenerator();

  static const String nsBudgetGoal = '2c985cd5-0cd0-404d-bcea-4cca9c3f7437';
  static const String nsRecurringOccurrence =
      '151a0b48-a293-4aba-95a8-6562233ef7af';

  static const Uuid _uuid = Uuid();

  String newId() => _uuid.v7();

  /// UUIDv5 of `NS_BUDGET_GOAL` and the string `user_id|YYYY-MM`.
  String budgetGoalId(String userId, String month) =>
      _uuid.v5(nsBudgetGoal, '${userId.toLowerCase()}|$month');

  /// UUIDv5 of `NS_RECURRING_OCCURRENCE` and the string `rule_id|YYYY-MM-DD`.
  String recurringOccurrenceId(String ruleId, CivilDate date) =>
      _uuid.v5(nsRecurringOccurrence, '${ruleId.toLowerCase()}|$date');
}
