import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../router/route_paths.dart';

/// A free-plan limit was hit (BUSINESS_RULES §7): says which one and offers the
/// way out, the paywall.
void showPlanLimitSnackBar(
  ScaffoldMessengerState messenger,
  GoRouter router,
  AppLocalizations l10n,
  String message,
) {
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: l10n.planLimitSeePremium,
          onPressed: () => unawaited(router.push(RoutePaths.paywall)),
        ),
      ),
    );
}
