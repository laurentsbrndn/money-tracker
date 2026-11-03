import '../../../l10n/generated/app_localizations.dart';

/// Account types in form order, with their stored values (DATA_MODEL §1.2).
const List<String> accountTypeValues = ['bank', 'e_wallet', 'cash', 'savings'];

String accountTypeLabel(AppLocalizations l10n, String type) => switch (type) {
  'bank' => l10n.accountTypeBank,
  'e_wallet' => l10n.accountTypeEWallet,
  'cash' => l10n.accountTypeCash,
  'savings' => l10n.accountTypeSavings,
  _ => type,
};
