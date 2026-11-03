import '../../../core/database/app_database.dart';

/// An account with its expected balance as of today.
class AccountWithBalance {
  const AccountWithBalance({
    required this.account,
    required this.expectedBalance,
  });

  final AccountRow account;
  final int expectedBalance;
}
