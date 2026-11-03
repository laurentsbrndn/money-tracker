import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_coordinator.dart';

/// Whether the system lets the app post notifications. Invalidate it after
/// asking for the permission or coming back from the system settings.
final notificationPermissionProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(notificationServiceProvider).areEnabled(),
);
