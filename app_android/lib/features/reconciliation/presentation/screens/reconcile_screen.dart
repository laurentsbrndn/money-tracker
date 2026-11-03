import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain_rules/reconciliation.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../settings/application/user_settings_providers.dart';
import '../../application/reconciliation_providers.dart';
import '../../domain/reconcile_item.dart';
import '../widgets/reconcile_input_tile.dart';
import '../widgets/reconcile_result_tile.dart';
import '../widgets/reconcile_summary_card.dart';

/// Cocokkan saldo (APP_FLOWS Flow 5): enter the real balance per account, see
/// the difference, then record what was missed, adjust, or leave it.
class ReconcileScreen extends ConsumerStatefulWidget {
  const ReconcileScreen({super.key});

  @override
  ConsumerState<ReconcileScreen> createState() => _ReconcileScreenState();
}

class _ReconcileScreenState extends ConsumerState<ReconcileScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerOf(String accountId) =>
      _controllers.putIfAbsent(accountId, TextEditingController.new);

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final session = ref.read(reconcileSessionProvider);
    final balances = <String, int>{};
    for (final entry in _controllers.entries) {
      if (session.reconciled.contains(entry.key)) {
        continue;
      }
      final value = MoneyField.valueOf(entry.value, negative: true);
      if (value != null) {
        balances[entry.key] = value;
      }
    }
    if (balances.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.reconcileNeedsInput)));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(reconcileSessionProvider.notifier).submit(balances);
      for (final id in balances.keys) {
        _controllers[id]?.clear();
      }
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeError(error, l10n))),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _adjust(ReconcileItem item, bool hide) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.reconcileAdjustTitle),
        content: Text(
          l10n.reconcileAdjustBody(
            formatSignedRupiah(item.result.diff, hidden: hide),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.reconcileAdjust),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(reconcileSessionProvider.notifier)
          .adjust(item.account.id, l10n.reconcileAdjustNote);
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeError(error, l10n))),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _recordMissed(ReconcileItem item) {
    final diff = item.result.diff;
    unawaited(
      context.push(
        RoutePaths.transactionMissed(
          accountId: item.account.id,
          // The real balance is lower than recorded: an expense is missing.
          type: diff < 0 ? 'expense' : 'income',
          amount: diff.abs(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(reconcileViewProvider);
    final session = ref.watch(reconcileSessionProvider);
    final hide = ref.watch(hideAmountsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reconcileTitle)),
      body: AsyncBody(
        value: view,
        onRetry: () => ref.invalidate(reconcileViewProvider),
        builder: (data) {
          final items = data.active;
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: l10n.reconcileEmptyTitle,
              message: l10n.reconcileEmptyBody,
            );
          }
          final reconciledItems = [
            for (final item in items)
              if (session.reconciled.contains(item.account.id)) item,
          ];
          final matched = reconciledItems
              .where(
                (item) => item.result.status == ReconciliationStatus.matched,
              )
              .length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Text(l10n.reconcileIntro),
              const SizedBox(height: 12),
              if (reconciledItems.isNotEmpty) ...[
                ReconcileSummaryCard(
                  matched: matched,
                  total: reconciledItems.length,
                  adjustedTotal: session.adjustedTotal,
                  hideAmounts: hide,
                ),
                const SizedBox(height: 4),
              ],
              for (final item in items)
                if (session.reconciled.contains(item.account.id))
                  ReconcileResultTile(
                    item: item,
                    hideAmounts: hide,
                    deferred: session.deferred.contains(item.account.id),
                    adjustedAmount: session.adjusted[item.account.id],
                    onMissed: () => _recordMissed(item),
                    onAdjust: _busy
                        ? () {}
                        : () => unawaited(_adjust(item, hide)),
                    onLater: () => ref
                        .read(reconcileSessionProvider.notifier)
                        .defer(item.account.id),
                    onReview: () => ref
                        .read(reconcileSessionProvider.notifier)
                        .undefer(item.account.id),
                  )
                else
                  ReconcileInputTile(
                    item: item,
                    controller: _controllerOf(item.account.id),
                    hideAmounts: hide,
                  ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(l10n.reconcileSubmit),
          ),
        ),
      ),
    );
  }
}
