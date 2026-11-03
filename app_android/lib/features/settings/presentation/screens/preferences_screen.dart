import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/error_messages.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/user_settings_actions.dart';
import '../../application/user_settings_providers.dart';
import '../widgets/timezone_picker_sheet.dart';

/// Pengaturan → Preferensi (APP_FLOWS Flow 12): timezone, first day of the
/// week, theme. All three live in `user_settings` and sync between devices.
class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(userSettingsProvider).value;
    final repository = ref.watch(userSettingsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.prefsTitle)),
      body: settings == null
          ? Center(child: Text(l10n.prefsSettingsNotReady))
          : ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.public),
                  title: Text(l10n.prefsTimezone),
                  subtitle: Text(settings.timezone.replaceAll('_', ' ')),
                  onTap: () async {
                    final picked = await showTimezonePicker(
                      context,
                      settings.timezone,
                    );
                    if (picked != null && picked != settings.timezone) {
                      if (!context.mounted) {
                        return;
                      }
                      await _run(context, () => repository.setTimezone(picked));
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
                  child: Text(
                    l10n.prefsTimezoneHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.calendar_view_week_outlined),
                  title: Text(l10n.prefsWeekStart),
                  trailing: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 1, label: Text(l10n.prefsMonday)),
                      ButtonSegment(value: 7, label: Text(l10n.prefsSunday)),
                    ],
                    selected: {settings.weekStart},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) => unawaited(
                      _run(context, () => repository.setWeekStart(value.first)),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: Text(l10n.prefsTheme),
                ),
                RadioGroup<String>(
                  groupValue: settings.theme,
                  onChanged: (value) {
                    if (value != null) {
                      unawaited(_run(context, () => repository.setTheme(value)));
                    }
                  },
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: 'system',
                        title: Text(l10n.prefsThemeSystem),
                      ),
                      RadioListTile<String>(
                        value: 'light',
                        title: Text(l10n.prefsThemeLight),
                      ),
                      RadioListTile<String>(
                        value: 'dark',
                        title: Text(l10n.prefsThemeDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
