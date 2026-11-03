import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain_rules/period.dart';
import '../../../../core/time/civil_date_format.dart';
import '../../../../core/time/user_clock.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/dashboard_providers.dart';

/// Previous / next month controls around the month name; tapping the name
/// opens a list of recent months. Months older than the free history limit
/// are disabled for free users.
class MonthSelector extends ConsumerWidget {
  const MonthSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final month = ref.watch(selectedMonthProvider);
    final notifier = ref.read(selectedMonthProvider.notifier);
    final current = YearMonth.of(ref.watch(userClockProvider).today());
    final canGoBack = ref.watch(canViewMonthProvider(month.addMonths(-1)));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: canGoBack
              ? l10n.monthPickerPrevious
              : l10n.monthPickerLocked,
          onPressed: canGoBack
              ? () => notifier.select(month.addMonths(-1))
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _pick(context, ref, current),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              formatYearMonth(month),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.monthPickerNext,
          onPressed: month.compareTo(current) < 0
              ? () => notifier.select(month.addMonths(1))
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    YearMonth current,
  ) async {
    final months = [for (var i = 0; i < 12; i++) current.addMonths(-i)];
    final picked = await showModalBottomSheet<YearMonth>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final month in months)
              Consumer(
                builder: (context, ref, _) {
                  final allowed = ref.watch(canViewMonthProvider(month));
                  return ListTile(
                    enabled: allowed,
                    title: Text(formatYearMonth(month)),
                    trailing: allowed ? null : const Icon(Icons.lock_outline),
                    onTap: allowed ? () => Navigator.pop(context, month) : null,
                  );
                },
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      ref.read(selectedMonthProvider.notifier).select(picked);
    }
  }
}
