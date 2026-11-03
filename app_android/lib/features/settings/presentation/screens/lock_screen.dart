import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/app_lock_controller.dart';
import '../../../../core/security/app_lock_state.dart';
import '../../../../core/security/pin_attempt_policy.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/settings_actions.dart';
import '../widgets/pin_pad.dart';

/// The lock screen (FRONTEND_FLUTTER §5 `/lock`). It is an overlay above the
/// whole app (see `App`), not a route, so dialogs and sheets that were open
/// stay hidden behind it. It has no Navigator above it, so the "forgot PIN"
/// confirmation is inline instead of a dialog.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _pad = GlobalKey<PinPadState>();
  Timer? _ticker;
  bool _wrong = false;
  bool _checking = false;
  bool _confirmingLogout = false;
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => mounted ? setState(() {}) : null,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int _secondsLeft(AppLockState lock) =>
      lockoutSecondsLeft(lock.lockedUntil, DateTime.now().toUtc());

  Future<void> _tryBiometric() async {
    if (!mounted) {
      return;
    }
    final lock = ref.read(appLockControllerProvider);
    if (!lock.biometricEnabled || !lock.locked) {
      return;
    }
    final reason = AppLocalizations.of(context).lockBiometricReason;
    await ref
        .read(appLockControllerProvider.notifier)
        .unlockWithBiometric(reason);
  }

  Future<void> _submit(String pin) async {
    setState(() => _checking = true);
    final result = await ref
        .read(appLockControllerProvider.notifier)
        .unlock(pin);
    if (!mounted) {
      return;
    }
    setState(() {
      _checking = false;
      _wrong = result != PinCheck.success;
    });
    if (result != PinCheck.success) {
      _pad.currentState?.clear();
    }
  }

  Future<void> _askLogout() async {
    final pending = await ref.read(settingsActionsProvider).pendingChanges();
    if (mounted) {
      setState(() {
        _pending = pending;
        _confirmingLogout = true;
      });
    }
  }

  static String _formatWait(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lock = ref.watch(appLockControllerProvider);
    final left = _secondsLeft(lock);

    if (_confirmingLogout) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l10n.lockForgot, style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(l10n.lockForgotBody, textAlign: TextAlign.center),
                if (_pending > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.lockForgotPending(_pending),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () =>
                      unawaited(ref.read(settingsActionsProvider).logout()),
                  child: Text(l10n.logoutConfirm),
                ),
                TextButton(
                  onPressed: () => setState(() => _confirmingLogout = false),
                  child: Text(l10n.actionCancel),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(l10n.lockTitle, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  left > 0
                      ? l10n.lockWait(_formatWait(left))
                      : (_wrong ? l10n.lockWrongPin : l10n.lockEnterPin),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _wrong || left > 0 ? theme.colorScheme.error : null,
                  ),
                ),
                const SizedBox(height: 32),
                PinPad(
                  key: _pad,
                  enabled: left == 0 && !_checking,
                  onComplete: (pin) => unawaited(_submit(pin)),
                  biometricButton: lock.biometricEnabled
                      ? IconButton(
                          iconSize: 28,
                          tooltip: l10n.lockUseBiometric,
                          onPressed: () => unawaited(_tryBiometric()),
                          icon: const Icon(Icons.fingerprint),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => unawaited(_askLogout()),
                  child: Text(l10n.lockForgot),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
