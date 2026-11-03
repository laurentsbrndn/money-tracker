import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/billing/entitlement_provider.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/domain_rules/period.dart';
import '../../../../core/domain_rules/report.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/category_icons.dart';
import '../../../../core/time/civil_date_format.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../dashboard/application/dashboard_providers.dart';
import '../../../dashboard/presentation/widgets/month_selector.dart';
import '../../../settings/application/user_settings_providers.dart';
import '../../../transactions/application/transaction_lookups.dart';
import '../../../transactions/application/transactions_providers.dart';
import '../../../transactions/domain/transaction_filter.dart';
import '../../application/reports_providers.dart';
import '../../domain/report_kind.dart';
import '../widgets/chart_colors.dart';
import '../widgets/month_bar_chart.dart';
import '../widgets/report_pie_chart.dart';

/// Lainnya → Laporan (APP_FLOWS Flow 8): per category, income sources, trend,
/// comparison, and unrecorded differences. Everything is computed on the
/// device from the local database by `core/domain_rules/report.dart`, so it
/// works offline; the server endpoints exist for verification and the web.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kind = ref.watch(reportKindControllerProvider);
    final premium = ref.watch(isPremiumProvider).value ?? false;
    final month = ref.watch(selectedMonthProvider);
    final range = ref.watch(reportRangeProvider);

    final Widget content;
    if (kind.premiumOnly && !premium) {
      content = _Locked(
        title: l10n.reportsLockedPremiumTitle,
        body: l10n.reportsLockedPremiumBody,
        action: l10n.planLimitSeePremium,
      );
    } else if (kind.usesMonth && !ref.watch(canViewMonthProvider(month))) {
      content = _Locked(
        title: l10n.reportsLockedMonthTitle,
        body: l10n.reportsLockedMonthBody,
        action: l10n.planLimitSeePremium,
      );
    } else {
      content = switch (kind) {
        ReportKind.category => _CategoryReport(month: month),
        ReportKind.source => _SourceReport(month: month),
        ReportKind.trend => _TrendReport(months: range),
        ReportKind.comparison => _ComparisonReport(month: month),
        ReportKind.unrecorded => _UnrecordedReport(months: range),
      };
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                for (final item in ReportKind.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_kindLabel(l10n, item)),
                      avatar: item.premiumOnly && !premium
                          ? const Icon(Icons.lock_outline, size: 16)
                          : null,
                      selected: item == kind,
                      onSelected: (_) => ref
                          .read(reportKindControllerProvider.notifier)
                          .select(item),
                    ),
                  ),
              ],
            ),
          ),
          if (kind.usesMonth)
            const Center(child: MonthSelector())
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 6, label: Text(l10n.reportsRange6)),
                  ButtonSegment(value: 12, label: Text(l10n.reportsRange12)),
                ],
                selected: {range},
                onSelectionChanged: (selection) => ref
                    .read(reportRangeProvider.notifier)
                    .select(selection.first),
              ),
            ),
          content,
        ],
      ),
    );
  }

  static String _kindLabel(AppLocalizations l10n, ReportKind kind) =>
      switch (kind) {
        ReportKind.category => l10n.reportKindCategory,
        ReportKind.source => l10n.reportKindSource,
        ReportKind.trend => l10n.reportKindTrend,
        ReportKind.comparison => l10n.reportKindComparison,
        ReportKind.unrecorded => l10n.reportKindUnrecorded,
      };
}

/// Points the transaction list at a filter and shows it ("tap bagian grafik
/// untuk melihat transaksinya").
void _openTransactions(
  BuildContext context,
  WidgetRef ref,
  TransactionFilter filter,
) {
  ref.read(transactionListControllerProvider.notifier).setFilter(filter);
  context.go(RoutePaths.transactions);
}

TransactionFilter _monthFilter(YearMonth month, {String? type}) =>
    TransactionFilter(type: type, from: month.first, to: month.last);

class _Locked extends StatelessWidget {
  const _Locked({
    required this.title,
    required this.body,
    required this.action,
  });

  final String title;
  final String body;
  final String action;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 360,
    child: EmptyState(
      icon: Icons.lock_outline,
      title: title,
      message: body,
      action: FilledButton(
        onPressed: () => context.push(RoutePaths.paywall),
        child: Text(action),
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 320,
    child: EmptyState(
      icon: Icons.insert_chart_outlined,
      title: AppLocalizations.of(context).reportsEmpty,
    ),
  );
}

/// Top entries stay; the rest is summed into "Lainnya".
const int _maxSlices = 7;

List<PieEntry> _withRest(
  AppLocalizations l10n,
  List<PieEntry> entries,
  Color restColor,
) {
  if (entries.length <= _maxSlices) {
    return entries;
  }
  final rest = entries.skip(_maxSlices).fold(0, (sum, e) => sum + e.amount);
  return [
    ...entries.take(_maxSlices),
    PieEntry(label: l10n.reportsOthers, amount: rest, color: restColor),
  ];
}

class _CategoryReport extends ConsumerWidget {
  const _CategoryReport({required this.month});

