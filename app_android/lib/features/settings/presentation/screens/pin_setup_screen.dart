import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/security/app_lock_controller.dart';
import '../../../../core/security/app_lock_state.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../widgets/pin_pad.dart';

/// What the PIN screen does.
enum PinSetupMode {
  /// First PIN: new, then confirm.
  set,

  /// Replace the PIN: current, new, then confirm.
  change,

  /// Turn the lock off: current.
  remove;

  static PinSetupMode parse(String? value) => values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => PinSetupMode.set,
  );
}

enum _Stage { current, fresh, confirm }

/// Sets, changes, or removes the PIN (APP_FLOWS Flow 12 "Keamanan").
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({required this.mode, super.key});

  final PinSetupMode mode;

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _pad = GlobalKey<PinPadState>();
  late _Stage _stage;
  String? _fresh;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _stage = widget.mode == PinSetupMode.set ? _Stage.fresh : _Stage.current;
  }

  Future<void> _onComplete(String pin) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final lock = ref.read(appLockControllerProvider.notifier);
    setState(() => _busy = true);
    try {
      switch (_stage) {
        case _Stage.current:
          if (widget.mode == PinSetupMode.remove) {
            final result = await lock.removePin(pin);
            if (result == PinCheck.success) {
              messenger.showSnackBar(SnackBar(content: Text(l10n.pinRemoved)));
              router.pop();
              return;
            }
            _fail(l10n.lockWrongPin);
          } else {
            final result = await lock.check(pin);
            if (result == PinCheck.success) {
              _advance(_Stage.fresh);
            } else {
              _fail(l10n.lockWrongPin);
            }
          }
        case _Stage.fresh:
          _fresh = pin;
          _advance(_Stage.confirm);
        case _Stage.confirm:
          if (pin != _fresh) {
            _fresh = null;
            _stage = _Stage.fresh;
            _fail(l10n.pinMismatch);
            return;
          }
          await lock.setPin(pin);
          messenger.showSnackBar(SnackBar(content: Text(l10n.pinSaved)));
          router.pop();
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _advance(_Stage next) {
    setState(() {
      _stage = next;
      _error = null;
    });
    _pad.currentState?.clear();
  }

  void _fail(String message) {
    setState(() => _error = message);
    _pad.currentState?.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title = switch (widget.mode) {
      PinSetupMode.set => l10n.pinSetTitle,
      PinSetupMode.change => l10n.pinChangeTitle,
      PinSetupMode.remove => l10n.pinRemoveTitle,
    };
    final prompt = switch (_stage) {
      _Stage.current => l10n.pinCurrentPrompt,
      _Stage.fresh => l10n.pinNewPrompt,
      _Stage.confirm => l10n.pinConfirmPrompt,
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(prompt, style: theme.textTheme.titleMedium),
                SizedBox(
                  height: 32,
                  child: _error == null
                      ? null
                      : Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                ),
                const SizedBox(height: 16),
                PinPad(
                  key: _pad,
                  enabled: !_busy,
                  onComplete: (pin) => unawaited(_onComplete(pin)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
