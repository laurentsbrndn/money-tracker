import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/presentation/screens/lock_screen.dart';
import 'app_lock_controller.dart';

/// Puts the lock screen above the whole app while it is locked, and makes
/// everything below unreachable (touch, focus, and accessibility).
class LockGate extends ConsumerWidget {
  const LockGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(appLockControllerProvider.select((s) => s.locked));
    ref.listen(appLockControllerProvider.select((s) => s.locked), (
      previous,
      next,
    ) {
      if (next) {
        // Close the keyboard of whatever field was being edited.
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
    return Stack(
      children: [
        ExcludeSemantics(
          excluding: locked,
          child: IgnorePointer(ignoring: locked, child: child),
        ),
        if (locked) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}
