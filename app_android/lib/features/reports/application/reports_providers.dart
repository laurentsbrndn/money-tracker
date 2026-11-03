import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/mappers/row_mappers.dart';
import '../../../core/domain_rules/period.dart';
import '../../../core/domain_rules/report.dart';
import '../../../core/domain_rules/types.dart';
import '../../../core/time/civil_date.dart';
import '../../../core/time/user_clock.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../budget/application/budget_providers.dart';
import '../domain/report_kind.dart';

part 'reports_providers.g.dart';

/// Which report is open.
@Riverpod(keepAlive: true)
class ReportKindController extends _$ReportKindController {
  @override
  ReportKind build() => ReportKind.category;

  void select(ReportKind kind) => state = kind;
}

/// How many months the trend and unrecorded-difference reports span.
@Riverpod(keepAlive: true)
class ReportRange extends _$ReportRange {
  @override
  int build() => 6;

  void select(int months) => state = months;
}

/// What every report is computed from: the local database only, so reports
/// work offline (API.md §5, APP_FLOWS Flow 8).
class ReportInputs {
  const ReportInputs({
    required this.accounts,
    required this.transactions,
    required this.goals,
    required this.today,
  });

  final List<Account> accounts;
  final List<Transaction> transactions;
  final List<BudgetGoal> goals;
  final CivilDate today;
}

@riverpod
Future<ReportInputs> reportInputs(Ref ref) async {
  final accounts = await ref.watch(allAccountsProvider.future);
  final transactions = await ref.watch(allTransactionsProvider.future);
  final goals = await ref.watch(budgetGoalsProvider.future);
  return ReportInputs(
    accounts: [for (final row in accounts) row.toDomain()],
    transactions: [for (final row in transactions) row.toDomain()],
    goals: [for (final row in goals) row.toDomain()],
    today: ref.watch(userClockProvider).today(),
  );
}

/// Expenses of [month] per category, largest first.
@riverpod
Future<List<KeyedAmount>> categoryReportData(Ref ref, YearMonth month) async {
  final inputs = await ref.watch(reportInputsProvider.future);
  return expenseByCategory(
    inputs.transactions,
    month,
    reportAsOf(month, inputs.today),
  );
}

/// Income of [month] per source, largest first.
@riverpod
Future<List<KeyedAmount>> sourceReportData(Ref ref, YearMonth month) async {
  final inputs = await ref.watch(reportInputsProvider.future);
  return incomeBySource(
    inputs.transactions,
    month,
    reportAsOf(month, inputs.today),
  );
}

/// The last [months] months ending with the current one.
@riverpod
Future<List<TrendMonth>> trendReportData(Ref ref, int months) async {
  final inputs = await ref.watch(reportInputsProvider.future);
  return trendReport(
    inputs.accounts,
    inputs.transactions,
    inputs.goals,
    YearMonth.of(inputs.today),
    months,
    inputs.today,
  );
}

/// [month] against the month before it.
@riverpod
Future<MonthComparison> comparisonReportData(Ref ref, YearMonth month) async {
  final inputs = await ref.watch(reportInputsProvider.future);
  return compareMonths(
    inputs.accounts,
    inputs.transactions,
    inputs.goals,
    month,
    inputs.today,
  );
}
