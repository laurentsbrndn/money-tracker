import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/billing/billing_providers.dart';
import 'core/notifications/notification_coordinator.dart';
import 'core/router/app_router.dart';
import 'core/security/lock_gate.dart';
import 'core/sync/sync_scheduler.dart';
import 'core/theme/app_theme.dart';
import 'features/recurring/application/recurring_providers.dart';
import 'features/settings/application/user_settings_providers.dart';
import 'l10n/generated/app_localizations.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Starts the sync triggers (resume, connectivity, post-login) once.
    ref.watch(syncSchedulerProvider);
    // Keeps the store customer equal to the signed-in user, and re-sends the
    // changes the plan refused once the server reports premium.
    ref
      ..watch(billingSessionSyncProvider)
      ..watch(premiumRetryCoordinatorProvider);
    // Creates the occurrences of recurring rules that came due.
    ref.watch(recurringCoordinatorProvider);
    // Keeps the local notifications in step with settings and data.
    ref.watch(notificationCoordinatorProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(appThemeModeProvider),
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) =>
          LockGate(child: child ?? const SizedBox.shrink()),
      locale: const Locale('id'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
