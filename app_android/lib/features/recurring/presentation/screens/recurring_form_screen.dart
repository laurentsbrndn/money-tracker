import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/billing/entitlement_provider.dart';
import '../../../../core/billing/plan_limits.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/domain_rules/recurrence.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/time/civil_date_format.dart';
import '../../../../core/time/user_clock.dart';
import '../../../../core/validation/validation_exception.dart';
import '../../../../core/widgets/date_tile.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/plan_limit_snack_bar.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../accounts/application/accounts_providers.dart';
import '../../../categories/application/categories_providers.dart';
import '../../../transactions/presentation/widgets/account_dropdown.dart';
import '../../../transactions/presentation/widgets/category_picker.dart';
import '../../application/recurring_providers.dart';
import '../../domain/recurring_prefill.dart';
import '../../domain/recurring_rule_input.dart';

/// Create or edit a recurring rule (APP_FLOWS Flow 10). With [ruleId] it edits
/// that rule; with [prefill] a new rule starts from a transaction.
class RecurringFormScreen extends ConsumerStatefulWidget {
  const RecurringFormScreen({this.ruleId, this.prefill, super.key});

  final String? ruleId;
  final RecurringPrefill? prefill;

  @override
  ConsumerState<RecurringFormScreen> createState() =>
      _RecurringFormScreenState();
}

