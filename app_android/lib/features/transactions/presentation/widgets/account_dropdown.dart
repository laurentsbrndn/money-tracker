import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/provider_logos.dart';

/// Account selector used by the entry and filter forms.
class AccountDropdown extends StatelessWidget {
  const AccountDropdown({
    required this.label,
    required this.accounts,
    required this.value,
    required this.onChanged,
    this.allowNone = false,
    this.noneLabel = '',
    super.key,
  });

  final String label;
  final List<AccountRow> accounts;
  final String? value;
  final ValueChanged<String?> onChanged;

  /// Adds an entry with a null value (used by "all accounts" filters).
  final bool allowNone;
  final String noneLabel;

  @override
  Widget build(BuildContext context) {
    final selected = accounts.any((a) => a.id == value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        if (allowNone) DropdownMenuItem<String>(child: Text(noneLabel)),
        for (final account in accounts)
          DropdownMenuItem(
            value: account.id,
            child: Row(
              children: [
                ProviderLogo(providerKey: account.providerKey, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(account.name, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
