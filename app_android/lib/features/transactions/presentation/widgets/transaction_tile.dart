import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/category_icons.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// One row of a transaction list: category icon, title, note, amount, and a
/// small cloud when the change has not reached the server yet.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    required this.transaction,
    required this.categories,
    required this.accounts,
    required this.hideAmounts,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final TransactionRow transaction;
  final Map<String, CategoryRow> categories;
  final Map<String, AccountRow> accounts;
  final bool hideAmounts;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final category = categories[transaction.categoryId];
    final account = accounts[transaction.accountId]?.name ?? '';
    final toAccount = accounts[transaction.toAccountId]?.name ?? '';

    final (
      IconData icon,
      Color color,
      String title,
      AmountKind kind,
    ) = switch (transaction.type) {
      'income' => (
        category == null ? Icons.south_west : CategoryIcons.of(category.icon),
        category == null
            ? scheme.primary
            : CategoryIcons.colorOf(category.color),
        category?.name ?? l10n.transactionUncategorized,
        AmountKind.income,
      ),
      'expense' => (
        category == null ? Icons.north_east : CategoryIcons.of(category.icon),
        category == null ? scheme.error : CategoryIcons.colorOf(category.color),
        category?.name ?? l10n.transactionUncategorized,
        AmountKind.expense,
      ),
      'transfer' => (
        Icons.swap_horiz,
        scheme.outline,
        l10n.transactionTransfer,
        AmountKind.transfer,
      ),
      _ => (
        Icons.tune,
        scheme.outline,
        l10n.transactionAdjustment,
        AmountKind.neutral,
      ),
    };

    final detail = transaction.type == 'transfer'
        ? l10n.transactionTransferRoute(account, toAccount)
        : [
            if ((transaction.note ?? transaction.source ?? '').isNotEmpty)
              transaction.note ?? transaction.source!,
            account,
          ].where((part) => part.isNotEmpty).join(' · ');

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (transaction.syncStatus == 'pending')
            Tooltip(
              message: l10n.transactionPendingSync,
              child: Icon(
                Icons.cloud_upload_outlined,
                size: 16,
                color: scheme.outline,
              ),
            )
          else if (transaction.syncStatus == 'failed')
            Tooltip(
              message: l10n.transactionFailedSync,
              child: Icon(Icons.error_outline, size: 16, color: scheme.error),
            ),
          const SizedBox(width: 6),
          AmountText(
            transaction.amount,
            kind: kind,
            hidden: hideAmounts,
            signed: true,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
