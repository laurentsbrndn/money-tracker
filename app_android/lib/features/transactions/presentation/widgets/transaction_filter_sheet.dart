import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/category_icons.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/time/civil_date_format.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../accounts/application/accounts_providers.dart';
import '../../../categories/application/categories_providers.dart';
import '../../domain/transaction_filter.dart';
import 'account_dropdown.dart';

/// Bottom sheet to set the history filters; returns the chosen filter.
Future<TransactionFilter?> showTransactionFilterSheet(
  BuildContext context,
  TransactionFilter current,
) => showModalBottomSheet<TransactionFilter>(
  context: context,
  isScrollControlled: true,
  builder: (context) => _FilterSheet(initial: current),
);

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});

  final TransactionFilter initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late TransactionFilter _filter = widget.initial;

  Future<void> _pickDate({required bool from}) async {
    final base =
        (from ? _filter.from : _filter.to) ??
        CivilDate.fromDateTime(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(base.year, base.month, base.day),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (picked == null) {
      return;
    }
    final date = CivilDate.fromDateTime(picked);
    setState(() {
      _filter = from
          ? _filter.copyWith(from: () => date)
          : _filter.copyWith(to: () => date);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accounts = ref.watch(allAccountsProvider).value ?? const [];
    final categories = ref.watch(allCategoriesProvider).value ?? const [];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.filterTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(l10n.filterType, style: theme.textTheme.labelLarge),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l10n.filterAll),
                    selected: _filter.type == null,
                    onSelected: (_) => setState(
                      () => _filter = _filter.copyWith(type: () => null),
                    ),
                  ),
                  for (final entry in {
                    'expense': l10n.transactionTypeExpense,
                    'income': l10n.transactionTypeIncome,
                    'transfer': l10n.transactionTypeTransfer,
                    'adjustment': l10n.transactionTypeAdjustment,
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _filter.type == entry.key,
                      onSelected: (_) => setState(
                        () => _filter = _filter.copyWith(type: () => entry.key),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              AccountDropdown(
                label: l10n.filterAccount,
                accounts: accounts,
                value: _filter.accountId,
                allowNone: true,
                noneLabel: l10n.filterAll,
                onChanged: (value) => setState(
                  () => _filter = _filter.copyWith(accountId: () => value),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: categories.any((c) => c.id == _filter.categoryId)
                    ? _filter.categoryId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.filterCategory,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String>(child: Text(l10n.filterAll)),
                  for (final category in categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Row(
                        children: [
                          Icon(
                            CategoryIcons.of(category.icon),
                            size: 20,
                            color: CategoryIcons.colorOf(category.color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              category.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                onChanged: (value) => setState(
                  () => _filter = _filter.copyWith(categoryId: () => value),
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.filterAllocation, style: theme.textTheme.labelLarge),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l10n.filterAll),
                    selected: _filter.allocation == null,
                    onSelected: (_) => setState(
                      () => _filter = _filter.copyWith(allocation: () => null),
                    ),
                  ),
                  for (final entry in {
                    'needs': l10n.allocationNeeds,
                    'wants': l10n.allocationWants,
                    'savings': l10n.allocationSavings,
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _filter.allocation == entry.key,
                      onSelected: (_) => setState(
                        () => _filter = _filter.copyWith(
                          allocation: () => entry.key,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(l10n.filterDateRange, style: theme.textTheme.labelLarge),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(from: true),
                      child: Text(
                        _filter.from == null
                            ? l10n.filterFrom
                            : formatCivilDateShort(_filter.from!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(from: false),
                      child: Text(
                        _filter.to == null
                            ? l10n.filterTo
                            : formatCivilDateShort(_filter.to!),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      TransactionFilter(query: widget.initial.query),
                    ),
                    child: Text(l10n.filterReset),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _filter),
                    child: Text(l10n.filterApply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
