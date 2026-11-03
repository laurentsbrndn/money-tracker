import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// The two Android channels: reminders (quiet) and budget warnings.
enum NotificationChannel {
  reminders('reminders'),
  budget('budget_alerts');

  const NotificationChannel(this.id);

  final String id;
}

/// Thin wrapper over `flutter_local_notifications` (FRONTEND_FLUTTER §4.5).
/// Scheduling is always inexact (`inexactAllowWhileIdle`): no exact-alarm
/// permission is needed because a reminder a few minutes late is fine.
class NotificationService {
  NotificationService({
    required this._remindersChannelName,
    required this._budgetChannelName,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final String _remindersChannelName;
  final String _budgetChannelName;
  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String> _taps = StreamController<String>.broadcast();
  Future<void>? _initialization;

  /// Payloads (app routes) of tapped notifications.
  Stream<String> get taps => _taps.stream;

  /// Registers the plugin and the channels once; every other method waits for
  /// it, so the service also works from the background sync isolate.
  Future<void> ensureInitialized() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _taps.add(payload);
        }
      },
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        NotificationChannel.reminders.id,
        _remindersChannelName,
        importance: Importance.defaultImportance,
      ),
    );
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        NotificationChannel.budget.id,
        _budgetChannelName,
        importance: Importance.high,
      ),
    );
  }

  /// The payload of the notification that cold-started the app, if any.
  Future<String?> launchPayload() async {
    await ensureInitialized();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details?.notificationResponse?.payload;
    }
    return null;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Whether the user allows notifications for the app (Android 13+ runtime
  /// permission, or the app-level switch on older versions).
  Future<bool> areEnabled() async {
    await ensureInitialized();
    return await _android?.areNotificationsEnabled() ?? false;
  }

  /// Shows the system permission dialog (Android 13+). Returns whether
  /// notifications are allowed afterwards.
  Future<bool> requestPermission() async {
    await ensureInitialized();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  /// Opens the system notification settings of the app, for when the
  /// permission was denied for good.
  Future<void> openSystemSettings() async {
    await ensureInitialized();
    await _plugin.openAppNotificationSettings();
  }

  NotificationDetails _details(NotificationChannel channel) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel == NotificationChannel.budget
              ? _budgetChannelName
              : _remindersChannelName,
          importance: channel == NotificationChannel.budget
              ? Importance.high
              : Importance.defaultImportance,
          priority: channel == NotificationChannel.budget
              ? Priority.high
              : Priority.defaultPriority,
        ),
      );

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    required String payload,
    required NotificationChannel channel,
  }) async {
    await ensureInitialized();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details(channel),
      payload: payload,
    );
  }

  Future<void> schedule({
    required int id,
    required tz.TZDateTime when,
    required String title,
    required String body,
    required String payload,
    required NotificationChannel channel,
  }) async {
    await ensureInitialized();
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: when,
      title: title,
      body: body,
      notificationDetails: _details(channel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Cancels the pending notifications whose id is in [ids].
  Future<void> cancelPending(Set<int> ids) async {
    await ensureInitialized();
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (ids.contains(request.id)) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  void dispose() => unawaited(_taps.close());
}
