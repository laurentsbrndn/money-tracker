import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/session_controller.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// "Verifikasi email" reminder shown until the address is verified
/// (APP_FLOWS Flow 1, step 3.2). Hidden for social-login users without email.
class VerifyEmailBanner extends ConsumerWidget {
  const VerifyEmailBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionControllerProvider).user;
    if (user == null || user.emailVerified || user.email == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: ListTile(
        leading: const Icon(Icons.mark_email_unread_outlined),
        title: Text(l10n.verifyEmailBanner),
        trailing: TextButton(
          onPressed: () => context.push(RoutePaths.verifyEmail),
          child: Text(l10n.verifyEmailBannerAction),
        ),
      ),
    );
  }
}