  final YearMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hide = ref.watch(hideAmountsProvider);
    final categories = ref.watch(categoriesByIdProvider);
    final colors = ChartColors.of(context);
    return AsyncBody(
      value: ref.watch(categoryReportDataProvider(month)),
      onRetry: () => ref.invalidate(categoryReportDataProvider(month)),
      builder: (items) {
        if (items.isEmpty) {
          return const _Empty();
        }
        final entries = [
          for (final item in items)
            _categoryEntry(context, ref, l10n, categories, month, item, colors),
        ];
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ReportPieChart(
                entries: _withRest(l10n, entries, colors.neutral),
                hidden: hide,
                semanticsLabel: l10n.reportsChartLabel(l10n.reportKindCategory),
              ),
              Text(
                l10n.reportsTapHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  PieEntry _categoryEntry(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    Map<String, CategoryRow> categories,
    YearMonth month,
    KeyedAmount item,
    ChartColors colors,
  ) {
    final category = item.key == null ? null : categories[item.key];
    return PieEntry(
      label: category?.name ?? l10n.transactionUncategorized,
      amount: item.amount,
      color: category == null
          ? colors.neutral
          : CategoryIcons.colorOf(category.color),
      // "Tanpa kategori" cannot be filtered on, so it has nothing to open.
      onTap: category == null
          ? null
          : () => _openTransactions(
              context,
              ref,
              TransactionFilter(
                type: 'expense',
                categoryId: category.id,
                from: month.first,
                to: month.last,
              ),
            ),
    );
  }
}

class _SourceReport extends ConsumerWidget {
  const _SourceReport({required this.month});

  final YearMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hide = ref.watch(hideAmountsProvider);
    final colors = ChartColors.of(context);
    return AsyncBody(
      value: ref.watch(sourceReportDataProvider(month)),
      onRetry: () => ref.invalidate(sourceReportDataProvider(month)),
      builder: (items) {
        if (items.isEmpty) {
          return const _Empty();
        }
        const palette = CategoryIcons.palette;
        final entries = [
          for (var i = 0; i < items.length; i++)
            PieEntry(
              label: items[i].key ?? l10n.reportsNoSource,
              amount: items[i].amount,
              color: items[i].key == null
                  ? colors.neutral
                  : CategoryIcons.colorOf(palette[i % palette.length]),
              onTap: items[i].key == null
                  ? null
                  : () => _openTransactions(
                      context,
                      ref,
                      TransactionFilter(
                        type: 'income',
                        query: items[i].key!,
                        from: month.first,
                        to: month.last,
                      ),
                    ),
            ),
        ];
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ReportPieChart(
                entries: _withRest(l10n, entries, colors.neutral),
                hidden: hide,
                semanticsLabel: l10n.reportsChartLabel(l10n.reportKindSource),
              ),
              Text(
                l10n.reportsTapHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

String _shortMonth(YearMonth month) => monthName(month.month).substring(0, 3);

class _Legend extends StatelessWidget {
  const _Legend(this.items);

  final List<(Color, String)> items;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    children: [
      for (final (color, label) in items)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
    ],
  );
}

class _TrendReport extends ConsumerWidget {
  const _TrendReport({required this.months});

  final int months;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hide = ref.watch(hideAmountsProvider);
    final colors = ChartColors.of(context);
    return AsyncBody(
      value: ref.watch(trendReportDataProvider(months)),
      onRetry: () => ref.invalidate(trendReportDataProvider(months)),
      builder: (data) {
        if (data.every((m) => m.income == 0 && m.expense == 0)) {
          return const _Empty();
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Legend([
                (colors.income, l10n.reportsIncome),
                (colors.expense, l10n.reportsExpense),
              ]),
              const SizedBox(height: 8),
              MonthBarChart(
                hidden: hide,
                semanticsLabel: l10n.reportsChartLabel(l10n.reportKindTrend),
                groups: [
                  for (final m in data)
                    BarGroup(
                      label: _shortMonth(m.month),
                      bars: [
                        BarValue(value: m.income, color: colors.income),
                        BarValue(value: m.expense, color: colors.expense),
                      ],
                    ),
                ],
                onGroupTap: (index) => _openTransactions(
                  context,
                  ref,
                  _monthFilter(data[index].month),
                ),
              ),
              Text(
                l10n.reportsTapHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Divider(height: 32),
              for (final m in data.reversed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(formatYearMonth(m.month)),
                  subtitle: Text(
                    '${l10n.reportsIncome} ${formatRupiah(m.income, hidden: hide)} · '
                    '${l10n.reportsExpense} ${formatRupiah(m.expense, hidden: hide)}\n'
                    '${l10n.reportsSavings} ${formatRupiah(m.savings, hidden: hide)}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    formatSignedRupiah(m.surplus, hidden: hide),
                    style: TextStyle(
                      color: m.surplus < 0 ? colors.expense : colors.income,
                    ),
                  ),
                  onTap: () =>
                      _openTransactions(context, ref, _monthFilter(m.month)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ComparisonReport extends ConsumerWidget {
  const _ComparisonReport({required this.month});

  final YearMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hide = ref.watch(hideAmountsProvider);
    final categories = ref.watch(categoriesByIdProvider);
    final colors = ChartColors.of(context);
    return AsyncBody(
      value: ref.watch(comparisonReportDataProvider(month)),
      onRetry: () => ref.invalidate(comparisonReportDataProvider(month)),
      builder: (data) {
        final measures = <(String, int, int)>[
          (l10n.reportsIncome, data.current.income, data.previous.income),
          (l10n.reportsExpense, data.current.expense, data.previous.expense),
          (l10n.reportsSurplus, data.current.surplus, data.previous.surplus),
          (l10n.reportsSavings, data.current.savings, data.previous.savings),
        ];
        if (measures.every((m) => m.$2 == 0 && m.$3 == 0)) {
          return const _Empty();
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Legend([
                (colors.neutral, l10n.reportsPreviousMonth),
                (colors.accent, l10n.reportsThisMonth),
              ]),
              const SizedBox(height: 8),
              MonthBarChart(
                hidden: hide,
                semanticsLabel: l10n.reportsChartLabel(
                  l10n.reportKindComparison,
                ),
                groups: [
                  for (final m in measures)
                    BarGroup(
                      label: m.$1,
                      bars: [
                        BarValue(value: m.$3, color: colors.neutral),
                        BarValue(value: m.$2, color: colors.accent),
                      ],
                    ),
                ],
              ),
              const Divider(height: 32),
              for (final m in measures)
                _ChangeRow(
                  label: m.$1,
                  current: m.$2,
                  previous: m.$3,
                  hidden: hide,
                  // More expense is bad; more of anything else is good.
                  higherIsBad: m.$1 == l10n.reportsExpense,
                ),
              const Divider(height: 32),
              Text(
                l10n.reportsComparisonCategories,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final line in data.expenseByCategory)
                _ChangeRow(
                  label: line.key == null
                      ? l10n.transactionUncategorized
                      : (categories[line.key]?.name ??
                            l10n.transactionUncategorized),
                  current: line.current,
                  previous: line.previous,
                  hidden: hide,
                  higherIsBad: true,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({
    required this.label,
    required this.current,
    required this.previous,
    required this.hidden,
    required this.higherIsBad,
  });

  final String label;
  final int current;
  final int previous;
  final bool hidden;
  final bool higherIsBad;

  @override
  Widget build(BuildContext context) {
    final colors = ChartColors.of(context);
    final change = current - previous;
    final bad = higherIsBad ? change > 0 : change < 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      subtitle: Text(
        '${formatRupiah(current, hidden: hidden)}  ←  ${formatRupiah(previous, hidden: hidden)}',
      ),
      trailing: change == 0
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  change > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: bad ? colors.expense : colors.income,
                ),
                Text(
                  formatRupiah(change.abs(), hidden: hidden),
                  style: TextStyle(color: bad ? colors.expense : colors.income),
                ),
              ],
            ),
    );
  }
}

class _UnrecordedReport extends ConsumerWidget {
  const _UnrecordedReport({required this.months});

  final int months;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hide = ref.watch(hideAmountsProvider);
    final colors = ChartColors.of(context);
    return AsyncBody(
      value: ref.watch(trendReportDataProvider(months)),
      onRetry: () => ref.invalidate(trendReportDataProvider(months)),
      builder: (data) {
        if (data.every((m) => m.adjustments == 0)) {
          return const _Empty();
        }
        final total = data.fold(0, (sum, m) => sum + m.adjustments);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.reportsUnrecordedBody),
              const SizedBox(height: 12),
              MonthBarChart(
                hidden: hide,
                semanticsLabel: l10n.reportsChartLabel(
                  l10n.reportKindUnrecorded,
                ),
                groups: [
                  for (final m in data)
                    BarGroup(
                      label: _shortMonth(m.month),
                      bars: [
                        BarValue(
                          value: m.adjustments,
                          color: m.adjustments < 0
                              ? colors.expense
                              : colors.income,
                        ),
                      ],
                    ),
                ],
                onGroupTap: (index) => _openTransactions(
                  context,
                  ref,
                  _monthFilter(data[index].month, type: 'adjustment'),
                ),
              ),
              Text(
                l10n.reportsTapHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Divider(height: 32),
              Text(
                l10n.reportsTotal(formatSignedRupiah(total, hidden: hide)),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final m in data.reversed.where((m) => m.adjustments != 0))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(formatYearMonth(m.month)),
                  trailing: Text(
                    formatSignedRupiah(m.adjustments, hidden: hide),
                    style: TextStyle(
                      color: m.adjustments < 0 ? colors.expense : colors.income,
                    ),
                  ),
                  onTap: () => _openTransactions(
                    context,
                    ref,
                    _monthFilter(m.month, type: 'adjustment'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
