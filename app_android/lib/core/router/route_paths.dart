abstract final class RoutePaths {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String verifyEmail = '/auth/verify-email';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String initialSync = '/initial-sync';
  static const String setup = '/setup';
  static const String upgradeRequired = '/upgrade-required';

  static const String home = '/home';
  static const String transactions = '/transactions';
  static const String transactionNew = '/transactions/new';
  static const String accounts = '/accounts';
  static const String accountNew = '/accounts/new';
  static const String accountEditPattern = '/accounts/:id/edit';
  static const String reconcile = '/reconcile';
  static const String budget = '/budget';
  static const String budgetGoal = '/budget/goal';
  static const String more = '/more';
  static const String subscription = '/more/subscription';
  static const String paywall = '/paywall';

  /// The paywall, starting a restore of past purchases at once.
  static const String paywallRestore = '/paywall?restore=1';
  static const String reports = '/more/reports';
  static const String export = '/more/export';
  static const String recurring = '/more/recurring';
  static const String recurringNew = '/more/recurring/new';
  static const String recurringEditPattern = '/more/recurring/:id';
  static const String categories = '/more/categories';
  static const String categoryNew = '/more/categories/new';
  static const String settingsProfile = '/more/settings/profile';
  static const String settingsPassword = '/more/settings/password';
  static const String settingsPreferences = '/more/settings/preferences';
  static const String settingsSecurity = '/more/settings/security';
  static const String settingsPin = '/more/settings/security/pin';
  static const String settingsNotifications = '/more/settings/notifications';
  static const String settingsSync = '/more/settings/sync';
  static const String settingsDeleteAccount = '/more/settings/delete-account';

  /// Entry form for a transaction missed on [accountId], prefilled with the
  /// difference to explain.
  static String transactionMissed({
    required String accountId,
    required String type,
    required int amount,
  }) => '$transactionNew?type=$type&from=$accountId&amount=$amount';

  static String transaction(String id) => '/transactions/$id';
  static String account(String id) => '/accounts/$id';
  static String recurringEdit(String id) => '/more/recurring/$id';
  static String categoryEdit(String id) => '/more/categories/$id';
  static String accountEdit(String id) => '/accounts/$id/edit';
}
