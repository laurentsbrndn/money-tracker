import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/error_messages.dart';
import '../../../../core/notifications/notification_coordinator.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/notification_permission_provider.dart';
import '../../application/user_settings_actions.dart';
import '../../application/user_settings_providers.dart';

/// The time the daily reminder gets when it is switched on.
const String defaultReminderTime = '20:00';

/// Pengaturan → Notifikasi (APP_FLOWS Flow 12): daily reminder and its time,
/// reconcile reminder, budget warnings. The permission is asked when the user
/// turns a reminder on, not before.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Back from the system settings: re-read the permission.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(notificationPermissionProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeError(error, l10n))),
      );
    }
  }

  /// Asks for the permission if it is missing; used when a reminder is
  /// switched on.
  Future<void> _ensurePermission() async {
    final service = ref.read(notificationServiceProvider);
    if (!await service.areEnabled()) {
      await service.requestPermission();
    }
    ref.invalidate(notificationPermissionProvider);
  }

  Future<void> _pickTime(String current) async {
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 20,
        minute: int.tryParse(parts.last) ?? 0,
      ),
    );
    if (picked == null) {
      return;
    }
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    await _run(
      () => ref.read(userSettingsRepositoryProvider).setDailyReminderTime('$hh:$mm'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(userSettingsProvider).value;
    final repository = ref.watch(userSettingsRepositoryProvider);
    final permitted = ref.watch(notificationPermissionProvider).value ?? true;
    final reminder = settings?.dailyReminderTime;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notifSettingsTitle)),
      body: settings == null
          ? Center(child: Text(l10n.prefsSettingsNotReady))
          : ListView(
              children: [
                if (!permitted)
                  Card(
                    margin: const EdgeInsets.all(16),
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.notifPermissionOffTitle,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(l10n.notifPermissionOffBody),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton(
                                onPressed: () => unawaited(_ensurePermission()),
                                child: Text(l10n.notifPermissionAllow),
                              ),
                              TextButton(
                                onPressed: () => unawaited(
                                  ref
                                      .read(notificationServiceProvider)
                                      .openSystemSettings(),
                                ),
                                child: Text(l10n.notifPermissionOpenSettings),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                SwitchListTile(
                  secondary: const Icon(Icons.edit_calendar_outlined),
                  title: Text(l10n.notifDaily),
                  subtitle: Text(
                    reminder == null
                        ? l10n.notifDailyOff
                        : l10n.notifDailyOn(reminder),
                  ),
                  value: reminder != null,
                  onChanged: (on) => unawaited(
                    _run(() async {
                      if (on) {
                        await _ensurePermission();
                      }
                      await repository.setDailyReminderTime(
                        on ? defaultReminderTime : null,
                      );
                    }),
                  ),
                ),
                if (reminder != null)
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 72, right: 16),
                    title: Text(l10n.notifDailyTime),
                    trailing: Text(reminder, style: theme.textTheme.titleMedium),
                    onTap: () => unawaited(_pickTime(reminder)),
                  ),
                SwitchListTile(
                  secondary: const Icon(Icons.fact_check_outlined),
                  title: Text(l10n.notifReconcile),
                  subtitle: Text(l10n.notifReconcileSubtitle),
                  value: settings.reconcileReminderEnabled,
                  onChanged: (on) => unawaited(
                    _run(() async {
                      if (on) {
                        await _ensurePermission();
                      }
                      await repository.setReconcileReminder(enabled: on);
                    }),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.pie_chart_outline),
                  title: Text(l10n.notifBudget),
                  subtitle: Text(l10n.notifBudgetSubtitle),
                  value: settings.budgetAlertEnabled,
                  onChanged: (on) => unawaited(
                    _run(() async {
                      if (on) {
                        await _ensurePermission();
                      }
                      await repository.setBudgetAlert(enabled: on);
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.notifHideNote,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
    );
  }
}
