import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';

part 'user_settings_providers.g.dart';

/// The user's single `user_settings` row (null until the first pull).
/// Declared by hand because it returns a Drift row type.
final userSettingsProvider = StreamProvider.autoDispose<UserSettingsRow?>(
  (ref) => ref
      .watch(appDatabaseProvider)
      .userSettingsDao
      .watchActive()
      .map((rows) => rows.isEmpty ? null : rows.first),
);

/// `hide_amounts`: amounts show as `Rp •••••`.
@riverpod
bool hideAmounts(Ref ref) =>
    ref.watch(userSettingsProvider).value?.hideAmounts ?? false;

/// `theme` as the app's [ThemeMode].
@riverpod
ThemeMode appThemeMode(Ref ref) =>
    switch (ref.watch(userSettingsProvider).value?.theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
