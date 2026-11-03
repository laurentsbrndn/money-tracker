import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/time/civil_date_format.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/recurrence_mapping.dart';
import '../../domain/recurring_rule_status.dart';
import 'schedule_text.dart';

/// One rule in the list: what it records, how often, what comes next, and
/// whether it is running.
class RecurringRuleTile extends StatelessWidget {
  const RecurringRuleTile({
    required this.rule,
    required this.title,
    required this.today,
    required this.premium,
    required this.hideAmounts,
    required this.onTap,
    required this.onTogglePause,
    super.key,
  });

  final RecurringRuleRow rule;

  /// Category name, or the transfer label.
  final String title;
  final CivilDate today;
  final bool premium;
  final bool hideAmounts;
  final VoidCallback onTap;
  final VoidCallback onTogglePause;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = rule.statusAt(today, premium: premium);
    final next = rule.nextDate(today);
    final (label, color) = switch (status) {
      RecurringRuleStatus.active => (
        l10n.recurringStatusActive,
        theme.colorScheme.primary,
      ),
      RecurringRuleStatus.paused => (
        l10n.recurringStatusPaused,
        theme.colorScheme.outline,
      ),
      RecurringRuleStatus.pausedNoPremium => (
        l10n.recurringStatusPausedNoPremium,
        theme.colorScheme.error,
      ),
      RecurringRuleStatus.ended => (
        l10n.recurringStatusEnded,
        theme.colorScheme.outline,
      ),
    };
    final kind = switch (rule.type) {
      'income' => AmountKind.income,
      'expense' => AmountKind.expense,
      _ => AmountKind.transfer,
    };
    return ListTile(
      onTap: onTap,
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(describeSchedule(l10n, rule)),
          Text(
            next == null
                ? l10n.recurringNoNext
                : l10n.recurringNextOn(formatCivilDateShort(next)),
            style: theme.textTheme.bodySmall,
          ),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AmountText(rule.amount, kind: kind, hidden: hideAmounts),
          if (status != RecurringRuleStatus.ended)
            IconButton(
              tooltip: rule.isPaused
                  ? l10n.recurringResume
                  : l10n.recurringPause,
              onPressed: onTogglePause,
              icon: Icon(rule.isPaused ? Icons.play_arrow : Icons.pause),
            ),
        ],
      ),
    );
  }
}
