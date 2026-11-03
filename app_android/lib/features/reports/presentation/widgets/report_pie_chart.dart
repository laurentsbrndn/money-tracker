import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/domain_rules/rounding.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/money/percent_formatter.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// One slice of a breakdown.
class PieEntry {
  const PieEntry({
    required this.label,
    required this.amount,
    required this.color,
    this.onTap,
  });

  final String label;
  final int amount;
  final Color color;

  /// Opens the transactions behind the slice; null when there is nothing to
  /// open (the "Lainnya" slice, an entry without a key).
  final VoidCallback? onTap;
}

/// A donut chart with a legend. Tapping a slice or a legend row opens the
/// transactions behind it. With [hidden] no amount is shown anywhere: the legend
/// keeps each entry's share of the total (a percentage), not its amount.
class ReportPieChart extends StatelessWidget {
  const ReportPieChart({
    required this.entries,
    required this.hidden,
    required this.semanticsLabel,
    super.key,
  });

  final List<PieEntry> entries;
  final bool hidden;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final total = entries.fold(0, (sum, entry) => sum + entry.amount);
    return Column(
      children: [
        Semantics(
          label: semanticsLabel,
          child: SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 56,
                sections: [
                  for (final entry in entries)
                    PieChartSectionData(
                      value: entry.amount.toDouble(),
                      color: entry.color,
                      radius: 44,
                      showTitle: false,
                      borderSide: BorderSide(
                        color: theme.colorScheme.surface,
                        width: 2,
                      ),
                    ),
                ],
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    if (event is! FlTapUpEvent) {
                      return;
                    }
                    final index = response?.touchedSection?.touchedSectionIndex;
                    if (index != null && index >= 0 && index < entries.length) {
                      entries[index].onTap?.call();
                    }
                  },
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            l10n.reportsTotal(formatRupiah(total, hidden: hidden)),
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        for (final entry in entries)
          ListTile(
            dense: true,
            onTap: entry.onTap,
            leading: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: entry.color,
                shape: BoxShape.circle,
              ),
            ),
            title: Text(entry.label, overflow: TextOverflow.ellipsis),
            subtitle: total == 0
                ? null
                : Text(
                    formatBasisPoints(roundHalfUp(entry.amount * 10000, total)),
                  ),
            trailing: Text(formatRupiah(entry.amount, hidden: hidden)),
          ),
      ],
    );
  }
}
