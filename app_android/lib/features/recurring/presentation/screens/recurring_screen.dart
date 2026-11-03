import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/billing/entitlement_provider.dart';
import '../../../../core/billing/plan_limits.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/time/user_clock.dart';
import '../../../../core/validation/validation_exception.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/plan_limit_snack_bar.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../settings/application/user_settings_providers.dart';
import '../../../transactions/application/transaction_lookups.dart';
import '../../application/recurring_providers.dart';
import '../widgets/recurring_rule_tile.dart';

/// Lainnya → Transaksi berulang (APP_FLOWS Flow 10): the rules, whether each
/// one runs, and the way to pause, resume, edit, or add one.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  Future<void> _togglePause(
    BuildContext context,
    WidgetRef ref,
    RecurringRuleRow rule,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref
          .read(recurringRepositoryProvider)
          .setPaused(rule, paused: !rule.isPaused);
    } on PlanLimitException {
      showPlanLimitSnackBar(
        messenger,
        router,
        l10n,
        l10n.recurringResumeNeedsPremium,
      );
    } on ValidationException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message(l10n))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rules = ref.watch(recurringRulesProvider);
    final categories = ref.watch(categoriesByIdProvider);
    final premium = ref.watch(isPremiumProvider).value ?? false;
    final hide = ref.watch(hideAmountsProvider);
    final today = ref.watch(userClockProvider).today();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.recurringTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          premium ? RoutePaths.recurringNew : RoutePaths.paywall,
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.recurringAdd),
      ),
      body: AsyncBody(
        value: rules,
        onRetry: () => ref.invalidate(recurringRulesProvider),
        builder: (data) {
          if (data.isEmpty) {
            return EmptyState(
              icon: Icons.repeat,
              title: premium
                  ? l10n.recurringEmptyTitle
                  : l10n.recurringLockedTitle,
              message: premium
                  ? l10n.recurringEmptyBody
                  : l10n.recurringLockedBody,
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              if (data.any((rule) => rule.isPaused) && !premium)
                Card(
                  margin: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.recurringPausedNoPremiumBody),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: () => context.push(RoutePaths.paywall),
                          child: Text(l10n.planLimitSeePremium),
                        ),
                      ],
                    ),
                  ),
                ),
              for (final rule in data)
                RecurringRuleTile(
                  rule: rule,
                  title: rule.type == 'transfer'
                      ? l10n.transactionTransfer
                      : (categories[rule.categoryId]?.name ??
                            l10n.transactionUncategorized),
                  today: today,
                  premium: premium,
                  hideAmounts: hide,
                  onTap: () => context.push(RoutePaths.recurringEdit(rule.id)),
                  onTogglePause: () =>
                      unawaited(_togglePause(context, ref, rule)),
                ),
            ],
          );
        },
      ),
    );
  }
}
