/// What the list shows for a rule (APP_FLOWS Flow 10).
enum RecurringRuleStatus {
  active,

  /// Paused by the user, or by the server for a reason the app does not know.
  paused,

  /// Paused while the server reports no premium: the server pauses every rule
  /// when premium ends (BUSINESS_RULES §7). It can only be resumed with
  /// premium.
  pausedNoPremium,

  /// The end date has passed and nothing is left to create.
  ended,
}
