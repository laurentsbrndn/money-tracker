import '../../../../core/domain_rules/types.dart';
import '../../../../l10n/generated/app_localizations.dart';

String allocationName(AppLocalizations l10n, Allocation allocation) =>
    switch (allocation) {
      Allocation.needs => l10n.allocationNeeds,
      Allocation.wants => l10n.allocationWants,
      Allocation.savings => l10n.allocationSavings,
    };
