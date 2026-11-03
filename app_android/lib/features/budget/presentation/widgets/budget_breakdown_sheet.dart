import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/domain_rules/period.dart';
import '../../../../core/domain_rules/types.dart';
import '../../../../core/theme/category_icons.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../settings/application/user_settings_providers.dart';
import '../../../transactions/application/transaction_lookups.dart';
import '../../application/budget_providers.dart';
import 'allocation_labels.dart';

/// Opens the per-category breakdown of one bucket (APP_FLOWS Flow 6 step 2).
Future<void> showBudgetBreakdownSheet(
  BuildContext context, {
  required YearMonth month,
  required Allocation allocation,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) =>
      _BreakdownSheet(month: month, allocation: allocation),
);

class _BreakdownSheet extends ConsumerWidget {
  const _BreakdownSheet({required this.month, required this.allocation});

  final YearMonth month;
  final Allocation allocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final breakdown = ref.watch(allocationBreakdownProvider((month, allocation)));
    final categories = ref.watch(categoriesByIdProvider);
    final hide = ref.watch(hideAmountsProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: breakdown.when(
          loading: () => const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) =>
              SizedBox(height: 160, child: Center(child: Text(l10n.errorGeneric))),
          data: (data) {
            final empty = data.categories.isEmpty && data.transferNet == 0;
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text(
                  l10n.budgetBreakdownTitle(allocationName(l10n, allocation)),
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (empty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(l10n.budgetBreakdownEmpty),
                  )
                else ...[
                  for (final entry in data.categories)
                    _categoryTile(l10n, categories[entry.categoryId], entry.amount, hide),
                  if (data.transferNet != 0)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.savings_outlined),
                      title: Text(l10n.budgetBreakdownTransfers),
                      trailing: AmountText(data.transferNet, hidden: hide),
                    ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.budgetBreakdownTotal,
                      style: theme.textTheme.titleSmall,
                    ),
                    trailing: AmountText(
                      data.total,
                      hidden: hide,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _categoryTile(
    AppLocalizations l10n,
    CategoryRow? category,
    int amount,
    bool hide,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      category == null
          ? Icons.category_outlined
          : CategoryIcons.of(category.icon),
      color: category == null ? null : CategoryIcons.colorOf(category.color),
    ),
    title: Text(category?.name ?? l10n.budgetBreakdownUncategorized),
    trailing: AmountText(amount, hidden: hide),
  );
}
