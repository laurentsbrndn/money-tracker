import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/billing/plan_limits.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/theme/provider_logos.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/time/civil_date_format.dart';
import '../../../../core/time/user_clock.dart';
import '../../../../core/validation/validation_exception.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/plan_limit_snack_bar.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/accounts_providers.dart';
import '../../domain/account_type_labels.dart';

/// Create (`accountId` null) or edit an account (APP_FLOWS Flow 5).
class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({this.accountId, super.key});

  final String? accountId;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _balance = TextEditingController();
  String _type = 'bank';
  String? _providerKey;
  late CivilDate _openingDate;
  bool _includeInTotal = true;
  bool _busy = false;
  bool _loaded = false;
  AccountRow? _existing;

  bool get _isEdit => widget.accountId != null;

  @override
  void initState() {
    super.initState();
    _openingDate = ref.read(userClockProvider).today();
    if (_isEdit) {
      _load();
    } else {
      _loaded = true;
    }
  }

  Future<void> _load() async {
    final account = await ref
        .read(accountsRepositoryProvider)
        .find(widget.accountId!);
    if (!mounted) {
      return;
    }
    if (account == null) {
      context.pop();
      return;
    }
    setState(() {
      _existing = account;
      _name.text = account.name;
      _type = account.type;
      _providerKey = account.providerKey;
      _openingDate = account.openingDate;
      _includeInTotal = account.includeInTotal;
      _balance.text = account.openingBalance < 0
          ? '-${groupThousands(account.openingBalance.abs())}'
          : groupThousands(account.openingBalance);
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(
        _openingDate.year,
        _openingDate.month,
        _openingDate.day,
      ),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _openingDate = CivilDate.fromDateTime(picked));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    final repository = ref.read(accountsRepositoryProvider);
    final balance = MoneyField.valueOf(_balance, negative: true) ?? 0;
    try {
      if (_isEdit) {
        await repository.update(
          _existing!,
          name: _name.text,
          type: _type,
          providerKey: _providerKey,
          openingBalance: balance,
          openingDate: _openingDate,
          includeInTotal: _includeInTotal,
        );
      } else {
        await repository.create(
          name: _name.text,
          type: _type,
          providerKey: _providerKey,
          openingBalance: balance,
          openingDate: _openingDate,
          includeInTotal: _includeInTotal,
        );
      }
      router.pop();
    } on ValidationException catch (error) {
      _fail(messenger, error.message(l10n));
    } on PlanLimitException {
      if (mounted) {
        setState(() => _busy = false);
      }
      showPlanLimitSnackBar(
        messenger,
        router,
        l10n,
        l10n.planLimitAccounts,
      );
    } on Object catch (error) {
      _fail(messenger, describeError(error, l10n));
    }
  }

  void _fail(ScaffoldMessengerState messenger, String message) {
    if (mounted) {
      setState(() => _busy = false);
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasLogo = _type != 'cash';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? l10n.accountFormEditTitle : l10n.accountFormNewTitle,
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    l10n.accountFieldType,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final type in accountTypeValues)
                        ChoiceChip(
                          label: Text(accountTypeLabel(l10n, type)),
                          selected: _type == type,
                          onSelected: (_) => setState(() {
                            _type = type;
                            if (type == 'cash') {
                              _providerKey = null;
                            }
                          }),
                        ),
                    ],
                  ),
                  if (hasLogo) ...[
                    const SizedBox(height: 16),
                    Text(
                      l10n.accountFieldProvider,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        for (final provider in ProviderLogos.all)
                          InkWell(
                            borderRadius: BorderRadius.circular(32),
                            onTap: () => setState(() {
                              _providerKey = provider.key;
                              if (_name.text.trim().isEmpty) {
                                _name.text = provider.name;
                              }
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  width: 2,
                                  color: _providerKey == provider.key
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                ),
                              ),
                              child: Tooltip(
                                message: provider.name,
                                child: ProviderLogo(providerKey: provider.key),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _name,
                    maxLength: 50,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.accountFieldName,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? l10n.validationNameRequired
                        : null,
                  ),
                  const SizedBox(height: 8),
                  MoneyField(
                    controller: _balance,
                    label: _isEdit
                        ? l10n.accountFieldOpeningBalanceEdit
                        : l10n.accountFieldOpeningBalance,
                    allowNegative: true,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.accountFieldOpeningDate),
                    subtitle: Text(formatCivilDateLong(_openingDate)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: _pickDate,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.accountFieldIncludeInTotal),
                    value: _includeInTotal,
                    onChanged: (value) =>
                        setState(() => _includeInTotal = value),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.accountFormHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(l10n.actionSave),
                  ),
                ],
              ),
            ),
    );
  }
}
