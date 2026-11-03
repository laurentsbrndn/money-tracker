import 'civil_date.dart';

/// Today's calendar date on the device. Fase 2 replaces this with the user's
/// timezone (`core/time/user_clock.dart`).
CivilDate todayCivil() => CivilDate.fromDateTime(DateTime.now());
