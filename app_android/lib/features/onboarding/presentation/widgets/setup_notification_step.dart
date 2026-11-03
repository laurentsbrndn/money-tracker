import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';

/// Setup wizard step: the daily reminder and its time (APP_FLOWS Flow 1 step
/// 6.5). The permission is requested when the user continues with the
/// reminder on.
class SetupNotificationStep extends StatelessWidget {
  const SetupNotificationStep({
    required this.enabled,
    required this.time,
    required this.onEnabledChanged,
    required this.onTimeChanged,
    super.key,
  });

  final bool enabled;

  /// `HH:MM`.
  final String time;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String> onTimeChanged;

  Future<void> _pick(BuildContext context) async {
    final parts = time.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 20,
        minute: int.tryParse(parts.last) ?? 0,
      ),
    );
    if (picked != null) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      onTimeChanged('$hh:$mm');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l10n.setupNotificationsTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(l10n.setupNotificationsBody),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.setupNotificationsToggle),
          value: enabled,
          onChanged: onEnabledChanged,
        ),
        if (enabled)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.notifDailyTime),
            trailing: Text(
              time,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () => unawaited(_pick(context)),
          ),
      ],
    );
  }
}
