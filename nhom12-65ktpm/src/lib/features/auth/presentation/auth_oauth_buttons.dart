import 'package:flutter/material.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../l10n/app_localizations.dart';

class AuthOAuthButtons extends StatelessWidget {
  const AuthOAuthButtons({super.key, required this.onSelected, this.pending});

  final ValueChanged<SocialAuthProvider>? onSelected;
  final SocialAuthProvider? pending;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(child: Center(child: Divider())),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    text.authOAuthDivider,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        for (final provider in SocialAuthProvider.values) ...[
          if (provider != SocialAuthProvider.google) const SizedBox(height: 12),
          OutlinedButton(
            key: ValueKey('auth-oauth-${provider.name}'),
            onPressed: onSelected == null ? null : () => onSelected!(provider),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1F1F1F),
              disabledForegroundColor: const Color(0xFF747775),
              side: const BorderSide(color: Color(0xFF747775)),
              minimumSize: const Size(48, 52),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              textStyle: const TextStyle(
                fontFamily: 'GoogleSans',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: pending == provider
                      ? const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1F1F1F),
                        )
                      : Image.asset(
                          provider == SocialAuthProvider.google
                              ? 'assets/branding/google_g.png'
                              : 'assets/branding/github_mark.png',
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    provider == SocialAuthProvider.google
                        ? text.authContinueGoogle
                        : text.authContinueGithub,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 30),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
