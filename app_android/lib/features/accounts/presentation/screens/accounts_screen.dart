import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabAccounts)),
      body: Center(child: Text(l10n.placeholderComingSoon)),
    );
  }
}
