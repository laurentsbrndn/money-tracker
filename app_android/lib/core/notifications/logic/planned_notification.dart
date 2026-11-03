import '../../time/civil_date.dart';

enum NotificationKind {
  daily,
  reconcileMonthEnd,
  reconcileStale,
  monthEvaluation,
}

/// One scheduled notification, as a wall-clock moment in the user's timezone.
/// The text is added when it is scheduled, so this stays pure.
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.kind,
    required this.date,
    required this.hour,
    required this.minute,
    required this.payload,
  });

  final int id;
  final NotificationKind kind;
  final CivilDate date;
  final int hour;
  final int minute;

  /// App route opened when the notification is tapped.
  final String payload;

  int get minutesOfDay => hour * 60 + minute;

  @override
  String toString() =>
      '#$id ${kind.name} $date ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $payload';
}
