import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/accounts/presentation/screens/account_detail_screen.dart';
import '../../features/accounts/presentation/screens/account_form_screen.dart';
import '../../features/accounts/presentation/screens/accounts_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/budget/presentation/screens/budget_screen.dart';
import '../../features/categories/presentation/screens/categories_screen.dart';
import '../../features/categories/presentation/screens/category_form_screen.dart';
import '../../features/dashboard/presentation/screens/home_screen.dart';
import '../../features/onboarding/presentation/screens/initial_sync_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/setup_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/settings/presentation/screens/change_password_screen.dart';
import '../../features/settings/presentation/screens/delete_account_screen.dart';
import '../../features/settings/presentation/screens/more_screen.dart';
import '../../features/settings/presentation/screens/profile_screen.dart';
import '../../features/settings/presentation/screens/sync_settings_screen.dart';
import '../../features/settings/presentation/screens/upgrade_required_screen.dart';
import '../../features/transactions/presentation/screens/transaction_form_screen.dart';
import '../../features/transactions/presentation/screens/transactions_screen.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/session_controller.dart';
import '../auth/session_state.dart';
import '../network/api_client_provider.dart';
import 'app_gate.dart';
import 'route_paths.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final refresh = ValueNotifier<int>(0);
  void bump(Object? previous, Object? next) => refresh.value++;
  ref
    ..listen(appGateProvider, bump)
    ..listen(sessionControllerProvider, bump)
    ..listen(upgradeRequiredProvider, bump)
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state.matchedLocation),
    routes: [
      GoRoute(
        path: RoutePaths.upgradeRequired,
        builder: (context, state) => const UpgradeRequiredScreen(),
      ),
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RoutePaths.verifyEmail,
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.resetPassword,
        builder: (context, state) => ResetPasswordScreen(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: RoutePaths.initialSync,
        builder: (context, state) => const InitialSyncScreen(),
      ),
      GoRoute(
        path: RoutePaths.setup,
        builder: (context, state) => const SetupScreen(),
      ),
      GoRoute(
        path: RoutePaths.transactionNew,
        builder: (context, state) => TransactionFormScreen(
          initialType: state.uri.queryParameters['type'],
          fromAccountId: state.uri.queryParameters['from'],
          initialAmount: int.tryParse(
            state.uri.queryParameters['amount'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/transactions/:id',
        builder: (context, state) =>
            TransactionFormScreen(transactionId: state.pathParameters['id']),
      ),
      GoRoute(
        path: RoutePaths.accountNew,
        builder: (context, state) => const AccountFormScreen(),
      ),
      GoRoute(
        path: RoutePaths.accountEditPattern,
        builder: (context, state) =>
            AccountFormScreen(accountId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/accounts/:id',
        builder: (context, state) =>
            AccountDetailScreen(accountId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.categories,
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: RoutePaths.categoryNew,
        builder: (context, state) =>
            CategoryFormScreen(type: state.uri.queryParameters['type']),
      ),
      GoRoute(
        path: '/more/categories/:id',
        builder: (context, state) =>
            CategoryFormScreen(categoryId: state.pathParameters['id']),
      ),
      GoRoute(
        path: RoutePaths.settingsProfile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.settingsPassword,
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.settingsSync,
        builder: (context, state) => const SyncSettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.settingsDeleteAccount,
        builder: (context, state) => const DeleteAccountScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _MainShell(shell: shell),
        branches: [
          _branch(RoutePaths.home, const HomeScreen()),
          _branch(RoutePaths.transactions, const TransactionsScreen()),
          _branch(RoutePaths.accounts, const AccountsScreen()),
          _branch(RoutePaths.budget, const BudgetScreen()),
          _branch(RoutePaths.more, const MoreScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}

/// Gate rules (APP_FLOWS Flow 1). A session that needs a fresh login keeps the
/// app usable; only the login screens stay reachable on top of it.
String? _redirect(Ref ref, String location) {
  // The server refused this app version (426): nothing else is usable.
  if (ref.read(upgradeRequiredProvider)) {
    return location == RoutePaths.upgradeRequired
        ? null
        : RoutePaths.upgradeRequired;
  }
  final gate = ref.read(appGateProvider);
  final needsLogin =
      ref.read(sessionControllerProvider).status == SessionStatus.needsLogin;
  bool at(String path) => location == path;
  String? stay(String target) => location == target ? null : target;

  switch (gate) {
    case AppGate.loading:
      return stay(RoutePaths.splash);
    case AppGate.signedOut:
      final authArea =
          location.startsWith('/auth/') || at(RoutePaths.onboarding);
      return authArea ? null : RoutePaths.onboarding;
    case AppGate.initialSync:
      final loginOnTop = needsLogin && at(RoutePaths.login);
      return loginOnTop ? null : stay(RoutePaths.initialSync);
    case AppGate.setup:
      const beforeSetup = [
        RoutePaths.splash,
        RoutePaths.onboarding,
        RoutePaths.register,
        RoutePaths.initialSync,
        RoutePaths.home,
      ];
      if (beforeSetup.contains(location) ||
          (at(RoutePaths.login) && !needsLogin)) {
        return RoutePaths.setup;
      }
      return null;
    case AppGate.ready:
      const entryScreens = [
        RoutePaths.splash,
        RoutePaths.onboarding,
        RoutePaths.register,
        RoutePaths.initialSync,
        RoutePaths.setup,
      ];
      if (entryScreens.contains(location)) {
        return RoutePaths.home;
      }
      if (at(RoutePaths.login) && !needsLogin) {
        return RoutePaths.home;
      }
      return null;
  }
}

StatefulShellBranch _branch(String path, Widget screen) {
  return StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (context, state) => screen)],
  );
}

class _MainShell extends StatelessWidget {
  const _MainShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.tabHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: l10n.tabTransactions,
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: l10n.tabAccounts,
          ),
          NavigationDestination(
            icon: const Icon(Icons.pie_chart_outline),
            selectedIcon: const Icon(Icons.pie_chart),
            label: l10n.tabBudget,
          ),
          NavigationDestination(
            icon: const Icon(Icons.more_horiz),
            selectedIcon: const Icon(Icons.more_horiz),
            label: l10n.tabMore,
          ),
        ],
      ),
    );
  }
}
