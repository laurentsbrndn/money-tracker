import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/billing/entitlement_provider.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/time/user_clock.dart';
import '../../../../core/validation/validation_exception.dart';
import '../../../../core/widgets/date_tile.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../accounts/application/accounts_providers.dart';
import '../../../categories/application/categories_providers.dart';
import '../../../recurring/domain/recurring_prefill.dart';
import '../../application/transactions_providers.dart';
import '../../domain/transaction_draft.dart';
import '../widgets/account_dropdown.dart';
import '../widgets/amount_numpad.dart';
import '../widgets/category_picker.dart';

const List<String> _types = ['expense', 'income', 'transfer'];
const int _maxDigits = 12;

/// Entry/edit form for expense, income and transfer (APP_FLOWS Flow 3).
/// With [transactionId] it edits that transaction and the type is fixed.
class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({
    this.transactionId,
    this.initialType,
    this.fromAccountId,
    this.initialAmount,
    super.key,
  });

  final String? transactionId;
  final String? initialType;

  /// Prefill for a transfer started from an account (archive flow).
  final String? fromAccountId;
  final int? initialAmount;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _note = TextEditingController();
  final _source = TextEditingController();
  final _fee = TextEditingController();

  String _digits = '';
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  String? _allocation;
  late CivilDate _date;
  TransactionRow? _existing;
  bool _loaded = false;
  bool _busy = false;
  bool _defaultsApplied = false;
  List<String> _sourceSuggestions = const [];

  bool get _isEdit => widget.transactionId != null;
  String get _type => _types[_tabs.index];

  @override
  void initState() {
    super.initState();
    _date = ref.read(userClockProvider).today();
    final startType = _types.indexOf(widget.initialType ?? 'expense');
    _tabs = TabController(
      length: _types.length,
      vsync: this,
      initialIndex: startType < 0 ? 0 : startType,
    )..addListener(_onTabChanged);
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _digits = widget.initialAmount.toString();
    }
    _accountId = widget.fromAccountId;
    _loadSuggestions();
    if (_isEdit) {
      _loadExisting();
    } else {
      _loaded = true;
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _note.dispose();
    _source.dispose();
    _fee.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    final sources = await ref
        .read(transactionsRepositoryProvider)
        .recentSources();
    if (mounted) {
      setState(() => _sourceSuggestions = sources);
    }
  }

  Future<void> _loadExisting() async {
    final repository = ref.read(transactionsRepositoryProvider);
    final row = await repository.find(widget.transactionId!);
    if (!mounted) {
      return;
    }
    if (row == null || row.deletedAt != null || row.type == 'adjustment') {
      context.pop();
      return;
    }
    final fees = row.type == 'transfer'
        ? await repository.feesOf(row.id)
        : const <TransactionRow>[];
    if (!mounted) {
      return;
    }
    setState(() {
      _existing = row;
      _tabs.index = _types.indexOf(row.type);
      _digits = row.amount.toString();
      _accountId = row.accountId;
      _toAccountId = row.toAccountId;
      _categoryId = row.categoryId;
      _allocation = row.allocation;
      _date = row.transactionDate;
      _note.text = row.note ?? '';
      _source.text = row.source ?? '';
      if (fees.isNotEmpty) {
        _fee.text = groupThousands(fees.first.amount);
      }
      _defaultsApplied = true;
      _loaded = true;
    });
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) {
      return;
    }
    setState(() {
      _categoryId = null;
      _allocation = null;
      _toAccountId = null;
      _defaultsApplied = false;
    });
  }

  /// Picks the account used last for this type (APP_FLOWS Flow 3), once the
  /// accounts are known.
  Future<void> _applyDefaults(List<AccountRow> open) async {
    _defaultsApplied = true;
    if (_accountId != null && open.any((a) => a.id == _accountId)) {
      return;
    }
    final last = await ref
        .read(transactionsRepositoryProvider)
        .lastAccountId(_type);
    if (!mounted) {
      return;
    }
    setState(() {
      _accountId = open.any((a) => a.id == last)
          ? last
          : (open.isEmpty ? null : open.first.id);
    });
  }

  void _addDigits(String digits) {
    // No leading zeros: typing 0 on an empty amount stays empty.
    final next = (_digits + digits).replaceFirst(RegExp(r'^0+'), '');
    if (next.length > _maxDigits) {
      return;
    }
    setState(() => _digits = next);
  }

  void _backspace() {
    if (_digits.isEmpty) {
      return;
    }
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(transactionsRepositoryProvider)
          .save(
            TransactionDraft(
              type: _type,
              amount: _digits.isEmpty ? null : int.parse(_digits),
              accountId: _accountId,
              toAccountId: _type == 'transfer' ? _toAccountId : null,
              categoryId: _type == 'transfer' ? null : _categoryId,
              allocation: _type == 'expense' ? _allocation : null,
              source: _type == 'income' ? _source.text : null,
              note: _note.text,
              date: _date,
              fee: _type == 'transfer' ? MoneyField.valueOf(_fee) : null,
              existing: _existing,
            ),
          );
      router.pop();
    } on ValidationException catch (error) {
      _fail(messenger, error.message(l10n));
    } on Object catch (error) {
      _fail(messenger, describeError(error, l10n));
    }
  }

  /// "Jadikan berulang" (APP_FLOWS Flow 10): the fields typed so far become
  /// the template of a recurring rule. Recurring rules are a Premium feature,
  /// so a free user is taken to the paywall instead.
  void _makeRecurring() {
    final premium = ref.read(isPremiumProvider).value ?? false;
    if (!premium) {
      context.push(RoutePaths.paywall);
      return;
    }
    context.push(
      RoutePaths.recurringNew,
      extra: RecurringPrefill(
        type: _type,
        amount: _digits.isEmpty ? null : int.parse(_digits),
        accountId: _accountId,
        toAccountId: _type == 'transfer' ? _toAccountId : null,
        categoryId: _type == 'transfer' ? null : _categoryId,
        allocation: _type == 'expense' ? _allocation : null,
        source: _type == 'income' ? _source.text : null,
        note: _note.text,
        startDate: _date,
      ),
    );
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
    final accounts = ref.watch(allAccountsProvider).value ?? const [];
    final categories = ref.watch(allCategoriesProvider).value ?? const [];
    final usedIds = {_existing?.accountId, _existing?.toAccountId};
    final selectable = [
      for (final account in accounts)
        if (account.archivedAt == null || usedIds.contains(account.id)) account,
    ];
    if (_loaded && !_defaultsApplied && !_isEdit && selectable.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _applyDefaults(selectable),
      );
      _defaultsApplied = true;
    }
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.txFormEditTitle : l10n.txFormNewTitle),
        actions: [
          if (!_isEdit)
            IconButton(
              tooltip: l10n.txMakeRecurring,
              onPressed: _makeRecurring,
              icon: const Icon(Icons.repeat),
            ),
        ],
        bottom: _isEdit
            ? null
            : TabBar(
                controller: _tabs,
                tabs: [
                  Tab(text: l10n.transactionTypeExpense),
                  Tab(text: l10n.transactionTypeIncome),
                  Tab(text: l10n.transactionTypeTransfer),
                ],
              ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _AmountHeader(digits: _digits),
                Expanded(
                  child: selectable.isEmpty
                      ? Center(child: Text(l10n.txNoAccounts))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: _fields(l10n, selectable, categories),
                        ),
                ),
                if (!keyboardOpen) ...[
                  AmountNumpad(
                    onDigits: _addDigits,
                    onBackspace: _backspace,
                    onClear: () => setState(() => _digits = ''),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: FilledButton(
                    onPressed: _busy || selectable.isEmpty ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(l10n.actionSave),
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _fields(
    AppLocalizations l10n,
    List<AccountRow> accounts,
    List<CategoryRow> categories,
  ) {
    final type = _type;
    final visibleCategories = [
      for (final category in categories)
        if (category.type == type &&
            ((!category.isHidden && category.archivedAt == null) ||
                category.id == _categoryId))
          category,
    ];
    final fromAccount = accounts.where((a) => a.id == _accountId).firstOrNull;
    final toAccount = accounts.where((a) => a.id == _toAccountId).firstOrNull;
    final toSavings =
        toAccount?.type == 'savings' && fromAccount?.type != 'savings';
    final fields = <Widget>[];

    if (type == 'expense') {
      fields
        ..add(_label(l10n.txFieldCategory))
        ..add(
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
        )
        ..add(const SizedBox(height: 12))
        ..add(_label(l10n.txFieldAllocation))
        ..add(
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
        );
    }

    if (type == 'income') {
      fields
        ..add(
          TextField(
            controller: _source,
            maxLength: 100,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.txFieldSource,
              border: const OutlineInputBorder(),
            ),
          ),
        )
        ..add(
          _sourceSuggestions.isEmpty
              ? const SizedBox.shrink()
              : Wrap(
                  spacing: 8,
                  children: [
                    for (final suggestion in _sourceSuggestions)
                      ActionChip(
                        label: Text(suggestion),
                        onPressed: () =>
                            setState(() => _source.text = suggestion),
                      ),
                  ],
                ),
        )
        ..add(const SizedBox(height: 12))
        ..add(_label(l10n.txFieldCategory))
        ..add(
          CategoryPicker(
            categories: visibleCategories,
            selectedId: _categoryId,
            onSelected: (category) => setState(() => _categoryId = category.id),
          ),
        );
    }

    fields
      ..add(const SizedBox(height: 16))
      ..add(
        AccountDropdown(
          label: type == 'transfer'
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
      );

    if (type == 'transfer') {
      fields
        ..add(const SizedBox(height: 16))
        ..add(
          AccountDropdown(
            label: l10n.txFieldToAccount,
            accounts: [
              for (final account in accounts)
                if (account.id != _accountId) account,
            ],
            value: _toAccountId,
            onChanged: (value) => setState(() => _toAccountId = value),
          ),
        );
      if (toSavings) {
        fields
          ..add(const SizedBox(height: 8))
          ..add(
            Row(
              children: [
                const Icon(Icons.savings_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.txTransferToSavingsHint)),
              ],
            ),
          );
      }
      fields
        ..add(const SizedBox(height: 16))
        ..add(MoneyField(controller: _fee, label: l10n.txFieldFee));
    }

    fields
      ..add(const SizedBox(height: 8))
      ..add(
        DateTile(
          label: l10n.txFieldDate,
          date: _date,
          onChanged: (value) => setState(() => _date = value),
        ),
      )
      ..add(
        TextField(
          controller: _note,
          maxLength: 255,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: switch (type) {
              'expense' => l10n.txFieldNoteExpense,
              'income' => l10n.txFieldNoteIncome,
              _ => l10n.txFieldNoteTransfer,
            },
            border: const OutlineInputBorder(),
          ),
        ),
      );
    return fields;
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 4),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}

class _AmountHeader extends StatelessWidget {
  const _AmountHeader({required this.digits});

  final String digits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = digits.isEmpty ? 0 : int.parse(digits);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Text(
        formatRupiah(value),
        textAlign: TextAlign.center,
        style: theme.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: digits.isEmpty ? theme.colorScheme.outline : null,
        ),
      ),
    );
  }
}
