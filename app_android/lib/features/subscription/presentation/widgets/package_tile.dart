import 'package:flutter/material.dart';

import '../../../../core/billing/paywall_package.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// One selectable package of the paywall.
class PackageTile extends StatelessWidget {
  const PackageTile({
    required this.package,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final PaywallPackage package;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (title, price) = switch (package.period) {
      PaywallPeriod.monthly => (
        l10n.paywallMonthly,
        l10n.paywallPerMonth(package.priceText),
      ),
      PaywallPeriod.yearly => (
        l10n.paywallYearly,
        l10n.paywallPerYear(package.priceText),
      ),
      PaywallPeriod.other => (package.title, package.priceText),
    };
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? theme.colorScheme.primary : theme.dividerColor,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? theme.colorScheme.primary : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    Text(price, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              if (package.hasTrial)
                Chip(
                  label: Text(l10n.paywallTrialBadge),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
