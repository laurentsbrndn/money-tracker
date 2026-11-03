import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/billing/paywall_package.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/platform/external_links.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/subscription_controller.dart';
import '../../domain/subscription_state.dart';
import '../widgets/billing_messages.dart';
import '../widgets/package_tile.dart';

/// The paywall (APP_FLOWS Flow 9): benefits, the monthly/yearly packages from
/// RevenueCat, restore, terms. After a purchase it waits for the server to
/// report premium; the screen never decides that itself.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({this.restoreOnOpen = false, super.key});

  /// Starts "Pulihkan pembelian" as soon as the screen opens (the button on
  /// the subscription screen).
  final bool restoreOnOpen;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    // Provider state may not change while the widget tree is being built.
    Future.microtask(() {
      final controller = ref.read(subscriptionControllerProvider.notifier)..open();
      if (widget.restoreOnOpen && controller.isAvailable) {
        unawaited(controller.restore());
      }
    });
  }

  String? _effectiveSelection(List<PaywallPackage> packages) {
    if (packages.isEmpty) {
      return null;
    }
    if (packages.any((p) => p.id == _selectedId)) {
      return _selectedId;
    }
    // The yearly package is listed last and is the default.
    return packages.last.id;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(subscriptionControllerProvider);
    final controller = ref.read(subscriptionControllerProvider.notifier);

    return PopScope(
      canPop: !state.busy,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.paywallTitle)),
        body: SafeArea(child: _body(context, l10n, state, controller)),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    SubscriptionState state,
    SubscriptionController controller,
  ) {
    switch (state.phase) {
      case SubscriptionPhase.purchasing:
      case SubscriptionPhase.processing:
        return _Progress(
          title: l10n.paywallProcessingTitle,
          body: l10n.paywallProcessingBody,
        );
      case SubscriptionPhase.confirmed:
        return EmptyState(
          icon: Icons.verified_outlined,
          title: l10n.paywallConfirmedTitle,
          message: l10n.paywallConfirmedBody,
          action: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.paywallDone),
          ),
        );
      case SubscriptionPhase.timedOut:
        return EmptyState(
          icon: Icons.hourglass_top,
          title: l10n.paywallTimedOutTitle,
          message: l10n.paywallTimedOutBody,
          action: FilledButton(
            onPressed: () => unawaited(controller.checkAgain()),
            child: Text(l10n.paywallCheckAgain),
          ),
        );
      case SubscriptionPhase.idle:
        break;
    }

    if (!controller.isAvailable) {
      return EmptyState(
        icon: Icons.storefront_outlined,
        title: l10n.paywallUnavailableTitle,
        message: l10n.paywallUnavailableBody,
      );
    }
    final packages = state.packages;
    final failure = state.packagesFailure;
    if (packages.isEmpty && state.packagesLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (packages.isEmpty && failure != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l10n.paywallUnavailableTitle,
        message: billingFailureMessage(l10n, failure),
        action: OutlinedButton(
          onPressed: () => unawaited(controller.loadPackages()),
          child: Text(l10n.paywallRetry),
        ),
      );
    }

    final selected = _effectiveSelection(packages);
    final notice = subscriptionNoticeMessage(l10n, state);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.paywallSubtitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        _Benefit(l10n.paywallBenefitLimits),
        _Benefit(l10n.paywallBenefitHistory),
        _Benefit(l10n.paywallBenefitReports),
        _Benefit(l10n.paywallBenefitRecurring),
        const SizedBox(height: 16),
        for (final package in packages)
          PackageTile(
            package: package,
            selected: package.id == selected,
            onTap: () => setState(() => _selectedId = package.id),
          ),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              notice,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: selected == null
              ? null
              : () => unawaited(controller.buy(selected)),
          child: Text(l10n.paywallSubscribe),
        ),
        TextButton(
          onPressed: () => unawaited(controller.restore()),
          child: Text(l10n.subscriptionRestore),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.paywallLegal,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            if (AppConfig.termsUrl.isNotEmpty)
              TextButton(
                onPressed: () =>
                    unawaited(ExternalLinks.open(AppConfig.termsUrl)),
                child: Text(l10n.paywallTerms),
              ),
            if (AppConfig.privacyUrl.isNotEmpty)
              TextButton(
                onPressed: () =>
                    unawaited(ExternalLinks.open(AppConfig.privacyUrl)),
                child: Text(l10n.paywallPrivacy),
              ),
          ],
        ),
      ],
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
