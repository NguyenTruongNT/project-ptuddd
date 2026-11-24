import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/auth/auth_session_providers.dart';
import '../../../l10n/app_localizations.dart';
import 'auth_error_message.dart';

class LogoutButton extends ConsumerStatefulWidget {
  const LogoutButton({super.key});
  @override
  ConsumerState<LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends ConsumerState<LogoutButton> {
  bool _busy = false;
  Future<void> _logout() async {
    if (_busy) return;
    final text = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final demo = ref.read(demoModeProvider);
      if (!demo) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(text.profileLogout),
            content: Text(text.profileLogoutConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(text.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(text.profileLogout),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        await ref.read(authRepositoryProvider)?.signOut();
      }
      if (!mounted) return;
      ref.read(demoModeProvider.notifier).disable();
      ref.invalidate(currentProfileProvider);
      context.go(AppRoutes.signIn);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authErrorMessage(error, text))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    return OutlinedButton.icon(
      onPressed: _busy ? null : _logout,
      icon: const Icon(Icons.logout),
      label: Text(
        ref.watch(demoModeProvider) ? text.authExitDemo : text.profileLogout,
      ),
    );
  }
}
