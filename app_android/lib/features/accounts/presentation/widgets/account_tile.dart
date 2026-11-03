import 'package:flutter/material.dart';

import '../../../../core/domain_rules/reconciliation.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/provider_logos.dart';
import '../../../../core/time/civil_date_format.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../reconciliation/domain/reconcile_item.dart';
import '../../domain/account_with_balance.dart';

/// An account row: the recorded (expected) balance, and, when the account has
/// been reconciled, its last real balance with a matched / difference / stale
/// badge (APP_FLOWS Flow 5).
class AccountTile extends StatelessWidget {
  const AccountTile({
    required this.item,
    required this.hideAmounts,
    required this.onTap,
    this.reconcile,
    super.key,
  });

  final AccountWithBalance item;
  final bool hideAmounts;
  final VoidCallback onTap;
  final ReconcileItem? reconcile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final account = item.account;
    final result = reconcile?.result;
    final date = result?.latestSnapshotDate;
    final subtitleLines = <String>[
      if (!account.includeInTotal) l10n.accountsExcludedFromTotal,
      if (result != null)
        if (result.hasSnapshot && date != null)
          l10n.accountsActualOn(
            formatRupiah(result.latestSnapshotAmount, hidden: hideAmounts),
            formatCivilDateShort(date),
          )
        else
          l10n.accountsNoSnapshot,
    ];
    return ListTile(
      onTap: onTap,
      leading: ProviderLogo(providerKey: account.providerKey),
      title: Text(account.name),
      subtitle: subtitleLines.isEmpty ? null : Text(subtitleLines.join('\n')),
      isThreeLine: subtitleLines.length > 1,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AmountText(
            item.expectedBalance,
            hidden: hideAmounts,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (result != null) _badge(l10n, theme, result),
        ],
      ),
    );
  }

  Widget _badge(
    AppLocalizations l10n,
    ThemeData theme,
    AccountReconciliation result,
  ) {
    final (String text, Color color) = switch (result.status) {
      ReconciliationStatus.matched => (
        l10n.accountBadgeMatched,
        AppColors.income,
      ),
      ReconciliationStatus.mismatch => (
        l10n.reconcileDiff(
          formatSignedRupiah(result.diff, hidden: hideAmounts),
        ),
        AppColors.warning,
      ),
      ReconciliationStatus.stale => (
        l10n.accountBadgeStale,
        theme.colorScheme.outline,
      ),
    };
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
