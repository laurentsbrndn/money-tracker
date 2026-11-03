import 'account_with_balance.dart';

/// All accounts with expected balances and the expected total of the accounts
/// that count towards it (BUSINESS_RULES §4.2).
class AccountsOverview {
  const AccountsOverview({required this.items, required this.expectedTotal});

  final List<AccountWithBalance> items;
  final int expectedTotal;
}