class _RecurringFormScreenState extends ConsumerState<RecurringFormScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _source = TextEditingController();
  final _interval = TextEditingController(text: '1');

  String _type = 'expense';
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  String? _allocation;
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  int _dayOfWeek = 1;
  int _dayOfMonth = 1;
  int _monthOfYear = 1;
  late CivilDate _start;
  CivilDate? _end;
  String _mode = 'auto';
  RecurringRuleRow? _existing;
  bool _loaded = false;
  bool _busy = false;

  bool get _isEdit => widget.ruleId != null;

  @override
  void initState() {
    super.initState();
    _start = ref.read(userClockProvider).today();
    final prefill = widget.prefill;
    if (prefill != null) {
      _type = prefill.type;
      _start = prefill.startDate;
      _accountId = prefill.accountId;
      _toAccountId = prefill.toAccountId;
      _categoryId = prefill.categoryId;
      _allocation = prefill.allocation;
      _note.text = prefill.note ?? '';
      _source.text = prefill.source ?? '';
      if (prefill.amount != null && prefill.amount! > 0) {
        _amount.text = groupThousands(prefill.amount!);
      }
    }
    _applyScheduleDefaults();
    if (_isEdit) {
      unawaited(_loadExisting());
    } else {
      _loaded = true;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _source.dispose();
    _interval.dispose();
    super.dispose();
  }

  /// The day fields start from the first occurrence's date.
  void _applyScheduleDefaults() {
    _dayOfWeek = _start.weekday;
    _dayOfMonth = _start.day;
    _monthOfYear = _start.month;
  }

  Future<void> _loadExisting() async {
    final row = await ref
        .read(recurringRepositoryProvider)
        .find(widget.ruleId!);
    if (!mounted) {
      return;
    }
    if (row == null || row.deletedAt != null) {
      context.pop();
      return;
    }
    setState(() {
      _existing = row;
      _type = row.type;
      _amount.text = groupThousands(row.amount);
      _accountId = row.accountId;
      _toAccountId = row.toAccountId;
      _categoryId = row.categoryId;
      _allocation = row.allocation;
      _note.text = row.note ?? '';
      _source.text = row.source ?? '';
      _frequency = RecurringFrequency.fromValue(row.frequency);
      _interval.text = '${row.intervalCount}';
      _dayOfWeek = row.dayOfWeek ?? row.startDate.weekday;
      _dayOfMonth = row.dayOfMonth ?? row.startDate.day;
      _monthOfYear = row.monthOfYear ?? row.startDate.month;
      _start = row.startDate;
      _end = row.endDate;
      _mode = row.mode;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(recurringRepositoryProvider)
          .save(
            RecurringRuleInput(
              type: _type,
              amount: MoneyField.valueOf(_amount),
              accountId: _accountId,
              toAccountId: _type == 'transfer' ? _toAccountId : null,
              categoryId: _type == 'transfer' ? null : _categoryId,
              allocation: _type == 'expense' ? _allocation : null,
              source: _type == 'income' ? _source.text : null,
              note: _note.text,
              frequency: _frequency,
              intervalCount: int.tryParse(_interval.text) ?? 0,
              dayOfWeek: _dayOfWeek,
              dayOfMonth: _dayOfMonth,
              monthOfYear: _monthOfYear,
              startDate: _start,
              endDate: _end,
              mode: _mode,
            ),
            existing: _existing,
          );
      messenger.showSnackBar(SnackBar(content: Text(l10n.recurringSaved)));
      router.pop();
    } on ValidationException catch (error) {
      _fail(messenger, error.message(l10n));
    } on PlanLimitException {
      if (mounted) {
        setState(() => _busy = false);
      }
      showPlanLimitSnackBar(messenger, router, l10n, l10n.planLimitRecurring);
    } on Object catch (error) {
      _fail(messenger, describeError(error, l10n));
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.recurringDelete),
        content: Text(l10n.recurringDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(recurringRepositoryProvider).delete(_existing!.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.recurringDeleted)));
    router.pop();
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
    final premium = ref.watch(isPremiumProvider).value ?? false;
    final accounts = ref.watch(allAccountsProvider).value ?? const [];
    final categories = ref.watch(allCategoriesProvider).value ?? const [];

    // Creating a rule is a Premium feature; editing an existing one is not.
    if (!_isEdit && !premium) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.recurringNewTitle)),
        body: EmptyState(
          icon: Icons.repeat,
          title: l10n.recurringLockedTitle,
          message: l10n.recurringLockedBody,
          action: FilledButton(
            onPressed: () => context.pushReplacement(RoutePaths.paywall),
            child: Text(l10n.planLimitSeePremium),
          ),
        ),
      );
    }

    final usedIds = {_existing?.accountId, _existing?.toAccountId};
    final selectable = [
      for (final account in accounts)
        if (account.archivedAt == null || usedIds.contains(account.id)) account,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.recurringEditTitle : l10n.recurringNewTitle),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: l10n.recurringDelete,
              onPressed: _busy ? null : () => unawaited(_delete()),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ..._template(l10n, selectable, categories),
                const SizedBox(height: 24),
                ..._schedule(l10n),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy || selectable.isEmpty ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(l10n.actionSave),
                ),
              ],
            ),
    );
  }

  List<Widget> _template(
    AppLocalizations l10n,
    List<AccountRow> accounts,
    List<CategoryRow> categories,
  ) {
    final visibleCategories = [
      for (final category in categories)
        if (category.type == _type &&
            ((!category.isHidden && category.archivedAt == null) ||
                category.id == _categoryId))
          category,
    ];
    return [
      SegmentedButton<String>(
        segments: [
          ButtonSegment(
            value: 'expense',
            label: Text(l10n.transactionTypeExpense),
          ),
          ButtonSegment(
            value: 'income',
            label: Text(l10n.transactionTypeIncome),
          ),
          ButtonSegment(
            value: 'transfer',
            label: Text(l10n.transactionTypeTransfer),
          ),
        ],
        selected: {_type},
        onSelectionChanged: _isEdit
            ? null
            : (selection) => setState(() {
                _type = selection.first;
                _categoryId = null;
                _allocation = null;
                _toAccountId = null;
              }),
      ),
      const SizedBox(height: 16),
      MoneyField(controller: _amount, label: l10n.txFieldAmount),
      const SizedBox(height: 16),
      if (_type == 'expense') ...[
        _label(l10n.txFieldCategory),
        visibleCategories.isEmpty
            ? Text(l10n.txNoCategories)
            : CategoryPicker(
                categories: visibleCategories,
                selectedId: _categoryId,
                onSelected: (category) => setState(() {
                  _categoryId = category.id;
                  _allocation = category.defaultAllocation ?? _allocation;
                }),
              ),
        const SizedBox(height: 12),
        _label(l10n.txFieldAllocation),
        Wrap(
          spacing: 8,
          children: [
            for (final entry in {
              'needs': l10n.allocationNeeds,
              'wants': l10n.allocationWants,
              'savings': l10n.allocationSavings,
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _allocation == entry.key,
                onSelected: (_) => setState(() => _allocation = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
      if (_type == 'income') ...[
        TextField(
          controller: _source,
          maxLength: 100,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.txFieldSource,
            border: const OutlineInputBorder(),
          ),
        ),
        _label(l10n.txFieldCategory),
        CategoryPicker(
          categories: visibleCategories,
          selectedId: _categoryId,
          onSelected: (category) => setState(() => _categoryId = category.id),
        ),
        const SizedBox(height: 16),
      ],
      AccountDropdown(
        label: _type == 'transfer'
            ? l10n.txFieldFromAccount
            : l10n.txFieldAccount,
        accounts: accounts,
        value: _accountId,
        onChanged: (value) => setState(() {
          _accountId = value;
          if (_toAccountId == value) {
            _toAccountId = null;
          }
        }),
      ),
      if (_type == 'transfer') ...[
        const SizedBox(height: 16),
        AccountDropdown(
          label: l10n.txFieldToAccount,
          accounts: [
            for (final account in accounts)
              if (account.id != _accountId) account,
          ],
          value: _toAccountId,
          onChanged: (value) => setState(() => _toAccountId = value),
        ),
      ],
      const SizedBox(height: 16),
      TextField(
        controller: _note,
        maxLength: 255,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: switch (_type) {
            'expense' => l10n.txFieldNoteExpense,
            'income' => l10n.txFieldNoteIncome,
            _ => l10n.txFieldNoteTransfer,
          },
          border: const OutlineInputBorder(),
        ),
      ),
    ];
  }

  List<Widget> _schedule(AppLocalizations l10n) {
    final unit = switch (_frequency) {
      RecurringFrequency.daily => l10n.recurringUnitDay,
      RecurringFrequency.weekly => l10n.recurringUnitWeek,
      RecurringFrequency.monthly => l10n.recurringUnitMonth,
      RecurringFrequency.yearly => l10n.recurringUnitYear,
    };
    return [
      DropdownButtonFormField<RecurringFrequency>(
        initialValue: _frequency,
        decoration: InputDecoration(
          labelText: l10n.recurringFieldFrequency,
          border: const OutlineInputBorder(),
        ),
        items: [
          DropdownMenuItem(
            value: RecurringFrequency.daily,
            child: Text(l10n.recurringFrequencyDaily),
          ),
          DropdownMenuItem(
            value: RecurringFrequency.weekly,
            child: Text(l10n.recurringFrequencyWeekly),
          ),
          DropdownMenuItem(
            value: RecurringFrequency.monthly,
            child: Text(l10n.recurringFrequencyMonthly),
          ),
          DropdownMenuItem(
            value: RecurringFrequency.yearly,
            child: Text(l10n.recurringFrequencyYearly),
          ),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _frequency = value;
              _applyScheduleDefaults();
            });
          }
        },
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _interval,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: l10n.recurringFieldEvery,
          suffixText: unit,
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 16),
      if (_frequency == RecurringFrequency.weekly) ...[
        _label(l10n.recurringFieldWeekday),
        Wrap(
          spacing: 8,
          children: [
            for (var day = 1; day <= 7; day++)
              ChoiceChip(
                label: Text(weekdayName(day)),
                selected: _dayOfWeek == day,
                onSelected: (_) => setState(() => _dayOfWeek = day),
              ),
          ],
        ),
      ],
      if (_frequency == RecurringFrequency.yearly)
        DropdownButtonFormField<int>(
          initialValue: _monthOfYear,
          decoration: InputDecoration(
            labelText: l10n.recurringFieldMonth,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (var month = 1; month <= 12; month++)
              DropdownMenuItem(value: month, child: Text(monthName(month))),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _monthOfYear = value;
                final most = CivilDate.daysInMonth(2024, value);
                if (_dayOfMonth > most) {
                  _dayOfMonth = most;
                }
              });
            }
          },
        ),
      if (_frequency == RecurringFrequency.monthly ||
          _frequency == RecurringFrequency.yearly) ...[
        if (_frequency == RecurringFrequency.yearly) const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _dayOfMonth,
          decoration: InputDecoration(
            labelText: l10n.recurringFieldDay,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (
              var day = 1;
              day <=
                  (_frequency == RecurringFrequency.yearly
                      ? CivilDate.daysInMonth(2024, _monthOfYear)
                      : 31);
              day++
            )
              DropdownMenuItem(value: day, child: Text('$day')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _dayOfMonth = value);
            }
          },
        ),
        if (_dayOfMonth > 28)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.recurringMonthEndHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
      const SizedBox(height: 8),
      DateTile(
        label: l10n.recurringFieldStart,
        date: _start,
        onChanged: (value) => setState(() {
          _start = value;
          _applyScheduleDefaults();
        }),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.recurringHasEnd),
        value: _end != null,
        onChanged: (on) =>
            setState(() => _end = on ? _start.addDays(365) : null),
      ),
      if (_end != null)
        DateTile(
          label: l10n.recurringFieldEnd,
          date: _end!,
          firstDate: _start,
          lastDate: _start.addDays(365 * 30),
          onChanged: (value) => setState(() => _end = value),
        ),
      const SizedBox(height: 8),
      _label(l10n.recurringFieldMode),
      SegmentedButton<String>(
        segments: [
          ButtonSegment(value: 'auto', label: Text(l10n.recurringModeAuto)),
          ButtonSegment(
            value: 'confirm',
            label: Text(l10n.recurringModeConfirm),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: (selection) =>
            setState(() => _mode = selection.first),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          _mode == 'auto'
              ? l10n.recurringModeAutoHint
              : l10n.recurringModeConfirmHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ];
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 4),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}
