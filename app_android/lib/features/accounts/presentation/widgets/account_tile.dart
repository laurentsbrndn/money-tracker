import 'package:flutter/material.dart';

import '../../../../core/theme/provider_logos.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/account_with_balance.dart';

class AccountTile extends StatelessWidget {
  const AccountTile({
    required this.item,
    required this.hideAmounts,
    required this.onTap,
    super.key,
  });

  final AccountWithBalance item;
  final bool hideAmounts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = item.account;
    return ListTile(
      onTap: onTap,
      leading: ProviderLogo(providerKey: account.providerKey),
      title: Text(account.name),
      subtitle: account.includeInTotal
          ? null
          : Text(l10n.accountsExcludedFromTotal),
      trailing: AmountText(
        item.expectedBalance,
        hidden: hideAmounts,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
