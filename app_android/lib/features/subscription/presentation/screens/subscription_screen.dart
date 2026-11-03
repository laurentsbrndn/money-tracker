import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/billing/entitlement_info.dart';
import '../../../../core/billing/entitlement_provider.dart';
import '../../../../core/platform/external_links.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/time/civil_date_format.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/subscription_controller.dart';

/// Lainnya → Langganan: the plan, when it renews or ends, and the way to manage
/// it. All of it is the server's entitlement as cached by the last sync.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => unawaited(
        ref.read(subscriptionControllerProvider.notifier).refreshStatus(),
      ),
    );
  }

  Future<void> _manage(EntitlementInfo info) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final package = (await PackageInfo.fromPlatform()).packageName;
    final opened = await ExternalLinks.open(
      ExternalLinks.manageSubscriptionUrl(
        packageName: package,
        productId: info.productId,
      ),
    );
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.subscriptionManageFailed)),
      );
    }
  }

  String _planName(AppLocalizations l10n, String? productId) {
    if (productId == null) {
      return l10n.subscriptionPlanOther;
    }
    if (productId.contains('year')) {
      return l10n.subscriptionPlanYearly;
    }
    if (productId.contains('month')) {
      return l10n.subscriptionPlanMonthly;
    }
    return l10n.subscriptionPlanOther;
  }

  CivilDate _date(DateTime value) {
    final local = value.toLocal();
    return CivilDate(local.year, local.month, local.day);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final info =
        ref.watch(entitlementInfoProvider).value ?? EntitlementInfo.free;
    final now = DateTime.now();
    final expires = info.expiresAt;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.subscriptionTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        info.premium
                            ? Icons.workspace_premium
                            : Icons.person_outline,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          info.premium
                              ? l10n.subscriptionPremiumActive
                              : l10n.subscriptionFree,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!info.premium)
                    Text(l10n.subscriptionFreeBody)
                  else ...[
                    Text(
                      l10n.subscriptionPlan(_planName(l10n, info.productId)),
                    ),
                    if (expires != null)
                      Text(
                        info.willRenew
                            ? l10n.subscriptionRenewsOn(
                                formatCivilDateLong(_date(expires)),
                              )
                            : l10n.subscriptionEndsOn(
                                formatCivilDateLong(_date(expires)),
                              ),
                      ),
                    if (info.isInTolerance(now))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          l10n.subscriptionToleranceNote,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!info.premium)
            FilledButton(
              onPressed: () => context.push(RoutePaths.paywall),
              child: Text(l10n.subscriptionSeePlans),
            )
          else if (info.store == null || info.store == 'play_store')
            OutlinedButton(
              onPressed: () => unawaited(_manage(info)),
              child: Text(l10n.subscriptionManage),
            ),
          TextButton(
            onPressed: () => context.push(RoutePaths.paywallRestore),
            child: Text(l10n.subscriptionRestore),
          ),
        ],
      ),
    );
  }
}
