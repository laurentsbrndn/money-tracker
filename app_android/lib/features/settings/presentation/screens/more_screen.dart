import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabMore)),
      body: Center(child: Text(l10n.placeholderComingSoon)),
    );
  }
}
