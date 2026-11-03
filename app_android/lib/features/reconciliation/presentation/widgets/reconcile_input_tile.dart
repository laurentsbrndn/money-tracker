import 'package:flutter/material.dart';

import '../../../../core/money/money_formatter.dart';
import '../../../../core/theme/provider_logos.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/reconcile_item.dart';

/// One account waiting for its real balance: the recorded balance and an
/// input for what the user actually sees.
class ReconcileInputTile extends StatelessWidget {
  const ReconcileInputTile({
    required this.item,
    required this.controller,
    required this.hideAmounts,
    super.key,
  });

  final ReconcileItem item;
  final TextEditingController controller;
  final bool hideAmounts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = item.account;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProviderLogo(providerKey: account.providerKey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        l10n.reconcileRecordedLabel(
                          formatRupiah(
                            item.result.expectedBalance,
                            hidden: hideAmounts,
                          ),
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MoneyField(
              controller: controller,
              label: l10n.reconcileInputLabel,
              allowNegative: true,
            ),
          ],
        ),
      ),
    );
  }
}
